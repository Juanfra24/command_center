// lib/config/services/bot_engine/microbot_setup_service.dart
import 'package:command_center/config/services/bot_engine/java_installer.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:get/get.dart';

enum MicrobotSetupStep { idle, python, java, microbot, complete, failed }

/// Orchestrates all dependency installation for the app.
/// Coordinates Python, Java 17, and Microbot JAR setup with progress reporting.
class MicrobotSetupService extends GetxService {
  final PythonSetupService _pythonSetup;
  final JavaInstaller _javaInstaller;
  final MicrobotJarDownloader _jarDownloader;

  final currentStep = MicrobotSetupStep.idle.obs;
  final progress = ''.obs;
  final progressPercent = 0.0.obs;
  final isComplete = false.obs;
  final isSkipped = false.obs;

  bool _isRunning = false;

  MicrobotSetupService({
    required PythonSetupService pythonSetup,
    required JavaInstaller javaInstaller,
    required MicrobotJarDownloader jarDownloader,
  })  : _pythonSetup = pythonSetup,
        _javaInstaller = javaInstaller,
        _jarDownloader = jarDownloader;

  /// Run all dependency checks and installations.
  /// Called during splash screen before app loads.
  Future<void> ensureDependencies() async {
    if (_isRunning || isComplete.value) return;
    _isRunning = true;

    try {
      // Step 1: Python + Patchright
      currentStep.value = MicrobotSetupStep.python;
      progress.value = 'Checking Python...';
      progressPercent.value = 0.0;
      await _pythonSetup.initializeSetup();
      progressPercent.value = 0.33;

      // Step 2: Java 17
      currentStep.value = MicrobotSetupStep.java;
      progress.value = 'Checking Java 17...';
      var javaPath = await _javaInstaller.findJavaPath();
      if (javaPath == null) {
        progress.value = 'Downloading Java 17 Runtime...';
        javaPath =
            await _javaInstaller.install(onProgress: (downloaded, total) {
          if (total > 0) {
            final pct = downloaded / total;
            progressPercent.value = 0.33 + (pct * 0.33);
            final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            progress.value = 'Downloading Java 17... $mb MB / $totalMb MB';
          }
        });
      }
      // Verify Java is actually usable after install
      final verifiedJava = await _javaInstaller.findJavaPath();
      if (verifiedJava == null) {
        throw Exception(
            'Java 17 installation failed — java not found after install');
      }
      progressPercent.value = 0.66;

      // Step 3: Microbot JAR
      currentStep.value = MicrobotSetupStep.microbot;
      progress.value = 'Checking Microbot...';
      final jarPath =
          await _jarDownloader.ensureJar(onProgress: (downloaded, total) {
        if (total > 0) {
          final pct = downloaded / total;
          progressPercent.value = 0.66 + (pct * 0.34);
          final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
          progress.value = 'Downloading Microbot... $mb MB / $totalMb MB';
        }
      });

      if (jarPath == null) {
        logger.w('Microbot JAR not available — launching without bot engine');
      }

      progressPercent.value = 1.0;
      currentStep.value = MicrobotSetupStep.complete;
      progress.value = 'Ready';
      isComplete.value = true;
    } catch (e) {
      logger.e('Setup failed: $e');
      currentStep.value = MicrobotSetupStep.failed;
      progress.value = 'Setup failed: ${_sanitizeError(e)}';
    } finally {
      _isRunning = false;
    }
  }

  /// Whether the app can proceed (setup succeeded or was skipped).
  bool get canProceed => isComplete.value || isSkipped.value;

  /// Retry setup after a failure.
  Future<void> retry() async {
    if (_isRunning) return;
    currentStep.value = MicrobotSetupStep.idle;
    progress.value = '';
    progressPercent.value = 0.0;
    isComplete.value = false;
    await ensureDependencies();
  }

  /// Skip setup and proceed without bot engine.
  void skip() {
    isSkipped.value = true;
    currentStep.value = MicrobotSetupStep.complete;
    progress.value = 'Skipped — bot engine unavailable';
    logger.w('Setup skipped by user');
  }

  static String _sanitizeError(Object error) {
    final msg = error.toString();
    // Strip exception type prefixes for cleaner UI display
    if (msg.startsWith('SetupFailedException: ')) {
      return msg.substring('SetupFailedException: '.length);
    }
    if (msg.startsWith('Exception: ')) {
      return msg.substring('Exception: '.length);
    }
    return msg;
  }
}
