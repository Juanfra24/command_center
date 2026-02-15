import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/core/constants/app_values.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// Status codes for automation operations (matches Python enum)
enum AutomationStatus {
  success,
  proxyValidationFailed,
  browserError,
  timeout,
  captchaRequired,
  unknownError;

  factory AutomationStatus.fromString(String value) {
    switch (value) {
      case 'success':
        return AutomationStatus.success;
      case 'proxy_validation_failed':
        return AutomationStatus.proxyValidationFailed;
      case 'browser_error':
        return AutomationStatus.browserError;
      case 'timeout':
        return AutomationStatus.timeout;
      case 'captcha_required':
        return AutomationStatus.captchaRequired;
      default:
        return AutomationStatus.unknownError;
    }
  }
}

/// Result of an automation operation
class AutomationResult {
  final AutomationStatus status;
  final String message;
  final String? expectedIp;
  final String? actualIp;
  final Map<String, dynamic>? data;

  AutomationResult({
    required this.status,
    required this.message,
    this.expectedIp,
    this.actualIp,
    this.data,
  });

  factory AutomationResult.fromJson(Map<String, dynamic> json) {
    return AutomationResult(
      status: AutomationStatus.fromString(json['status'] ?? 'unknown_error'),
      message: json['message'] ?? 'Unknown error',
      expectedIp: json['expected_ip'],
      actualIp: json['actual_ip'],
      data: json['data'],
    );
  }

  factory AutomationResult.error(String message) {
    return AutomationResult(
      status: AutomationStatus.unknownError,
      message: message,
    );
  }

  bool get isSuccess => status == AutomationStatus.success;
  bool get needsCaptcha => status == AutomationStatus.captchaRequired;
  bool get proxyFailed => status == AutomationStatus.proxyValidationFailed;
}

/// Service for managing browser automation tasks
class AutomationService extends GetxService {
  /// Observable states
  final isRunning = false.obs;
  final currentTask = Rxn<String>();
  final lastResult = Rxn<AutomationResult>();
  final logs = <String>[].obs;
  final isCancelling = false.obs;

  /// Default timeout for automation tasks (2 minutes)
  static const Duration defaultTimeout = Duration(minutes: 2);

  /// Currently running process (for cancellation)
  Process? _currentProcess;

  /// Get the scripts directory path
  String get _scriptsPath {
    // Get the executable directory and navigate to scripts
    final execDir = path.dirname(Platform.resolvedExecutable);

    // In development, scripts are next to lib
    // In production, they should be bundled with the app
    final devScriptsPath = path.join(
      path.dirname(path.dirname(execDir)),
      'scripts',
    );

    // Check if we're in development
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

    // Fallback to bundled scripts
    return path.join(execDir, 'data', 'scripts');
  }

  /// Add a log entry
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    logs.add('[$timestamp] $message');
    logger.i('[Automation] $message');
  }

  /// Clear logs
  void clearLogs() {
    logs.clear();
  }

  /// Cancel the currently running automation task
  Future<void> cancelCurrentTask() async {
    if (!isRunning.value || _currentProcess == null) {
      _log('No task to cancel');
      return;
    }

    isCancelling.value = true;
    _log('Cancelling current task...');

    try {
      // Kill the process and any child processes
      final killed = _currentProcess!.kill(ProcessSignal.sigterm);
      if (!killed) {
        // Force kill if graceful termination fails
        _currentProcess!.kill(ProcessSignal.sigkill);
      }
      _log('Task cancelled');
    } catch (e) {
      _log('Error cancelling task: $e');
    } finally {
      _currentProcess = null;
      isRunning.value = false;
      isCancelling.value = false;
      currentTask.value = null;
    }
  }

  /// Run a Python script with timeout and cancellation support
  Future<({int exitCode, String stdout, String stderr})> _runPythonScript(
    List<String> args, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;
    _log('Running Python with timeout: ${effectiveTimeout.inSeconds}s');

    final stdout = StringBuffer();
    final stderr = StringBuffer();

    _currentProcess =
        await Process.start('python', args, workingDirectory: _scriptsPath);

    // Listen to stdout/stderr
    _currentProcess!.stdout.listen((data) {
      stdout.write(String.fromCharCodes(data));
    });

    _currentProcess!.stderr.listen((data) {
      stderr.write(String.fromCharCodes(data));
    });

    // Wait for process with timeout
    try {
      final exitCode = await _currentProcess!.exitCode.timeout(
        effectiveTimeout,
        onTimeout: () {
          _log('Script timed out after ${effectiveTimeout.inSeconds}s');
          _currentProcess?.kill(ProcessSignal.sigterm);
          throw TimeoutException('Script timed out', effectiveTimeout);
        },
      );
      return (
        exitCode: exitCode,
        stdout: stdout.toString(),
        stderr: stderr.toString()
      );
    } on TimeoutException {
      _currentProcess?.kill(ProcessSignal.sigkill);
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  /// Build proxy URL from slot entity
  /// Format: username:password@proxyhost:port
  String? _buildProxyUrl(ProxySlotEntity slot) {
    try {
      // Log slot details for debugging
      _log('Building proxy URL for slot #${slot.slotNumber}');
      _log('  Slot ID: ${slot.id}');
      _log('  Username: ${slot.username}');
      _log('  Password: ${slot.password.replaceAll(RegExp(r'.'), '*')}');
      _log('  Port: ${slot.port}');

      // Validate slot has required fields
      if (slot.username.isEmpty || slot.password.isEmpty) {
        logger.e('Slot #${slot.slotNumber} missing username or password');
        return null;
      }

      // Use AppValues for proxy host configuration
      final proxyHost = AppValues.proxyHost;
      final proxyPort = AppValues.proxyPort;
      _log('  Proxy Host: $proxyHost');
      _log('  Proxy Port: $proxyPort');

      // Build proxy URL in format: username:password@host:port
      final proxyUrl =
          '${slot.username}:${slot.password}@$proxyHost:$proxyPort';
      _log(
          '  Final Proxy URL format: ${slot.username}:***@$proxyHost:$proxyPort');
      return proxyUrl;
    } catch (e) {
      logger.e('Error building proxy URL: $e');
      return null;
    }
  }

  /// Validate proxy IP matches expected
  Future<AutomationResult> validateProxyIp({
    required ProxySlotEntity slot,
  }) async {
    if (isRunning.value) {
      return AutomationResult.error('Another automation task is running');
    }

    // Check Python setup
    final pythonSetup = Get.find<PythonSetupService>();
    if (!pythonSetup.isSetupComplete.value) {
      _log('Python dependencies not installed, installing now...');
      final success = await pythonSetup.installDependencies();
      if (!success) {
        return AutomationResult.error(
          'Python setup failed: ${pythonSetup.setupError.value ?? "Unknown error"}',
        );
      }

      // Verify installation succeeded
      _log('Verifying Python dependency installation...');
      final verified = await pythonSetup.checkDependenciesInstalled();
      if (!verified) {
        return AutomationResult.error(
          'Python dependencies installation completed but verification failed. '
          'Please check that seleniumbase is properly installed.',
        );
      }
      _log('Python dependencies verified successfully');
    }

    isRunning.value = true;
    currentTask.value = 'Validating proxy IP';
    _log('Starting proxy validation for slot #${slot.slotNumber}');

    try {
      // Get expected IP from slot
      final proxyController = Get.find<ProxyController>();
      final currentIp = proxyController.getCurrentIpForSlot(slot);

      if (currentIp == null) {
        final result = AutomationResult.error(
          'No IP assigned to slot #${slot.slotNumber}',
        );
        lastResult.value = result;
        return result;
      }

      final expectedIp = currentIp.ipAddress;
      final proxyUrl = _buildProxyUrl(slot);

      if (proxyUrl == null) {
        final result = AutomationResult.error(
          'Could not build proxy URL for slot #${slot.slotNumber}',
        );
        lastResult.value = result;
        return result;
      }

      _log('Expected IP: $expectedIp');
      _log('Proxy URL: $proxyUrl');

      // Run Python script
      final scriptPath = path.join(_scriptsPath, 'account_automation.py');
      _log('Running script: $scriptPath');

      final args = [
        scriptPath,
        'validate',
        proxyUrl,
        expectedIp,
        '--debug', // Enable verbose logging for better debugging
      ];

      // Log the full command for debugging
      _log('Full Python command:');
      _log('  python ${args.join(' ')}'
          .replaceAll(RegExp(r':[^:@]+@'), ':***@'));

      final result = await _runPythonScript(args);

      _log('Script exit code: ${result.exitCode}');

      // Parse result from output
      final output = result.stdout;
      final stderr = result.stderr;

      if (stderr.isNotEmpty) {
        _log('Script errors: $stderr');

        // If stderr contains import errors, provide helpful message
        if (stderr.contains('ModuleNotFoundError') ||
            stderr.contains('No module named')) {
          return AutomationResult.error('Python dependency error: $stderr\n\n'
              'Please ensure Python dependencies are installed correctly. '
              'Try running: python -m pip install -r scripts/requirements.txt');
        }
      }

      if (result.exitCode != 0) {
        return AutomationResult.error(
          'Script failed with exit code ${result.exitCode}:\n$stderr',
        );
      }

      // Find JSON result in output
      final resultJson = _extractJsonResult(output);

      if (resultJson != null) {
        final automationResult = AutomationResult.fromJson(resultJson);
        lastResult.value = automationResult;
        _log(
            'Result: ${automationResult.status.name} - ${automationResult.message}');
        return automationResult;
      } else {
        final automationResult = AutomationResult.error(
          'Could not parse script output: $output',
        );
        lastResult.value = automationResult;
        return automationResult;
      }
    } on TimeoutException catch (e) {
      _log('Timeout: $e');
      final result = AutomationResult(
        status: AutomationStatus.timeout,
        message:
            'Proxy validation timed out. The browser may be stuck. Try again or check your proxy settings.',
      );
      lastResult.value = result;
      return result;
    } catch (e) {
      _log('Error: $e');
      final result = AutomationResult.error('Failed to run automation: $e');
      lastResult.value = result;
      return result;
    } finally {
      isRunning.value = false;
      currentTask.value = null;
      _currentProcess = null;
    }
  }

  /// Create RuneScape session with validated proxy
  Future<AutomationResult> createAccountSession({
    required ProxySlotEntity slot,
  }) async {
    if (isRunning.value) {
      return AutomationResult.error('Another automation task is running');
    }

    // Check Python setup
    final pythonSetup = Get.find<PythonSetupService>();
    if (!pythonSetup.isSetupComplete.value) {
      _log('Python dependencies not installed, installing now...');
      final success = await pythonSetup.installDependencies();
      if (!success) {
        return AutomationResult.error(
          'Python setup failed: ${pythonSetup.setupError.value ?? "Unknown error"}',
        );
      }

      // Verify installation succeeded
      _log('Verifying Python dependency installation...');
      final verified = await pythonSetup.checkDependenciesInstalled();
      if (!verified) {
        return AutomationResult.error(
          'Python dependencies installation completed but verification failed. '
          'Please check that seleniumbase is properly installed.',
        );
      }
      _log('Python dependencies verified successfully');
    }

    isRunning.value = true;
    currentTask.value = 'Creating account session';
    _log('Starting account session for slot #${slot.slotNumber}');

    try {
      // Get expected IP from slot
      final proxyController = Get.find<ProxyController>();
      final currentIp = proxyController.getCurrentIpForSlot(slot);

      if (currentIp == null) {
        final result = AutomationResult.error(
          'No IP assigned to slot #${slot.slotNumber}',
        );
        lastResult.value = result;
        return result;
      }

      final expectedIp = currentIp.ipAddress;
      final proxyUrl = _buildProxyUrl(slot);

      if (proxyUrl == null) {
        final result = AutomationResult.error(
          'Could not build proxy URL for slot #${slot.slotNumber}',
        );
        lastResult.value = result;
        return result;
      }

      _log('Expected IP: $expectedIp');
      _log('Proxy URL: $proxyUrl');

      // Run Python script
      final scriptPath = path.join(_scriptsPath, 'account_automation.py');
      _log('Running script: $scriptPath');

      final args = [
        scriptPath,
        'session',
        proxyUrl,
        expectedIp,
        '--keep-open',
        '--debug', // Enable verbose logging
      ];

      // Start process without waiting (browser stays open)
      _currentProcess = await Process.start('python', args);

      // Capture output for a bit to check for immediate errors
      final outputBuffer = StringBuffer();
      final subscription =
          _currentProcess!.stdout.transform(utf8.decoder).listen(
        (data) {
          outputBuffer.write(data);
          _log(data.trim());
        },
      );

      // Wait a few seconds for initial setup
      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();

      // If process exited quickly, it might have failed
      // Try to get result from output
      final output = outputBuffer.toString();

      if (output.contains('RESULT')) {
        final resultJson = _extractJsonResult(output);
        if (resultJson != null) {
          final automationResult = AutomationResult.fromJson(resultJson);
          lastResult.value = automationResult;
          return automationResult;
        }
      }

      // Process is still running, which means browser is open
      final result = AutomationResult(
        status: AutomationStatus.success,
        message: 'Browser session started - check browser window',
        expectedIp: expectedIp,
      );
      lastResult.value = result;
      return result;
    } catch (e) {
      _log('Error: $e');
      final result = AutomationResult.error('Failed to create session: $e');
      lastResult.value = result;
      return result;
    } finally {
      isRunning.value = false;
      currentTask.value = null;
    }
  }

  /// Extract JSON result from script output
  Map<String, dynamic>? _extractJsonResult(String output) {
    try {
      // Look for the result marker
      final resultMarker = '=== RESULT ===';
      final markerIndex = output.indexOf(resultMarker);

      if (markerIndex != -1) {
        final jsonStart = markerIndex + resultMarker.length;
        final jsonStr = output.substring(jsonStart).trim();

        // Find the JSON object
        final openBrace = jsonStr.indexOf('{');
        if (openBrace != -1) {
          var braceCount = 0;
          var closeBrace = openBrace;

          for (var i = openBrace; i < jsonStr.length; i++) {
            if (jsonStr[i] == '{') braceCount++;
            if (jsonStr[i] == '}') braceCount--;
            if (braceCount == 0) {
              closeBrace = i;
              break;
            }
          }

          final jsonObject = jsonStr.substring(openBrace, closeBrace + 1);
          return json.decode(jsonObject);
        }
      }
    } catch (e) {
      logger.e('Error parsing JSON result: $e');
    }
    return null;
  }
}
