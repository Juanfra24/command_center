import 'dart:io';
import 'package:command_center/config/services/python_dependency_checker.dart';
import 'package:command_center/core/helper/logger.dart';
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

/// Service to manage Python environment setup and dependencies
class PythonSetupService extends GetxService {
  final isSetupComplete = false.obs;
  final isChecking = false.obs;
  final isChromiumInstalled = false.obs;
  final setupError = Rxn<String>();
  final setupProgress = ''.obs;
  final currentStep = SetupStep.idle.obs;
  final setupProgressPercent = 0.0.obs;

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
    if (result) isSetupComplete.value = true;
    return result;
  }

  /// Install Python dependencies
  Future<bool> installDependencies() async {
    if (isChecking.value) return false;

    isChecking.value = true;
    setupError.value = null;
    currentStep.value = SetupStep.checkingPython;
    setupProgressPercent.value = 0.1;

    try {
      setupProgress.value = 'Checking Python installation...';

      if (!await checkPythonAvailable()) {
        setupError.value =
            'Python not found. Please install Python 3.8 or higher.';
        currentStep.value = SetupStep.failed;
        return false;
      }

      setupProgressPercent.value = 0.2;

      if (!await checkPipAvailable()) {
        setupError.value = 'pip not found. Please reinstall Python with pip.';
        currentStep.value = SetupStep.failed;
        return false;
      }

      setupProgressPercent.value = 0.3;
      currentStep.value = SetupStep.installingDependencies;
      setupProgress.value = 'Installing Python dependencies...';

      final requirementsPath = path.join(_scriptsPath, 'requirements.txt');

      if (!File(requirementsPath).existsSync()) {
        setupError.value = 'requirements.txt not found at: $requirementsPath';
        currentStep.value = SetupStep.failed;
        return false;
      }

      logger.i('Installing from: $requirementsPath');

      final process = await Process.start(
        'python',
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
        setupError.value =
            'Failed to install dependencies: ${output.toString()}';
        logger.e('Dependency installation failed with exit code: $exitCode');
        currentStep.value = SetupStep.failed;
        return false;
      }

      setupProgressPercent.value = 0.6;
      logger.i('Python dependencies installed successfully');

      currentStep.value = SetupStep.installingChromium;
      setupProgress.value = 'Installing Chromium browser driver...';

      final chromiumSuccess = await installChromiumDriver();
      if (!chromiumSuccess) {
        logger.w('Chromium pre-install failed, will download at runtime');
      }

      setupProgressPercent.value = 0.9;
      currentStep.value = SetupStep.verifying;
      setupProgress.value = 'Verifying installation...';

      final verified = await checkDependenciesInstalled();
      if (!verified) {
        setupError.value = 'Installation verification failed';
        currentStep.value = SetupStep.failed;
        return false;
      }

      setupProgressPercent.value = 1.0;
      currentStep.value = SetupStep.complete;
      setupProgress.value = 'Setup complete!';
      isSetupComplete.value = true;
      return true;
    } catch (e) {
      setupError.value = 'Error during setup: $e';
      logger.e('Python setup error: $e');
      currentStep.value = SetupStep.failed;
      return false;
    } finally {
      isChecking.value = false;
    }
  }

  /// Install Chromium via Patchright
  Future<bool> installChromiumDriver() async {
    try {
      logger.i('Installing Chromium via patchright...');

      final result = await Process.run(
        'python',
        ['-m', 'patchright', 'install', 'chromium'],
        workingDirectory: _scriptsPath,
      );

      if (result.exitCode == 0) {
        logger.i('Patchright Chromium installed successfully');
        isChromiumInstalled.value = true;
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
    if (result) isChromiumInstalled.value = true;
    return result;
  }

  /// Initialize and setup if needed
  Future<void> initializeSetup() async {
    if (isSetupComplete.value) return;

    logger.i('Checking Python setup...');

    if (await checkDependenciesInstalled()) {
      logger.i('Dependencies found, visually verifying browser...');

      final browserWorks = await _verifyChromiumWorks();

      if (browserWorks) {
        isSetupComplete.value = true;
        return;
      } else {
        logger.w('Browser verification failed! Re-running full setup...');
      }
    }

    logger.i('Installing/Repairing Python dependencies and drivers...');
    await installDependencies();
  }
}
