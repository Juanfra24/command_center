import 'dart:io';

import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:path/path.dart' as p;

class MicrobotEngine implements BotEngine {
  final String javaPath;
  String jarPath;
  final MicrobotProfileWriter _profileWriter;
  final NativeCommandsService _nativeCommands;
  final JagexTokenService _jagexTokenService;
  final void Function(String message) onLog;
  final void Function()? onOutdated;

  final Set<int> _activePids = {};
  final Map<int, int> _pidToCharacterId = {};
  bool _outdatedSignaled = false;

  MicrobotEngine({
    required this.javaPath,
    required this.jarPath,
    required String profilesBasePath,
    required NativeCommandsService nativeCommands,
    required JagexTokenService jagexTokenService,
    required this.onLog,
    this.onOutdated,
  })  : _profileWriter =
            MicrobotProfileWriter(profilesBasePath: profilesBasePath),
        _nativeCommands = nativeCommands,
        _jagexTokenService = jagexTokenService;

  @override
  String get engineName => 'Microbot';

  @override
  bool get isOutdated => _outdatedSignaled;

  /// Reset after a successful JAR update so clients can be relaunched.
  void resetOutdated() => _outdatedSignaled = false;

  @override
  Future<LaunchResult> launch({
    required int characterId,
    required int accountId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  }) async {
    final profileDir = _profileWriter.profilePath(characterId: characterId);

    // Seed Jagex token before writing profile
    try {
      await _jagexTokenService.seedToken(
        accountId: accountId,
        email: email,
        password: password,
        profileDir: profileDir,
        skipBrowserFallback:
            true, // browser auth is only triggered on account creation
      );
    } catch (e) {
      // Log but don't fail launch — legacy accounts don't need Jagex token
      onLog('[MicrobotEngine] Warning: Jagex token seeding failed: $e');
    }

    await _profileWriter.writeProfile(
      characterId: characterId,
      email: email,
      password: password,
      world: config.world,
      scriptName: config.scriptName,
      scriptParams: config.scriptParams,
    );

    final args = buildLaunchArgs(
        characterId: characterId, proxyUrl: proxyUrl, config: config);

    logger.i('Launching Microbot for $characterName (id=$characterId)');

    // Poll for status port file (max 10s, 500ms intervals)
    final portFilePath = p.join(
      _profileWriter.profilePath(characterId: characterId),
      'status.port',
    );
    // Delete any stale port file from a previous crashed session BEFORE
    // starting the process, so we cannot accidentally delete the file written
    // by the newly-launched process.
    final staleFile = File(portFilePath);
    if (await staleFile.exists()) {
      await staleFile.delete();
    }

    final process = await Process.start(javaPath, args);
    final pid = process.pid;

    _activePids.add(pid);
    _pidToCharacterId[pid] = characterId;

    process.stdout.transform(const SystemEncoding().decoder).listen((data) {
      onLog('[Microbot:$characterName] ${_redactCredentials(data)}');
      if (!_outdatedSignaled &&
          data.contains('error_game_js5connect_outofdate')) {
        _outdatedSignaled = true;
        onOutdated?.call();
      }
    });
    process.stderr.transform(const SystemEncoding().decoder).listen((data) {
      onLog('[Microbot:$characterName:ERR] ${_redactCredentials(data)}');
    });

    process.exitCode.then((_) {
      _activePids.remove(pid);
      _pidToCharacterId.remove(pid);
    });
    int? statusPort;
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      // Abort early if process already exited
      if (!_activePids.contains(pid)) {
        logger.w('Process $pid exited before Status API was ready');
        break;
      }
      final portFile = File(portFilePath);
      if (await portFile.exists()) {
        final content = (await portFile.readAsString()).trim();
        statusPort = int.tryParse(content);
        if (statusPort != null) {
          logger.i('Status API port for $characterName: $statusPort');
          break;
        }
      }
    }

    return (pid: pid, statusPort: statusPort);
  }

  @override
  Future<void> stop(int pid) async {
    final characterId = _pidToCharacterId[pid];
    await _nativeCommands.killProcess(pid);
    _activePids.remove(pid);
    _pidToCharacterId.remove(pid);
    if (characterId != null) {
      await _profileWriter.deleteProfile(characterId: characterId);
    }
  }

  List<String> buildLaunchArgs({
    required int characterId,
    required String? proxyUrl,
    required LaunchConfig config,
  }) {
    final profileDir = _profileWriter.profilePath(characterId: characterId);
    final args = <String>[];
    final jvmArgs = (config.jvmArgs == null || config.jvmArgs!.isEmpty)
        ? '-Xmx512m'
        : config.jvmArgs!;
    if (jvmArgs.contains('"') || jvmArgs.contains("'")) {
      logger.w(
          'JVM args contain quotes which may not be split correctly: $jvmArgs');
    }
    args.addAll(jvmArgs.split(' ').where((s) => s.isNotEmpty));
    args.add('-Djagex.userhome=${p.join(profileDir, 'jagex')}');
    args.addAll(['-jar', jarPath]);
    args.add('--cc-profile-dir=$profileDir');
    args.add('--status-port-file=${p.join(profileDir, 'status.port')}');
    if (proxyUrl != null) {
      args.add('--proxy=$proxyUrl');
    }
    args.add('--safe-mode');
    if (config.scriptParams.isNotEmpty) {
      args.add('--script-params=${config.scriptParams}');
    }
    if (config.advancedFlags.isNotEmpty) {
      args.addAll(config.advancedFlags.split(' ').where((s) => s.isNotEmpty));
    }
    return args;
  }

  Future<void> cleanStaleProfiles(Set<int> liveCharacterIds) async {
    await _profileWriter.cleanStaleProfiles(liveCharacterIds: liveCharacterIds);
  }

  @override
  void registerRecapturedPid({required int pid, required int characterId}) {
    _activePids.add(pid);
    _pidToCharacterId[pid] = characterId;
  }

  Set<int> get activePids => Set.unmodifiable(_activePids);

  static final _credentialPattern = RegExp(r'password=\S+');
  static String _redactCredentials(String data) =>
      data.replaceAll(_credentialPattern, 'password=***');
}
