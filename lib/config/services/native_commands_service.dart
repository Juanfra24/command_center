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

  /// Launch a DreamBot game client via CreateProcess.
  /// Returns the child process PID.
  Future<int> runGameClient({
    required String characterName,
    required String? proxyAddress,
    required String scriptName,
    String world = 'auto',
    bool covert = true,
    String render = 'NONE',
    String scriptParams = '',
    String advancedFlags = '',
  }) async {
    try {
      final int pid = await _platform.invokeMethod('runGameClient', {
        'characterName': characterName,
        'proxyAddress': proxyAddress ?? 'none',
        'scriptName': scriptName,
        'world': world,
        'covert': covert,
        'render': render,
        'scriptParams': scriptParams,
        'advancedFlags': advancedFlags,
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

  /// Run a generic CMD command.
  Future<String> runCmdCommand(String command) async {
    try {
      final String result =
          await _platform.invokeMethod('runCmdCommand', {'command': command});
      return result;
    } on PlatformException catch (e) {
      logger.e('Failed to run CMD command: ${e.message}');
      rethrow;
    }
  }
}
