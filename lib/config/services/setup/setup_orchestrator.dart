import 'dart:async';

import 'package:command_center/config/services/bot_engine/java_installer.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/config/services/setup/scripts_extractor.dart';
import 'package:command_center/config/services/setup/setup_messages.dart';
import 'package:command_center/config/services/setup/setup_step_state.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:get/get.dart';

/// Orchestrates the 4-step mandatory setup flow.
/// Holds reactive state that the splash screen observes.
/// [run()] blocks until all steps complete — the caller simply awaits it.
class SetupOrchestrator extends GetxService {
  final ScriptsExtractor _scriptsExtractor;
  final PythonSetupService _pythonSetup;
  final JavaInstaller _javaInstaller;
  final MicrobotJarDownloader _jarDownloader;

  SetupOrchestrator({
    required ScriptsExtractor scriptsExtractor,
    required PythonSetupService pythonSetup,
    required JavaInstaller javaInstaller,
    required MicrobotJarDownloader jarDownloader,
  })  : _scriptsExtractor = scriptsExtractor,
        _pythonSetup = pythonSetup,
        _javaInstaller = javaInstaller,
        _jarDownloader = jarDownloader;

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

  /// Called by the UI Retry button.
  void retryCurrentStep() {
    _retryCompleter?.complete();
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
  }) {
    steps[index] = steps[index].copyWith(
      status: status,
      detail: detail,
      progress: progress,
      errorMessage: errorMessage,
      fixHint: fixHint,
      clearError: clearError,
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
    _updateStep(i, detail: 'Checking Python...');
    await _pythonSetup.initializeSetup();
  }

  Future<void> _runJavaSetup(int i) async {
    _updateStep(i, detail: 'Checking Java 17...');
    var javaPath = await _javaInstaller.findJavaPath();
    if (javaPath == null) {
      _updateStep(i, detail: 'Downloading Java 17 Runtime...');
      javaPath = await _javaInstaller.install(
        onProgress: (downloaded, total) {
          if (total > 0) {
            final pct = downloaded / total;
            final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            _updateStep(i,
                detail: 'Downloading Java 17... $mb MB / $totalMb MB',
                progress: pct);
          }
        },
      );
    }
    // Verify
    final verified = await _javaInstaller.findJavaPath();
    if (verified == null) {
      throw Exception('Java 17 not found after install');
    }
    _updateStep(i, detail: 'Java 17 ready');
  }

  Future<void> _runMicrobotSetup(int i) async {
    _updateStep(i, detail: 'Checking Microbot...');
    final jarPath = await _jarDownloader.ensureJar(
      onProgress: (downloaded, total) {
        if (total > 0) {
          final pct = downloaded / total;
          final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
          _updateStep(i,
              detail: 'Downloading Microbot... $mb MB / $totalMb MB',
              progress: pct);
        }
      },
    );
    if (jarPath == null) {
      throw Exception('Microbot JAR not available');
    }
    _updateStep(i, detail: 'Microbot ready');
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
        if (msg.contains('token') || msg.contains('PAT')) {
          return SetupMessages.githubPatMissing();
        }
        return SetupMessages.jarDownloadFailed();
      default:
        return (error: 'Setup failed', hint: 'Try restarting the application');
    }
  }
}
