import 'dart:io';
import 'package:command_center/core/helper/logger.dart';
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

  String get _scriptsPath {
    // Get the scripts directory path
    final execDir = path.dirname(Platform.resolvedExecutable);

    // In development
    final devScriptsPath = path.join(
      path.dirname(path.dirname(execDir)),
      'scripts',
    );

    if (Directory(devScriptsPath).existsSync()) {
      return devScriptsPath;
    }

    // Try relative to workspace
    final workspacePath = path.join(
      Platform.environment['USERPROFILE'] ?? '',
      'projects',
      'command_center',
      'scripts',
    );

    if (Directory(workspacePath).existsSync()) {
      return workspacePath;
    }

    // Fallback
    return path.join(execDir, 'data', 'scripts');
  }

  /// Check if Python is available
  Future<bool> checkPythonAvailable() async {
    try {
      final result = await Process.run('python', ['--version']);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        logger.i('Python found: $version');
        return true;
      }
    } catch (e) {
      logger.e('Python not found: $e');
    }
    return false;
  }

  /// Check if pip is available
  Future<bool> checkPipAvailable() async {
    try {
      final result = await Process.run('python', ['-m', 'pip', '--version']);
      if (result.exitCode == 0) {
        logger.i('pip is available');
        return true;
      }
    } catch (e) {
      logger.e('pip not found: $e');
    }
    return false;
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

      // Check Python
      if (!await checkPythonAvailable()) {
        setupError.value =
            'Python not found. Please install Python 3.8 or higher.';
        currentStep.value = SetupStep.failed;
        return false;
      }

      setupProgressPercent.value = 0.2;

      // Check pip
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

      // Install dependencies with upgrade flag
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

      // Capture output
      final output = StringBuffer();
      process.stdout.listen((data) {
        final text = String.fromCharCodes(data);
        output.write(text);
        logger.d(text);
      });

      process.stderr.listen((data) {
        final text = String.fromCharCodes(data);
        output.write(text);
        // Using logger.w here is fine for pip warnings
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

      // Install Chromium driver
      currentStep.value = SetupStep.installingChromium;
      setupProgress.value = 'Installing Chromium browser driver...';

      final chromiumSuccess = await installChromiumDriver();
      if (!chromiumSuccess) {
        logger.w('Chromium pre-install failed, will download at runtime');
      }

      setupProgressPercent.value = 0.9;
      currentStep.value = SetupStep.verifying;
      setupProgress.value = 'Verifying installation...';

      // Verify the installation
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

  /// Install Chromium driver using seleniumbase
  Future<bool> installChromiumDriver() async {
    try {
      logger.i('Installing Chromium driver via sbase...');

      final result = await Process.run(
        'python',
        ['-m', 'sbase', 'install', 'chromedriver', 'latest'],
        workingDirectory: _scriptsPath,
      );

      if (result.exitCode == 0) {
        logger.i('Chromium driver installed successfully');
        isChromiumInstalled.value = true;
        // Proceed to run the visual check
        return await _verifyChromiumWorks();
      } else {
        logger.w('Chromium driver install returned: ${result.stderr}');
        return await _verifyChromiumWorks();
      }
    } catch (e) {
      logger.w('Error installing Chromium driver: $e');
      return false;
    }
  }

  /// Verify Chromium works by running a simple test (NOW VISIBLE)
  Future<bool> _verifyChromiumWorks() async {
    try {
      logger.i('Opening browser to verify installation...');
      // Run a quick VISIBLE test (headless=False)
      final result = await Process.run(
        'python',
        [
          '-c',
          '''
from seleniumbase import SB
import sys
try:
    # Changed headless to False so you can see it open on Windows!
    with SB(uc=True, headless=False) as sb:
        sb.open("about:blank")
        print("CHROMIUM_OK")
        sys.exit(0)
except Exception as e:
    print(f"CHROMIUM_ERROR: {e}")
    sys.exit(1)
'''
        ],
        workingDirectory: _scriptsPath,
      ).timeout(const Duration(seconds: 60));

      final output = result.stdout.toString();
      if (output.contains('CHROMIUM_OK')) {
        logger.i('Chromium verification successful - Browser works!');
        isChromiumInstalled.value = true;
        return true;
      }
      logger.w('Chromium verification failed: $output');
      return false;
    } catch (e) {
      logger.w('Chromium verification error: $e');
      return false;
    }
  }

  /// Check if dependencies are already installed
  Future<bool> checkDependenciesInstalled() async {
    try {
      final result = await Process.run(
        'python',
        ['-c', 'import seleniumbase; print("OK")'],
      );

      if (result.exitCode == 0 &&
          result.stdout.toString().trim().contains('OK')) {
        logger.i('Python dependencies already installed');
        isSetupComplete.value = true;
        return true;
      }
    } catch (e) {
      logger.w('Dependencies check failed: $e');
    }
    return false;
  }

  /// Initialize and setup if needed
  Future<void> initializeSetup() async {
    if (isSetupComplete.value) return;

    logger.i('Checking Python setup...');

    // First check if the python packages exist
    if (await checkDependenciesInstalled()) {
      logger.i('Dependencies found, visually verifying browser...');

      // FORCED CHECK: Even if packages exist, make sure Chrome actually opens!
      final browserWorks = await _verifyChromiumWorks();

      if (browserWorks) {
        isSetupComplete.value = true;
        return;
      } else {
        logger.w('Browser verification failed! Re-running full setup...');
        // If the browser fails to open, fall through and reinstall everything
      }
    }

    // If not installed, or if browser verification failed, install them
    logger.i('Installing/Repairing Python dependencies and drivers...');
    await installDependencies();
  }
}
