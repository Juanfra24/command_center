import 'dart:io';

import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/Status/data/process_model.dart';

/// Linux implementation using ps and kill (pure Dart, no native code).
class NativeCommandsLinux implements NativeCommandsService {
  @override
  Future<List<ProcessClient>> listJavaProcesses() async {
    try {
      final result = await Process.run(
        'ps',
        ['-eo', 'pid,comm,args', '--no-headers'],
      );
      if (result.exitCode != 0) {
        logger.e('ps command failed: ${result.stderr}');
        return [];
      }
      return parsePsOutput(result.stdout as String);
    } catch (e) {
      logger.e('Failed to list Java processes: $e');
      return [];
    }
  }

  /// Parse ps output into ProcessClient list.
  /// Format: `  PID COMM            ARGS...`
  /// Filters where COMM is exactly "java".
  static List<ProcessClient> parsePsOutput(String output) {
    final processes = <ProcessClient>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Split into at most 3 parts: PID, COMM, ARGS
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;

      final pid = int.tryParse(parts[0]);
      final comm = parts[1];
      final args = parts.sublist(2).join(' ');

      if (pid != null && comm == 'java') {
        processes.add(ProcessClient(
          processId: pid,
          commandLine: args,
        ));
      }
    }
    return processes;
  }

  @override
  Future<void> killProcess(int pid) async {
    try {
      // Send SIGTERM first for graceful shutdown
      await Process.run('kill', ['-15', '$pid']);
      // Wait briefly for process to exit
      await Future.delayed(const Duration(seconds: 2));
      // Force kill if still alive
      await Process.run('kill', ['-9', '$pid']);
    } catch (e) {
      logger.e('Failed to kill process $pid: $e');
    }
  }
}
