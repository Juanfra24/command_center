import 'dart:convert';
import 'dart:io';

import 'package:command_center/config/services/automation/python_runner.dart';
import 'package:command_center/config/services/automation/result_parser.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Manages Jagex OAuth token lifecycle for bot accounts.
///
/// Before each bot launch, [seedToken] is called to ensure a fresh
/// game session token is written to `<profileDir>/jagex/credentials.properties`.
/// Fast path: HTTP refresh using the stored refresh token (seconds).
/// Slow path: Patchright browser flow via Python, used on first auth or
/// when the refresh token has expired (weeks/months).
class JagexTokenService {
  final DatabaseService _db;
  final PythonRunner _pythonRunner;

  static const _tokenUrl = 'https://account.jagex.com/oauth2/token';
  static const _sessionUrl = 'https://auth.jagex.com/game-session/v1/sessions';
  static const _accountsUrl = 'https://auth.jagex.com/game-session/v1/accounts';
  static const _clientId = 'com_jagex_auth_desktop_launcher';

  JagexTokenService({
    required DatabaseService db,
    required PythonRunner pythonRunner,
  })  : _db = db,
        _pythonRunner = pythonRunner;

  /// Returns the jagex home dir path for a given profile dir.
  /// This is what gets passed as `-Djagex.userhome` to the JVM.
  static String jagexHomeDir(String profileDir) => p.join(profileDir, 'jagex');

  /// Write the game client credentials file at
  /// `<profileDir>/jagex/credentials.properties`.
  /// Static so it can be tested independently.
  static Future<void> writeCredentialsFile({
    required String profileDir,
    required String sessionId,
    required String characterId,
    required String displayName,
  }) async {
    final jagexDir = Directory(jagexHomeDir(profileDir));
    await jagexDir.create(recursive: true);

    final content = [
      '#Do not share this file with anyone',
      'JX_CHARACTER_ID=$characterId',
      'JX_SESSION_ID=$sessionId',
      'JX_REFRESH_TOKEN=',
      'JX_DISPLAY_NAME=$displayName',
      'JX_ACCESS_TOKEN=',
      '',
    ].join('\n');

    await File(p.join(jagexDir.path, 'credentials.properties'))
        .writeAsString(content);
  }

  /// Seed the Jagex credentials file before launching a bot.
  /// Tries HTTP refresh first; falls back to full Patchright browser auth.
  /// Set [skipBrowserFallback] to true to disable the slow browser auth path
  /// (e.g. during bot launches where first-time auth is not expected).
  Future<void> seedToken({
    required int accountId,
    required String email,
    required String password,
    required String profileDir,
    String? imapHost,
    String? imapUser,
    String? imapPass,
    bool skipBrowserFallback = false,
  }) async {
    final account = await _db.accountRepository.getAccountById(accountId);
    if (account == null) throw Exception('Account $accountId not found');

    if (account.jagexRefreshToken != null) {
      try {
        logger
            .i('[JagexToken] Refreshing token via HTTP for account $accountId');
        final (idToken, newRefreshToken) =
            await _httpRefreshIdToken(account.jagexRefreshToken!);
        final session = await _getGameSession(idToken);
        await writeCredentialsFile(
          profileDir: profileDir,
          sessionId: session.$1,
          characterId: account.jagexCharacterId ?? session.$2,
          displayName: account.jagexDisplayName ?? session.$3,
        );
        // Persist rotated refresh token so next refresh still works
        if (newRefreshToken != null) {
          await _db.accountRepository.updateJagexToken(
            accountId: accountId,
            refreshToken: newRefreshToken,
            characterId: account.jagexCharacterId ?? session.$2,
            displayName: account.jagexDisplayName ?? session.$3,
          );
        }
        logger.i('[JagexToken] Token seeded via HTTP refresh');
        return;
      } catch (e) {
        logger.w(
            '[JagexToken] HTTP refresh failed ($e), falling back to browser auth');
      }
    }

    if (skipBrowserFallback) {
      logger.w(
          '[JagexToken] No refresh token stored and browser fallback disabled — skipping');
      return;
    }

    logger.i('[JagexToken] Running browser auth for account $accountId');
    await _acquireViaAutomation(
      accountId: accountId,
      email: email,
      password: password,
      profileDir: profileDir,
      imapHost: imapHost,
      imapUser: imapUser,
      imapPass: imapPass,
    );
  }

  // ── Private ───────────────────────────────────────────────────────────────

  /// Returns (idToken, newRefreshToken). newRefreshToken may be null if not rotated.
  Future<(String, String?)> _httpRefreshIdToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Token refresh HTTP ${response.statusCode}: ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = json['id_token'] as String?;
    if (idToken == null) {
      throw Exception('id_token missing from refresh response');
    }
    final newRefreshToken = json['refresh_token'] as String?;
    return (idToken, newRefreshToken);
  }

  /// Returns (sessionId, characterId, displayName).
  Future<(String, String, String)> _getGameSession(String idToken) async {
    final sessionResp = await http.post(
      Uri.parse(_sessionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (sessionResp.statusCode != 200) {
      throw Exception('Session API HTTP ${sessionResp.statusCode}');
    }
    final sessionId = (jsonDecode(sessionResp.body)
        as Map<String, dynamic>)['sessionId'] as String;

    final accountsResp = await http.get(
      Uri.parse(_accountsUrl),
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (accountsResp.statusCode != 200) {
      throw Exception('Accounts API HTTP ${accountsResp.statusCode}');
    }
    final accounts = jsonDecode(accountsResp.body) as List;
    if (accounts.isEmpty) {
      throw Exception('No accounts in game-session response');
    }

    final first = accounts.first as Map<String, dynamic>;
    return (
      sessionId,
      first['accountId'] as String,
      first['displayName'] as String,
    );
  }

  Future<void> _acquireViaAutomation({
    required int accountId,
    required String email,
    required String password,
    required String profileDir,
    String? imapHost,
    String? imapUser,
    String? imapPass,
  }) async {
    final args = [
      _pythonRunner.scriptFile,
      'jagex-auth',
      '--email',
      email,
      '--profile-dir',
      jagexHomeDir(profileDir),
      if (imapHost != null) ...['--imap-host', imapHost],
    ];
    _pythonRunner.logCommand(args);

    final env = <String, String>{
      'CC_ACCOUNT_PASS': password,
      if (imapUser != null) 'CC_IMAP_USER': imapUser,
      if (imapPass != null) 'CC_IMAP_PASS': imapPass,
    };

    final raw = await _pythonRunner.run(
      args,
      workingDirectory: _pythonRunner.scriptsPath,
      timeout: const Duration(minutes: 5),
      environment: env,
    );

    final result = ResultParser.processScriptOutput(
      exitCode: raw.exitCode,
      stdout: raw.stdout,
      stderr: raw.stderr,
      onLog: (msg) => logger.i('[JagexToken] $msg'),
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception('jagex-auth automation failed: ${result.message}');
    }

    final refreshToken = result.data!['refresh_token'] as String?;
    final characterId = result.data!['character_id'] as String?;
    final displayName = result.data!['display_name'] as String?;

    if (refreshToken == null || characterId == null || displayName == null) {
      throw Exception('jagex-auth returned incomplete data: ${result.data}');
    }

    await _db.accountRepository.updateJagexToken(
      accountId: accountId,
      refreshToken: refreshToken,
      characterId: characterId,
      displayName: displayName,
    );

    logger.i('[JagexToken] Token stored in DB and credentials file written');
  }
}
