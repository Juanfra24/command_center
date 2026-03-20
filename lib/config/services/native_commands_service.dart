import 'package:command_center/feature/Status/data/process_model.dart';

/// Platform-agnostic interface for OS process operations.
/// Windows uses WMI COM API via method channel.
/// Linux uses ps/kill via pure Dart.
abstract class NativeCommandsService {
  /// List running Java processes with their PIDs and full command lines.
  Future<List<ProcessClient>> listJavaProcesses();

  /// Kill a process (and its children on Windows) by PID.
  Future<void> killProcess(int pid);
}
