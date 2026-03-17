import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:command_center/core/constants/app_values.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// Manages Python process lifecycle: spawning, output capture, timeout, cancellation.
class PythonRunner {
  Process? _currentProcess;
  final List<int> _detachedSessionPids = [];
  final isCancelling = false.obs;

  /// Callback for log lines from Python stdout
  final void Function(String message) onLog;

  PythonRunner({required this.onLog});

  /// Resolve the scripts directory (development or production).
  String get scriptsPath {
    final execDir = path.dirname(Platform.resolvedExecutable);

    // In development, scripts are next to lib
    final devScriptsPath = path.join(
      path.dirname(path.dirname(execDir)),
      'scripts',
    );
    if (Directory(devScriptsPath).existsSync()) return devScriptsPath;

    // Try relative to workspace (development only — USERPROFILE is user-controlled)
    if (kDebugMode) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isNotEmpty) {
        final workspacePath = path.join(
          userProfile,
          'projects',
          'command_center',
          'scripts',
        );
        if (Directory(workspacePath).existsSync()) return workspacePath;
      }
    }

    // Fallback to bundled scripts
    return path.join(execDir, 'data', 'scripts');
  }

  /// Full path to account_automation.py
  String get scriptFile => path.join(scriptsPath, 'account_automation.py');

  /// Build proxy URL from a slot entity.
  /// Format: username:password@proxyhost:port
  String? buildProxyUrl(ProxySlotEntity slot) {
    try {
      onLog('Building proxy URL for slot #${slot.slotNumber}');
      onLog('  Slot ID: ${slot.id}');
      onLog('  Port: ${slot.port}');

      if (slot.username.isEmpty || slot.password.isEmpty) {
        logger.e('Slot #${slot.slotNumber} missing username or password');
        return null;
      }

      final proxyHost = AppValues.proxyHost;
      final proxyPort = AppValues.proxyPort;
      onLog('  Proxy Host: $proxyHost');
      onLog('  Proxy Port: $proxyPort');

      final proxyUrl =
          '${slot.username}:${slot.password}@$proxyHost:$proxyPort';
      onLog(
          '  Final Proxy URL format: ${slot.username}:***@$proxyHost:$proxyPort');
      return proxyUrl;
    } catch (e) {
      logger.e('Error building proxy URL: $e');
      return null;
    }
  }

  /// Redact secrets from a string (proxy creds and named flag values).
  static String redact(String input) {
    return input
        .replaceAll(RegExp(r':[^:@]+@'), ':***@') // proxy user:pass@host
        .replaceAll(RegExp(r'--imap-pass\s+\S+'), '--imap-pass ***')
        .replaceAll(RegExp(r'--imap-user\s+\S+'), '--imap-user ***');
  }

  /// Log redacted command for debugging
  void logCommand(List<String> args) {
    onLog('Full Python command:');
    onLog(redact('  python ${args.join(' ')}'));
  }

  /// Run a Python script with timeout and cancellation support.
  /// Sensitive credentials should be passed via [environment] instead of [args].
  Future<({int exitCode, String stdout, String stderr})> run(
    List<String> args, {
    required String workingDirectory,
    Duration timeout = const Duration(minutes: 2),
    Map<String, String>? environment,
  }) async {
    onLog('Running Python with timeout: ${timeout.inSeconds}s');

    final stdout = StringBuffer();
    final stderr = StringBuffer();

    // -u flag disables Python's stdout/stderr buffering so we get logs in real-time
    _currentProcess = await Process.start('python', ['-u', ...args],
        workingDirectory: workingDirectory,
        environment: environment);

    // Listen to stdout/stderr and forward to logs in real-time.
    // Suppress all lines after the === RESULT === marker (contains credentials in JSON).
    var seenResultMarker = false;
    final stdoutDone = _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
      stdout.write(data);
      for (final line in data.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.contains('=== RESULT ===')) {
          seenResultMarker = true;
          continue;
        }
        if (!seenResultMarker && trimmed.isNotEmpty) {
          onLog('[py] ${redact(trimmed)}');
        }
      }
    }).asFuture<void>();

    // Redact stderr to prevent credential leakage from Python tracebacks
    final stderrDone = _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
      stderr.write(data);
      for (final line in data.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          onLog('[py:err] ${redact(trimmed)}');
        }
      }
    }).asFuture<void>();

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
      // Ensure all stream data is consumed before reading buffers
      await Future.wait([
        stdoutDone.catchError((_) {}),
        stderrDone.catchError((_) {}),
      ]);
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

  /// Start a long-running session process (browser stays open).
  /// Returns early after [warmup] delay with captured output so far.
  Future<({String output, bool exited})> startSession(
    List<String> args, {
    required String workingDirectory,
    Duration warmup = const Duration(seconds: 8),
    Map<String, String>? environment,
  }) async {
    final outputBuffer = StringBuffer();

    _currentProcess = await Process.start('python', ['-u', ...args],
        workingDirectory: workingDirectory,
        environment: environment);

    _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
      outputBuffer.write(data);
      onLog(data.trim());
    });

    _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
      onLog('[stderr] ${data.trim()}');
    });

    // Wait for the browser to start and proxy to connect
    await Future.delayed(warmup);

    final output = outputBuffer.toString();
    final exited = output.contains('RESULT');

    // Track the detached PID for cleanup on app close
    if (_currentProcess != null) {
      _detachedSessionPids.add(_currentProcess!.pid);
    }
    _currentProcess = null;

    return (output: output, exited: exited);
  }

  /// Cancel the currently running process
  Future<void> cancel() async {
    if (_currentProcess == null) return;

    isCancelling.value = true;
    try {
      final killed = _currentProcess!.kill(ProcessSignal.sigterm);
      if (!killed) {
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

  /// Clean up any detached session processes.
  /// Call this on app close to avoid orphaned browser processes.
  void cleanupDetachedSessions() {
    for (final pid in _detachedSessionPids) {
      try {
        Process.killPid(pid, ProcessSignal.sigterm);
      } catch (_) {
        // Process may have already exited
      }
    }
    _detachedSessionPids.clear();
  }
}
