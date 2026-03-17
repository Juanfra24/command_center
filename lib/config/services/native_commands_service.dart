import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:flutter/services.dart';

class NativeCommandsService {
  static const _platform = MethodChannel('com.onemanco/commands');

  /// List running Java processes via WMI COM API.
  /// Returns structured data directly — no base64 decoding.
  Future<List<ProcessClient>> listJavaProcesses() async {
    try {
      final List<dynamic> result =
          await _platform.invokeMethod('listJavaProcesses');
      return ProcessClient.fromPlatformList(result);
    } on PlatformException catch (e) {
      logger.e('Failed to get Java processes: ${e.message}');
      return [];
    }
  }

  /// Kill a process and its children via taskkill.
  Future<void> killProcess(int pid) async {
    try {
      await _platform.invokeMethod('killProcessAndChilds', {'pid': pid});
    } on PlatformException catch (e) {
      logger.e('Failed to kill process $pid: ${e.message}');
    }
  }

  /// Launch a game client via CreateProcess.
  /// Returns the child process PID.
  Future<int> runGameClient({
    required String characterName,
    required String? proxyUrl,
    required String scriptName,
    String world = 'auto',
    String scriptParams = '',
    String advancedFlags = '',
    String? jvmArgs,
  }) async {
    try {
      final int pid = await _platform.invokeMethod('runGameClient', {
        'characterName': characterName,
        'proxyUrl': proxyUrl ?? 'none',
        'scriptName': scriptName,
        'world': world,
        'scriptParams': scriptParams,
        'advancedFlags': advancedFlags,
        if (jvmArgs != null) 'jvmArgs': jvmArgs,
        'destroyOnBan': true,
        'destroy': true,
        'minimized': true,
      });
      logger.i('Game client started for $characterName (PID: $pid)');
      return pid;
    } on PlatformException catch (e) {
      logger.e('Failed to run game client: ${e.message}');
      rethrow;
    }
  }
}
