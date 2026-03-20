import 'dart:io';
import 'package:command_center/config/services/python_dependency_checker.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/python_resolver.dart';
import 'package:command_center/core/helper/scripts_path.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// Setup step for tracking progress
enum SetupStep {
  idle,
  checkingPython,
  installingDependencies,
  installingChromium,
  verifying,
  complete,
  failed,
}

/// Thrown when Python setup fails and cannot proceed.
class SetupFailedException implements Exception {
  final String message;
  SetupFailedException(this.message);
  @override
  String toString() => 'SetupFailedException: $message';
}

/// Service to manage Python environment setup and dependencies
class PythonSetupService extends GetxService {
  bool isSetupComplete = false;
  bool isChecking = false;
  bool isChromiumInstalled = false;
  String? setupError;
  String setupProgress = '';
  SetupStep currentStep = SetupStep.idle;
  double setupProgressPercent = 0.0;

  late final PythonDependencyChecker _checker;

  @override
  void onInit() {
    super.onInit();
    _checker = Get.put(PythonDependencyChecker());
  }

  String get _scriptsPath => scriptsPath;

  /// Check if Python is available
  Future<bool> checkPythonAvailable() => _checker.checkPythonAvailable();

  /// Check if pip is available
  Future<bool> checkPipAvailable() => _checker.checkPipAvailable();

  /// Check if dependencies are already installed
  Future<bool> checkDependenciesInstalled() async {
    final result = await _checker.checkDependenciesInstalled();
    if (result) isSetupComplete = true;
    return result;
  }

  /// Install Python dependencies
  Future<bool> installDependencies() async {
    if (isChecking) return false;

    isChecking = true;
    setupError = null;
    currentStep = SetupStep.checkingPython;
    setupProgressPercent = 0.1;

    try {
      setupProgress = 'Checking Python installation...';

      if (!await checkPythonAvailable()) {
        setupError =
            'Python not found. Please install Python 3.8 or higher.';
        currentStep = SetupStep.failed;
        return false;
      }

      setupProgressPercent = 0.2;

      if (!await checkPipAvailable()) {
        setupError = 'pip not found. Please reinstall Python with pip.';
        currentStep = SetupStep.failed;
        return false;
      }

      setupProgressPercent = 0.3;
      currentStep = SetupStep.installingDependencies;
      setupProgress = 'Installing Python dependencies...';

      final requirementsPath = path.join(_scriptsPath, 'requirements.txt');

      if (!File(requirementsPath).existsSync()) {
        setupError = 'requirements.txt not found at: $requirementsPath';
        currentStep = SetupStep.failed;
        return false;
      }

      logger.i('Installing from: $requirementsPath');

      final python = await PythonResolver.executable;
      final process = await Process.start(
        python,
        [
          '-m',
          'pip',
          'install',
          '-r',
          requirementsPath,
          '--upgrade',
          '--no-cache-dir',
        ],
        workingDirectory: _scriptsPath,
      );

      final output = StringBuffer();
      process.stdout.listen((data) {
        final text = String.fromCharCodes(data);
        output.write(text);
        logger.d(text);
      });

      process.stderr.listen((data) {
        final text = String.fromCharCodes(data);
        output.write(text);
        logger.w(text);
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        setupError =
            'Failed to install dependencies: ${output.toString()}';
        logger.e('Dependency installation failed with exit code: $exitCode');
        currentStep = SetupStep.failed;
        return false;
      }

      setupProgressPercent = 0.6;
      logger.i('Python dependencies installed successfully');

      currentStep = SetupStep.installingChromium;
      setupProgress = 'Installing Chromium browser driver...';

      final chromiumSuccess = await installChromiumDriver();
      if (!chromiumSuccess) {
        logger.w('Chromium pre-install failed, will download at runtime');
      }

      setupProgressPercent = 0.9;
      currentStep = SetupStep.verifying;
      setupProgress = 'Verifying installation...';

      final verified = await checkDependenciesInstalled();
      if (!verified) {
        setupError = 'Installation verification failed';
        currentStep = SetupStep.failed;
        return false;
      }

      setupProgressPercent = 1.0;
      currentStep = SetupStep.complete;
      setupProgress = 'Setup complete!';
      isSetupComplete = true;
      return true;
    } catch (e) {
      setupError = 'Error during setup: $e';
      logger.e('Python setup error: $e');
      currentStep = SetupStep.failed;
      return false;
    } finally {
      isChecking = false;
    }
  }

  /// Install Chromium via Patchright
  Future<bool> installChromiumDriver() async {
    try {
      logger.i('Installing Chromium via patchright...');

      final python = await PythonResolver.executable;
      final result = await Process.run(
        python,
        ['-m', 'patchright', 'install', 'chromium'],
        workingDirectory: _scriptsPath,
      );

      if (result.exitCode == 0) {
        logger.i('Patchright Chromium installed successfully');
        isChromiumInstalled = true;
        return await _verifyChromiumWorks();
      } else {
        logger.w('Patchright Chromium install returned: ${result.stderr}');
        return await _verifyChromiumWorks();
      }
    } catch (e) {
      logger.w('Error installing Patchright Chromium: $e');
      return false;
    }
  }

  Future<bool> _verifyChromiumWorks() async {
    final result = await _checker.verifyChromiumWorks();
    if (result) isChromiumInstalled = true;
    return result;
  }

  /// Initialize and setup if needed.
  /// Throws [SetupFailedException] if Python setup fails critically.
  Future<void> initializeSetup() async {
    if (isSetupComplete) return;

    logger.i('Checking Python setup...');

    if (await checkDependenciesInstalled()) {
      logger.i('Dependencies found, visually verifying browser...');

      final browserWorks = await _verifyChromiumWorks();

      if (browserWorks) {
        isSetupComplete = true;
        return;
      } else {
        logger.w('Browser verification failed! Re-running full setup...');
      }
    }

    logger.i('Installing/Repairing Python dependencies and drivers...');
    final success = await installDependencies();
    if (!success) {
      throw SetupFailedException(setupError ?? 'Python setup failed');
    }
  }
}
