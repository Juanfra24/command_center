import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

/// Manages Python process lifecycle: spawning, output capture, timeout, cancellation.
class PythonRunner {
  Process? _currentProcess;
  final isCancelling = false.obs;

  /// Callback for log lines from Python stdout
  final void Function(String message) onLog;

  PythonRunner({required this.onLog});

  /// Run a Python script with timeout and cancellation support
  Future<({int exitCode, String stdout, String stderr})> run(
    List<String> args, {
    required String workingDirectory,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    onLog('Running Python with timeout: ${timeout.inSeconds}s');

    final stdout = StringBuffer();
    final stderr = StringBuffer();

    // -u flag disables Python's stdout/stderr buffering so we get logs in real-time
    _currentProcess = await Process.start('python', ['-u', ...args],
        workingDirectory: workingDirectory);

    // Listen to stdout/stderr and forward to logs in real-time
    _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
      stdout.write(data);
      // Forward each line to the log for real-time visibility
      for (final line in data.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('===')) {
          onLog('[py] $trimmed');
        }
      }
    });

    _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
      stderr.write(data);
    });

    // Wait for process with timeout
    try {
      final exitCode = await _currentProcess!.exitCode.timeout(
        timeout,
        onTimeout: () {
          onLog('Script timed out after ${timeout.inSeconds}s');
          _currentProcess?.kill(ProcessSignal.sigterm);
          throw TimeoutException('Script timed out', timeout);
        },
      );
      return (
        exitCode: exitCode,
        stdout: stdout.toString(),
        stderr: stderr.toString()
      );
    } on TimeoutException {
      _currentProcess?.kill(ProcessSignal.sigkill);
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  /// Cancel the currently running process
  Future<void> cancel() async {
    if (_currentProcess == null) {
      return;
    }

    isCancelling.value = true;

    try {
      // Kill the process and any child processes
      final killed = _currentProcess!.kill(ProcessSignal.sigterm);
      if (!killed) {
        // Force kill if graceful termination fails
        _currentProcess!.kill(ProcessSignal.sigkill);
      }
    } catch (_) {
      // Ignore errors during cancellation
    } finally {
      _currentProcess = null;
      isCancelling.value = false;
    }
  }

  bool get isProcessRunning => _currentProcess != null;
}
