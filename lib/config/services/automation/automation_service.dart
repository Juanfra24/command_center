import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/automation/python_runner.dart';
import 'package:command_center/config/services/automation/result_parser.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/core/constants/app_values.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/account.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// Service for managing browser automation tasks
class AutomationService extends GetxService {
  /// Observable states
  final isRunning = false.obs;
  final currentTask = Rxn<String>();
  final lastResult = Rxn<AutomationResult>();
  final logs = <String>[].obs;

  /// Default timeout for automation tasks (2 minutes)
  static const Duration defaultTimeout = Duration(minutes: 2);

  /// Longer timeout for account creation (10 minutes — email verification takes time)
  static const Duration accountCreationTimeout = Duration(minutes: 10);

  /// Python process runner
  late final PythonRunner _runner = PythonRunner(onLog: _log);

  /// Forwarded from PythonRunner
  RxBool get isCancelling => _runner.isCancelling;

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
    if (!isRunning.value || !_runner.isProcessRunning) {
      _log('No task to cancel');
      return;
    }

    _log('Cancelling current task...');

    try {
      await _runner.cancel();
      _log('Task cancelled');
    } catch (e) {
      _log('Error cancelling task: $e');
    } finally {
      isRunning.value = false;
      currentTask.value = null;
    }
  }

  /// Run a Python script with timeout and cancellation support
  Future<({int exitCode, String stdout, String stderr})> _runPythonScript(
    List<String> args, {
    Duration? timeout,
  }) async {
    return _runner.run(
      args,
      workingDirectory: _scriptsPath,
      timeout: timeout ?? defaultTimeout,
    );
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
      final resultJson = ResultParser.extractJsonResult(output);

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
      _log('Verifying Python dependency installation...');
      final verified = await pythonSetup.checkDependenciesInstalled();
      if (!verified) {
        return AutomationResult.error(
          'Python dependencies verification failed.',
        );
      }
      _log('Python dependencies verified successfully');
    }

    isRunning.value = true;
    currentTask.value = 'Creating Jagex account';
    _log('Starting account creation for slot #${slot.slotNumber}');

    try {
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

      // Fetch IMAP credentials from config
      final appConfig = Get.find<AppConfigService>();
      final imapHost = await appConfig.getImapHost();
      final imapUser = await appConfig.getImapUser();
      final imapPass = await appConfig.getImapPass();

      final scriptPath = path.join(_scriptsPath, 'account_automation.py');
      _log('Running script: $scriptPath create-account');

      final args = [
        scriptPath,
        'create-account',
        proxyUrl,
        expectedIp,
        '--debug',
        if (imapHost != null) ...['--imap-host', imapHost],
        if (imapUser != null) ...['--imap-user', imapUser],
        if (imapPass != null) ...['--imap-pass', imapPass],
      ];

      _log('Full Python command:');
      _log('  python ${args.join(' ')}'
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

      final resultJson = ResultParser.extractJsonResult(output);

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

      // Start process — browser stays open until user closes it.
      // -u flag disables Python's stdout buffering.
      final sessionProcess = await Process.start('python', ['-u', ...args],
          workingDirectory: _scriptsPath);

      // Capture output to check for immediate errors (e.g. proxy unreachable)
      final outputBuffer = StringBuffer();
      sessionProcess.stdout.transform(utf8.decoder).listen(
        (data) {
          outputBuffer.write(data);
          _log(data.trim());
        },
      );
      sessionProcess.stderr.transform(utf8.decoder).listen(
        (data) {
          _log('[stderr] ${data.trim()}');
        },
      );

      // Wait a bit for the browser to start and proxy to connect
      await Future.delayed(const Duration(seconds: 8));

      // If process exited quickly, it failed
      final output = outputBuffer.toString();
      if (output.contains('RESULT')) {
        final resultJson = ResultParser.extractJsonResult(output);
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
}
