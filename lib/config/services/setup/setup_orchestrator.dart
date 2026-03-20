import 'dart:async';

import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/bot_engine/java_installer.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/config/services/setup/scripts_extractor.dart';
import 'package:command_center/config/services/setup/setup_messages.dart';
import 'package:command_center/config/services/setup/setup_step_state.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/python_resolver.dart';
import 'package:get/get.dart';

/// Orchestrates the 4-step mandatory setup flow.
/// Holds reactive state that the splash screen observes.
/// [run()] blocks until all steps complete — the caller simply awaits it.
class SetupOrchestrator extends GetxService {
  final ScriptsExtractor _scriptsExtractor;
  final PythonSetupService _pythonSetup;
  final JavaInstaller _javaInstaller;
  final MicrobotJarDownloader _jarDownloader;
  final AppConfigService _appConfig;

  SetupOrchestrator({
    required ScriptsExtractor scriptsExtractor,
    required PythonSetupService pythonSetup,
    required JavaInstaller javaInstaller,
    required MicrobotJarDownloader jarDownloader,
    required AppConfigService appConfig,
  })  : _scriptsExtractor = scriptsExtractor,
        _pythonSetup = pythonSetup,
        _javaInstaller = javaInstaller,
        _jarDownloader = jarDownloader,
        _appConfig = appConfig;

  /// Observable list of step states — splash screen renders this.
  final steps = <SetupStepState>[
    const SetupStepState(label: 'Extract Scripts'),
    const SetupStepState(label: 'Python Setup'),
    const SetupStepState(label: 'Java Setup'),
    const SetupStepState(label: 'Microbot Setup'),
  ].obs;

  /// Index of the currently running (or failed) step.
  final currentStepIndex = 0.obs;

  /// Whether all steps completed.
  final isComplete = false.obs;

  Completer<void>? _retryCompleter;
  Completer<String>? _inputCompleter;

  /// Called by the UI when the user submits a text input (e.g. GitHub PAT).
  void submitInput(String value) {
    _inputCompleter?.complete(value);
    _inputCompleter = null;
  }

  /// Run all 4 steps sequentially. Blocks until all complete.
  Future<void> run() async {
    final stepFunctions = [
      _runExtractScripts,
      _runPythonSetup,
      _runJavaSetup,
      _runMicrobotSetup,
    ];

    for (var i = 0; i < stepFunctions.length; i++) {
      currentStepIndex.value = i;
      var success = false;

      while (!success) {
        _updateStep(i,
            status: StepStatus.running,
            detail: '',
            progress: 0.0,
            clearError: true);
        try {
          await stepFunctions[i](i);
          _updateStep(i, status: StepStatus.completed, progress: 1.0);
          success = true;
        } catch (e) {
          logger.e('Setup step ${steps[i].label} failed: $e');
          final msg = _errorForStep(i, e);
          _updateStep(
            i,
            status: StepStatus.failed,
            errorMessage: msg.error,
            fixHint: msg.hint,
          );
          // Block until user retries
          _retryCompleter = Completer<void>();
          await _retryCompleter!.future;
        }
      }
    }

    isComplete.value = true;
  }

  /// Called by the UI Retry button. Safe against double-tap.
  void retryCurrentStep() {
    if (_retryCompleter != null && !_retryCompleter!.isCompleted) {
      _retryCompleter!.complete();
    }
    _retryCompleter = null;
  }

  void _updateStep(
    int index, {
    StepStatus? status,
    String? detail,
    double? progress,
    String? errorMessage,
    String? fixHint,
    bool clearError = false,
    bool? needsInput,
    String? inputLabel,
  }) {
    steps[index] = steps[index].copyWith(
      status: status,
      detail: detail,
      progress: progress,
      errorMessage: errorMessage,
      fixHint: fixHint,
      clearError: clearError,
      needsInput: needsInput,
      inputLabel: inputLabel,
    );
  }

  // -- Step Implementations --------------------------------------------------

  Future<void> _runExtractScripts(int i) async {
    _updateStep(i, detail: 'Checking scripts...');
    if (await _scriptsExtractor.needsExtraction()) {
      await _scriptsExtractor.extract(
        onProgress: (detail) => _updateStep(i, detail: detail),
      );
    } else {
      _updateStep(i, detail: 'Scripts up to date');
    }
  }

  Future<void> _runPythonSetup(int i) async {
    // Reset state to avoid stuck guards on retry
    _pythonSetup.isChecking = false;
    _pythonSetup.isSetupComplete = false;
    PythonResolver.resetCache();

    _updateStep(i, detail: 'Checking Python availability...');
    if (!await _pythonSetup.checkPythonAvailable()) {
      throw SetupFailedException(
          'Python not found. Please install Python 3.8 or higher.');
    }

    _updateStep(i, detail: 'Checking pip...');
    if (!await _pythonSetup.checkPipAvailable()) {
      throw SetupFailedException(
          'pip not found. Please reinstall Python with pip.');
    }

    _updateStep(i, detail: 'Checking installed dependencies...', progress: 0.1);
    if (await _pythonSetup.checkDependenciesInstalled()) {
      _updateStep(i, detail: 'Verifying browser driver...', progress: 0.7);
      final browserWorks = await _pythonSetup.installChromiumDriver();
      if (browserWorks) {
        _updateStep(i, detail: 'Python environment ready', progress: 1.0);
        return;
      }
      logger.w('Browser verification failed, re-running full setup...');
    }

    _updateStep(i, detail: 'Installing Python dependencies...', progress: 0.2);
    final success = await _pythonSetup.installDependencies();
    if (!success) {
      throw SetupFailedException(
          _pythonSetup.setupError ?? 'Python setup failed');
    }
    _updateStep(i, detail: 'Python environment ready', progress: 1.0);
  }

  Future<void> _runJavaSetup(int i) async {
    _updateStep(i, detail: 'Checking for saved Java path...');
    var javaPath = await _javaInstaller.findJavaPath();

    if (javaPath != null) {
      _updateStep(i, detail: 'Java 17 found at: $javaPath', progress: 1.0);
      return;
    }

    _updateStep(i,
        detail: 'Java 17 not found — downloading Eclipse Temurin JRE...',
        progress: 0.05);
    javaPath = await _javaInstaller.install(
      onProgress: (downloaded, total) {
        if (total > 0) {
          final pct = downloaded / total;
          final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
          _updateStep(i,
              detail: 'Downloading Java 17 JRE... $mb MB / $totalMb MB',
              progress: 0.05 + (pct * 0.85));
        }
      },
    );

    _updateStep(i, detail: 'Verifying Java installation...', progress: 0.95);
    final verified = await _javaInstaller.findJavaPath();
    if (verified == null) {
      throw Exception('Java 17 not found after install');
    }
    _updateStep(i, detail: 'Java 17 installed at: $verified', progress: 1.0);
  }

  Future<void> _runMicrobotSetup(int i) async {
    _updateStep(i, detail: 'Checking configuration...');

    // Check if GitHub PAT is configured — prompt if missing or invalid
    var token = await _appConfig.getGithubPat();
    if (token == null || token.isEmpty) {
      token = await _promptForPat(i);
    }

    _updateStep(i, detail: 'Checking for cached Microbot JAR...');
    final jarPath = await _jarDownloader.ensureJar(
      onProgress: (downloaded, total) {
        if (total > 0) {
          final pct = downloaded / total;
          final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
          _updateStep(i,
              detail: 'Downloading Microbot JAR... $mb MB / $totalMb MB',
              progress: pct);
        }
      },
    );
    if (jarPath == null) {
      throw Exception('Microbot JAR not available');
    }
    _updateStep(i, detail: 'Microbot JAR ready at: $jarPath');
  }

  /// Prompt the user for a GitHub PAT via the splash screen input field.
  Future<String> _promptForPat(int i) async {
    _updateStep(
      i,
      status: StepStatus.running,
      detail:
          'A GitHub Personal Access Token is required to download Microbot from the private repository.',
      needsInput: true,
      inputLabel: 'GitHub Personal Access Token',
    );
    _inputCompleter = Completer<String>();
    final token = await _inputCompleter!.future;
    await _appConfig.saveGithubPat(token);
    _updateStep(i, detail: 'Verifying token...', needsInput: false);
    return token;
  }

  // -- Error Mapping ---------------------------------------------------------

  ({String error, String hint}) _errorForStep(int index, Object e) {
    final msg = e.toString();
    switch (index) {
      case 0:
        return SetupMessages.scriptsExtractionFailed();
      case 1:
        if (msg.contains('Python not found')) {
          return SetupMessages.pythonNotFound();
        }
        if (msg.contains('pip not found')) return SetupMessages.pipNotFound();
        if (msg.contains('requirements.txt')) {
          return SetupMessages.requirementsTxtMissing();
        }
        return SetupMessages.pipInstallFailed();
      case 2:
        if (msg.contains('extract')) {
          return SetupMessages.javaExtractionFailed();
        }
        return SetupMessages.javaDownloadFailed();
      case 3:
        if (msg.contains('401') ||
            msg.contains('invalid') ||
            msg.contains('expired') ||
            msg.contains('token') ||
            msg.contains('PAT')) {
          // Clear the bad PAT so user is re-prompted on retry
          _appConfig.saveGithubPat('');
          return SetupMessages.githubPatMissing();
        }
        return SetupMessages.jarDownloadFailed();
      default:
        return (error: 'Setup failed', hint: 'Try restarting the application');
    }
  }
}
