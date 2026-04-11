import 'dart:async';
import 'dart:io';

import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/automation/python_runner.dart';
import 'package:command_center/config/services/automation/result_parser.dart';
import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/account.dart';
import 'package:command_center/domain/entities/character.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/entities/skills.dart';
import 'package:get/get.dart';

/// Orchestrates browser automation by delegating process management to
/// [PythonRunner] and output parsing to [ResultParser].
class AutomationService extends GetxService {
  final isRunning = false.obs;
  final currentTask = Rxn<String>();
  final lastResult = Rxn<AutomationResult>();
  final logs = <String>[].obs;

  static const Duration defaultTimeout = Duration(minutes: 2);
  static const Duration accountCreationTimeout = Duration(minutes: 10);

  late final PythonRunner _runner = PythonRunner(onLog: _log);
  RxBool get isCancelling => _runner.isCancelling;

  @override
  void onClose() {
    unawaited(_runner.cleanupDetachedSessions());
    super.onClose();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    logs.add('[$timestamp] $message');
    logger.i('[Automation] $message');
  }

  void clearLogs() => logs.clear();

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

  /// Returns an error [AutomationResult] if setup fails, otherwise null.
  Future<AutomationResult?> _ensurePythonSetup() async {
    final ps = Get.find<PythonSetupService>();
    if (ps.isSetupComplete) return null;
    _log('Python dependencies not installed, installing now...');
    if (!await ps.installDependencies()) {
      return AutomationResult.error(
        'Python setup failed: ${ps.setupError ?? "Unknown error"}',
      );
    }
    _log('Verifying Python dependency installation...');
    if (!await ps.checkDependenciesInstalled()) {
      return AutomationResult.error(
        'Python dependencies verification failed. '
        'Please check that patchright is properly installed.',
      );
    }
    _log('Python dependencies verified successfully');
    return null;
  }

  /// Resolve proxy URL + expected IP. Sets [lastResult] on failure.
  Future<({String expectedIp, String proxyUrl})?> _resolveProxy(
      ProxySlotEntity slot) async {
    if (slot.id == null) {
      lastResult.value = AutomationResult.error(
        'Slot #${slot.slotNumber} has no database ID',
      );
      return null;
    }
    final db = Get.find<DatabaseService>();
    final currentIp = await db.proxyRepository.getActiveIpForSlot(slot.id!);
    if (currentIp == null) {
      lastResult.value = AutomationResult.error(
        'No IP assigned to slot #${slot.slotNumber}',
      );
      return null;
    }
    final proxyUrl = _runner.buildProxyUrl(slot);
    if (proxyUrl == null) {
      lastResult.value = AutomationResult.error(
        'Could not build proxy URL for slot #${slot.slotNumber}',
      );
      return null;
    }
    _log('Expected IP: ${currentIp.ipAddress}');
    _log(
        'Proxy URL length: ${proxyUrl.length} chars (non-empty: ${proxyUrl.isNotEmpty})');
    return (expectedIp: currentIp.ipAddress, proxyUrl: proxyUrl);
  }

  /// Guard + setup + resolve + run [body] + error handling.
  Future<AutomationResult> _executeTask({
    required String taskName,
    required ProxySlotEntity slot,
    required Future<AutomationResult> Function(String ip, String proxy) body,
    String timeoutMessage = 'Operation timed out.',
  }) async {
    if (isRunning.value) {
      return AutomationResult.error('Another automation task is running');
    }
    final setupErr = await _ensurePythonSetup();
    if (setupErr != null) return setupErr;

    isRunning.value = true;
    currentTask.value = taskName;
    _log('Starting $taskName for slot #${slot.slotNumber}');
    try {
      final p = await _resolveProxy(slot);
      if (p == null) return lastResult.value!;
      return await body(p.expectedIp, p.proxyUrl);
    } on TimeoutException {
      _log('Timeout during $taskName');
      final r = AutomationResult(
          status: AutomationStatus.timeout, message: timeoutMessage);
      lastResult.value = r;
      return r;
    } catch (e) {
      _log('Error: $e');
      final r = AutomationResult.error('Failed during $taskName: $e');
      lastResult.value = r;
      return r;
    } finally {
      isRunning.value = false;
      currentTask.value = null;
    }
  }

  /// Run script via [PythonRunner], parse via [ResultParser].
  Future<AutomationResult> _runAndParse(
    List<String> args, {
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    _runner.logCommand(args);
    final raw = await _runner.run(
      args,
      workingDirectory: _runner.scriptsPath,
      timeout: timeout ?? defaultTimeout,
      environment: environment,
    );
    final result = ResultParser.processScriptOutput(
      exitCode: raw.exitCode,
      stdout: raw.stdout,
      stderr: raw.stderr,
      onLog: _log,
    );
    lastResult.value = result;
    return result;
  }

  /// Build environment map with sensitive credentials (not exposed in argv).
  Map<String, String> _buildSecureEnv(String proxyUrl,
      {String? imapUser, String? imapPass}) {
    final env = <String, String>{
      'CC_PROXY_URL': proxyUrl,
    };
    if (imapUser != null) env['CC_IMAP_USER'] = imapUser;
    if (imapPass != null) env['CC_IMAP_PASS'] = imapPass;
    return env;
  }

  /// Validate proxy IP matches expected.
  Future<AutomationResult> validateProxyIp({
    required ProxySlotEntity slot,
  }) =>
      _executeTask(
        taskName: 'Validating proxy IP',
        slot: slot,
        timeoutMessage: 'Proxy validation timed out. The browser may be stuck. '
            'Try again or check your proxy settings.',
        body: (ip, proxy) => _runAndParse(
          [
            _runner.scriptFile,
            'validate',
            ip,
            '--debug',
          ],
          environment: _buildSecureEnv(proxy),
        ),
      );

  /// Create a new Jagex account through the proxy.
  Future<AutomationResult> createAccount({
    required ProxySlotEntity slot,
  }) =>
      _executeTask(
        taskName: 'Creating Jagex account',
        slot: slot,
        timeoutMessage: 'Account creation timed out. The browser may be stuck '
            'on captcha or loading.',
        body: (ip, proxy) async {
          final imapService = Get.find<ImapConfigService>();
          final imapHost = await imapService.getHost();
          final imapUser = await imapService.getUser();
          final imapPass = await imapService.getPass();
          final result = await _runAndParse(
            [
              _runner.scriptFile,
              'create-account',
              ip,
              '--debug',
              if (imapHost != null) ...['--imap-host', imapHost],
            ],
            timeout: accountCreationTimeout,
            environment:
                _buildSecureEnv(proxy, imapUser: imapUser, imapPass: imapPass),
          );
          if (result.isAccountCreated && result.data != null) {
            // Strict success rule (per product): only treat as success when
            // Python confirmed the account + character were fully created.
            // Anything else is a partial failure the user needs to see.
            final confirmed = result.data!['confirmed'] == true;
            final accountName = result.data!['accountName'] as String? ?? '';
            if (!confirmed || accountName.isEmpty) {
              _log('Account creation reported but not confirmed — '
                  'rejecting as error (confirmed=$confirmed, '
                  'accountName="$accountName")');
              final errorResult = AutomationResult.error(
                'Account creation did not complete: Jagex never confirmed '
                'the account + character. Check browser logs.',
              );
              lastResult.value = errorResult;
              return errorResult;
            }
            _log('Account email: ${result.data!['email'] ?? 'N/A'}');
            final accountId = await _persistAccount(result.data!, slot);
            // Strict success rule: if the account cannot be persisted to
            // the DB, the bot farm has no record of it — treat the entire
            // operation as an error so the UI reflects the real state.
            if (accountId == null) {
              final errorResult = AutomationResult.error(
                'Account created in browser but failed to persist to '
                'database. The account may exist on Jagex but is not '
                'tracked locally. Check logs for details.',
              );
              lastResult.value = errorResult;
              return errorResult;
            }
            // Acquire and store Jagex OAuth token immediately so first
            // launch uses HTTP refresh instead of slow browser auth.
            try {
              final tokenService = Get.find<JagexTokenService>();
              final tempDir =
                  Directory.systemTemp.createTempSync('jagex_auth_');
              try {
                await tokenService.seedToken(
                  accountId: accountId,
                  email: result.data!['email'] as String? ?? '',
                  password: result.data!['password'] as String? ?? '',
                  profileDir: tempDir.path,
                );
                _log(
                    'Jagex token acquired and stored for account $accountId');
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            } catch (e) {
              _log(
                  'Warning: Failed to acquire Jagex token: $e (will retry at first launch)');
            }
          }
          return result;
        },
      );

  /// Launch a browser session detached from the app process.
  /// The browser runs independently — closing the app does not kill it.
  Future<AutomationResult> createAccountSession({
    required ProxySlotEntity slot,
  }) =>
      _executeTask(
        taskName: 'Launching browser session',
        slot: slot,
        body: (ip, proxy) async {
          final args = [_runner.scriptFile, 'session', ip, '--debug'];
          _runner.logCommand(args);
          await _runner.launchDetached(
            args,
            workingDirectory: _runner.scriptsPath,
            environment: _buildSecureEnv(proxy),
          );
          final r = AutomationResult(
            status: AutomationStatus.success,
            message: 'Browser launched — close the window when done.',
            expectedIp: ip,
          );
          lastResult.value = r;
          return r;
        },
      );

  Future<int?> _persistAccount(
      Map<String, dynamic> data, ProxySlotEntity slot) async {
    try {
      final db = Get.find<DatabaseService>();
      final accountName = data['accountName'] ?? '';
      final account = AccountEntity(
        accountName: accountName,
        email: data['email'] ?? '',
        password: data['password'] ?? '',
        birthday: data['dob'] ?? '',
        proxySlotId: slot.id,
        characters: accountName.isNotEmpty
            ? [
                CharacterEntity(
                  accountId: 0, // Will be set by repository after insert
                  name: accountName,
                  banned: false,
                  actualSkills: SkillsEntity.empty(),
                  targetSkills: SkillsEntity.empty(),
                ),
              ]
            : const [],
      );
      final id = await db.accountRepository.insertAccount(account);
      _log('Account persisted to database with ID: $id');
      return id;
    } catch (e) {
      _log('Warning: Failed to persist account to database: $e');
      return null;
    }
  }
}
