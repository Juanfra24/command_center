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

}
