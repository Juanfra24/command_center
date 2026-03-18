import 'dart:io';

import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:path/path.dart' as p;

class MicrobotEngine implements BotEngine {
  final String javaPath;
  final String jarPath;
  final MicrobotProfileWriter _profileWriter;
  final NativeCommandsService _nativeCommands;
  final void Function(String message) onLog;

  final Set<int> _activePids = {};
  final Map<int, int> _pidToCharacterId = {};

  MicrobotEngine({
    required this.javaPath,
    required this.jarPath,
    required String profilesBasePath,
    required NativeCommandsService nativeCommands,
    required this.onLog,
  })  : _profileWriter = MicrobotProfileWriter(profilesBasePath: profilesBasePath),
        _nativeCommands = nativeCommands;

  @override
  String get engineName => 'Microbot';

  @override
  Future<LaunchResult> launch({
    required int characterId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  }) async {
    await _profileWriter.writeProfile(
      characterId: characterId,
      email: email,
      password: password,
      world: config.world,
      scriptName: config.scriptName,
    );

    final args = buildLaunchArgs(characterId: characterId, proxyUrl: proxyUrl, config: config);

    logger.i('Launching Microbot for $characterName (id=$characterId)');

    final process = await Process.start(javaPath, args);
    final pid = process.pid;

    _activePids.add(pid);
    _pidToCharacterId[pid] = characterId;

    process.stdout.transform(const SystemEncoding().decoder).listen((data) {
      onLog('[Microbot:$characterName] ${_redactCredentials(data)}');
    });
    process.stderr.transform(const SystemEncoding().decoder).listen((data) {
      onLog('[Microbot:$characterName:ERR] ${_redactCredentials(data)}');
    });

    process.exitCode.then((_) {
      _activePids.remove(pid);
      _pidToCharacterId.remove(pid);
    });

    // Poll for status port file (max 10s, 500ms intervals)
    final portFilePath = p.join(
      _profileWriter.profilePath(characterId: characterId),
      'status.port',
    );
    int? statusPort;
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
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
    final jvmArgs = config.jvmArgs ?? '-Xmx512m';
    args.addAll(jvmArgs.split(' ').where((s) => s.isNotEmpty));
    args.addAll(['-jar', jarPath]);
    args.add('--cc-profile-dir=$profileDir');
    args.add('--status-port-file=${p.join(profileDir, 'status.port')}');
    if (proxyUrl != null) {
      args.add('--proxy=$proxyUrl');
    }
    args.add('--safe-mode');
    if (config.advancedFlags.isNotEmpty) {
      args.addAll(config.advancedFlags.split(' ').where((s) => s.isNotEmpty));
    }
    return args;
  }

  Future<void> cleanStaleProfiles(Set<int> liveCharacterIds) async {
    await _profileWriter.cleanStaleProfiles(liveCharacterIds: liveCharacterIds);
  }

  Set<int> get activePids => Set.unmodifiable(_activePids);

  static final _credentialPattern = RegExp(r'password=\S+');
  static String _redactCredentials(String data) =>
      data.replaceAll(_credentialPattern, 'password=***');
}
