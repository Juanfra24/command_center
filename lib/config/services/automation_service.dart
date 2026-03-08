import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/core/constants/app_values.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/scripts_path.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/account.dart';
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
  accountCreated,
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
      case 'account_created':
        return AutomationStatus.accountCreated;
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

  bool get isSuccess => status == AutomationStatus.success || status == AutomationStatus.accountCreated;
  bool get isAccountCreated => status == AutomationStatus.accountCreated;
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

  /// Longer timeout for account creation (10 minutes — email verification takes time)
  static const Duration accountCreationTimeout = Duration(minutes: 10);

  /// Currently running process (for cancellation)
  Process? _currentProcess;

  /// Get the scripts directory path (cached, shared with PythonSetupService)
  String get _scriptsPath => scriptsPath;

  /// Maximum number of log entries to keep
  static const int _maxLogEntries = 500;

  /// Add a log entry (capped to prevent unbounded growth)
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    logs.add('[$timestamp] $message');
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
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

    // -u flag disables Python's stdout/stderr buffering so we get logs in real-time
    _currentProcess =
        await Process.start('python', ['-u', ...args], workingDirectory: _scriptsPath);

    // Listen to stdout/stderr and forward to logs in real-time
    _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
      stdout.write(data);
      // Forward each line to the log for real-time visibility
      for (final line in data.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('===')) {
          _log('[py] $trimmed');
        }
      }
    });

    _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
      stderr.write(data);
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

  /// Ensure Python environment is ready, installing if needed.
  /// Returns null on success, or an error [AutomationResult] on failure.
  Future<AutomationResult?> _ensurePythonReady() async {
    final pythonSetup = Get.find<PythonSetupService>();
    if (pythonSetup.isSetupComplete.value) return null;

    _log('Python dependencies not installed, installing now...');
    final success = await pythonSetup.installDependencies();
    if (!success) {
      return AutomationResult.error(
        'Python setup failed: ${pythonSetup.setupError.value ?? "Unknown error"}',
      );
    }

    _log('Verifying Python dependency installation...');
    final verified = await pythonSetup.checkDependenciesInstalled();
    if (!verified) {
      return AutomationResult.error(
        'Python dependencies installation completed but verification failed. '
        'Please check that seleniumbase is properly installed.',
      );
    }
    _log('Python dependencies verified successfully');
    return null;
  }

  /// Resolve the proxy URL and expected IP for a slot.
  /// Returns the resolved values or sets [lastResult] and returns null on failure.
  ({String expectedIp, String proxyUrl})? _resolveProxyForSlot(
      ProxySlotEntity slot) {
    final proxyController = Get.find<ProxyController>();
    final currentIp = proxyController.getCurrentIpForSlot(slot);

    if (currentIp == null) {
      final result = AutomationResult.error(
        'No IP assigned to slot #${slot.slotNumber}',
      );
      lastResult.value = result;
      return null;
    }

    final proxyUrl = _buildProxyUrl(slot);
    if (proxyUrl == null) {
      final result = AutomationResult.error(
        'Could not build proxy URL for slot #${slot.slotNumber}',
      );
      lastResult.value = result;
      return null;
    }

    return (expectedIp: currentIp.ipAddress, proxyUrl: proxyUrl);
  }

  /// Build proxy URL from slot entity
  /// Format: username:password@proxyhost:port
  String? _buildProxyUrl(ProxySlotEntity slot) {
    if (slot.username.isEmpty || slot.password.isEmpty) {
      logger.e('Slot #${slot.slotNumber} missing username or password');
      return null;
    }

    final proxyHost = AppValues.proxyHost;
    final proxyPort = AppValues.proxyPort;
    _log('Building proxy URL for slot #${slot.slotNumber} '
        '(${slot.username}:***@$proxyHost:$proxyPort)');

    return '${slot.username}:${slot.password}@$proxyHost:$proxyPort';
  }

  /// Validate proxy IP matches expected
  Future<AutomationResult> validateProxyIp({
    required ProxySlotEntity slot,
  }) async {
    if (isRunning.value) {
      return AutomationResult.error('Another automation task is running');
    }

    final pythonError = await _ensurePythonReady();
    if (pythonError != null) return pythonError;

    isRunning.value = true;
    currentTask.value = 'Validating proxy IP';
    _log('Starting proxy validation for slot #${slot.slotNumber}');

    try {
      final proxy = _resolveProxyForSlot(slot);
      if (proxy == null) return lastResult.value!;

      _log('Expected IP: ${proxy.expectedIp}');

      // Run Python script
      final scriptPath = path.join(_scriptsPath, 'account_automation.py');

      final args = [
        scriptPath,
        'validate',
        proxy.proxyUrl,
        proxy.expectedIp,
        '--debug',
      ];

      _log('Running: python ${args.join(' ')}'
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

  /// Create a new Jagex account through the proxy
  /// This runs the create-account command which:
  /// 1. Validates proxy IP
  /// 2. Navigates to account.jagex.com
  /// 3. Handles captcha & cookie consent
  /// 4. Fills registration form with random email @onemanco.org
  /// 5. Submits the form
  Future<AutomationResult> createAccount({
    required ProxySlotEntity slot,
  }) async {
    if (isRunning.value) {
      return AutomationResult.error('Another automation task is running');
    }

    final pythonError = await _ensurePythonReady();
    if (pythonError != null) return pythonError;

    isRunning.value = true;
    currentTask.value = 'Creating Jagex account';
    _log('Starting account creation for slot #${slot.slotNumber}');

    try {
      final proxy = _resolveProxyForSlot(slot);
      if (proxy == null) return lastResult.value!;

      _log('Expected IP: ${proxy.expectedIp}');

      // Fetch IMAP credentials from config
      final appConfig = Get.find<AppConfigService>();
      final imapHost = await appConfig.getImapHost();
      final imapUser = await appConfig.getImapUser();
      final imapPass = await appConfig.getImapPass();

      final scriptPath = path.join(_scriptsPath, 'account_automation.py');

      final args = [
        scriptPath,
        'create-account',
        proxy.proxyUrl,
        proxy.expectedIp,
        '--debug',
        if (imapHost != null) ...['--imap-host', imapHost],
        if (imapUser != null) ...['--imap-user', imapUser],
        if (imapPass != null) ...['--imap-pass', imapPass],
      ];

      _log('Running: python ${args.join(' ')}'
          .replaceAll(RegExp(r':[^:@]+@'), ':***@'));

      final result = await _runPythonScript(
        args,
        timeout: accountCreationTimeout,
      );

      _log('Script exit code: ${result.exitCode}');

      final output = result.stdout;
      final stderr = result.stderr;

      if (stderr.isNotEmpty) {
        _log('Script errors: $stderr');
        if (stderr.contains('ModuleNotFoundError') ||
            stderr.contains('No module named')) {
          return AutomationResult.error('Python dependency error: $stderr');
        }
      }

      final resultJson = _extractJsonResult(output);

      if (resultJson != null) {
        final automationResult = AutomationResult.fromJson(resultJson);
        lastResult.value = automationResult;
        _log(
            'Result: ${automationResult.status.name} - ${automationResult.message}');
        if (automationResult.data != null) {
          _log('Account email: ${automationResult.data!['email'] ?? 'N/A'}');
        }

        // Persist created account to database
        if (automationResult.isAccountCreated && automationResult.data != null) {
          try {
            final dbService = Get.find<DatabaseService>();
            final accountRepo = dbService.accountRepository;
            final data = automationResult.data!;

            final account = AccountEntity(
              accountName: data['accountName'] ?? '',
              email: data['email'] ?? '',
              password: data['password'] ?? '',
              birthday: data['dob'] ?? '',
              proxySlotId: slot.id,
              characters: const [],
            );

            final insertedId = await accountRepo.insertAccount(account);
            _log('Account persisted to database with ID: $insertedId');
          } catch (e) {
            _log('Warning: Failed to persist account to database: $e');
          }
        }

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
            'Account creation timed out. The browser may be stuck on captcha or loading.',
      );
      lastResult.value = result;
      return result;
    } catch (e) {
      _log('Error: $e');
      final result =
          AutomationResult.error('Failed to create account: $e');
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

    final pythonError = await _ensurePythonReady();
    if (pythonError != null) return pythonError;

    isRunning.value = true;
    currentTask.value = 'Creating account session';
    _log('Starting account session for slot #${slot.slotNumber}');

    try {
      final proxy = _resolveProxyForSlot(slot);
      if (proxy == null) return lastResult.value!;

      _log('Expected IP: ${proxy.expectedIp}');

      final scriptPath = path.join(_scriptsPath, 'account_automation.py');

      final args = [
        scriptPath,
        'session',
        proxy.proxyUrl,
        proxy.expectedIp,
        '--keep-open',
        '--debug', // Enable verbose logging
      ];

      // Start process — browser stays open until user closes it.
      // -u flag disables Python's stdout buffering.
      _currentProcess = await Process.start('python', ['-u', ...args],
          workingDirectory: _scriptsPath);

      // Capture output to check for immediate errors (e.g. proxy unreachable)
      final outputBuffer = StringBuffer();
      _currentProcess!.stdout.transform(utf8.decoder).listen(
        (data) {
          outputBuffer.write(data);
          _log(data.trim());
        },
      );
      _currentProcess!.stderr.transform(utf8.decoder).listen(
        (data) {
          _log('[stderr] ${data.trim()}');
        },
      );

      // Wait a bit for the browser to start and proxy to connect
      await Future.delayed(const Duration(seconds: 8));

      // If process exited quickly, it failed
      final output = outputBuffer.toString();
      if (output.contains('RESULT')) {
        final resultJson = _extractJsonResult(output);
        if (resultJson != null) {
          final automationResult = AutomationResult.fromJson(resultJson);
          lastResult.value = automationResult;
          return automationResult;
        }
      }

      // Process is still running = browser is open and working
      final result = AutomationResult(
        status: AutomationStatus.success,
        message: 'Browser launched with proxy - close browser window when done',
        expectedIp: proxy.expectedIp,
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
