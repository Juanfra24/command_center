import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:command_center/core/constants/app_values.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/python_resolver.dart';
import 'package:command_center/core/helper/scripts_path.dart' as sp;
import 'package:command_center/domain/entities/proxy_slot.dart';
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

  /// Resolve the scripts directory — delegates to shared resolver.
  String get scriptsPath => sp.scriptsPath;

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

  /// Build a minimal environment map for Python subprocesses that explicitly
  /// whitelists only the OS-level variables required to run Python (PATH,
  /// HOME, TEMP, etc.), merged with the caller-supplied map. This blocks
  /// credential bleed from the parent process: any stray env var left behind
  /// by a prior launch or the shell that started the app never reaches Python.
  static Map<String, String> buildSubprocessEnv(
      [Map<String, String>? extra]) {
    const allowed = <String>{
      'PATH',
      'HOME',
      'USER',
      'LANG',
      'LC_ALL',
      'LC_CTYPE',
      'TMPDIR',
      'TMP',
      'TEMP',
      'USERPROFILE',
      'SYSTEMROOT',
      'SYSTEMDRIVE',
      'WINDIR',
      'COMSPEC',
      'PATHEXT',
      'APPDATA',
      'LOCALAPPDATA',
      'PROGRAMFILES',
      'PROGRAMFILES(X86)',
      'PROGRAMDATA',
      'DISPLAY',
      'XAUTHORITY',
      'XDG_RUNTIME_DIR',
      'XDG_CONFIG_HOME',
      'XDG_DATA_HOME',
      'XDG_CACHE_HOME',
      'SHELL',
      'PYTHONPATH',
      'PYTHONHOME',
    };
    final env = <String, String>{};
    Platform.environment.forEach((key, value) {
      if (allowed.contains(key.toUpperCase())) {
        env[key] = value;
      }
    });
    if (extra != null) {
      env.addAll(extra);
    }
    return env;
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
    final python = await PythonResolver.executable;
    // includeParentEnvironment: false + whitelist prevents credential bleed
    // from the parent process (e.g. stray secrets set earlier in the session).
    _currentProcess = await Process.start(
      python,
      ['-u', ...args],
      workingDirectory: workingDirectory,
      environment: buildSubprocessEnv(environment),
      includeParentEnvironment: false,
    );

    // We never write to stdin — close it so the script can't block
    // waiting on input() and leave the process hung past its timeout.
    unawaited(_currentProcess!.stdin.close().catchError((_) {}));

    // Listen to stdout/stderr and forward to logs in real-time.
    // Suppress all lines after the === RESULT === marker (contains credentials in JSON).
    var seenResultMarker = false;
    final stdoutDone =
        _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
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
    final stderrDone =
        _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
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
      // Drain orphaned stream subscriptions so they don't leak after kill
      await Future.wait([
        stdoutDone.catchError((_) {}),
        stderrDone.catchError((_) {}),
      ]).timeout(const Duration(seconds: 2), onTimeout: () => []);
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  /// Launch a browser session fully detached from this process.
  /// The child process survives app close — no stdout/stderr in detached mode.
  Future<void> launchDetached(
    List<String> args, {
    required String workingDirectory,
    Map<String, String>? environment,
  }) async {
    final python = await PythonResolver.executable;
    // ProcessStartMode.detachedWithStdio gives us exitCode, detached gives
    // nothing. We use detached for true orphaning, and accept we can't watch
    // for exit — but we can at least probe liveness on cleanup (see
    // cleanupDetachedSessions) so we don't SIGTERM a recycled PID.
    final process = await Process.start(
      python,
      ['-u', ...args],
      workingDirectory: workingDirectory,
      environment: buildSubprocessEnv(environment),
      includeParentEnvironment: false,
      mode: ProcessStartMode.detached,
    );
    _detachedSessionPids.add(process.pid);
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
  Future<void> cleanupDetachedSessions() async {
    for (final pid in _detachedSessionPids) {
      try {
        // On Linux, probe with `kill -0` before sending SIGTERM so we don't
        // signal a recycled PID belonging to an unrelated process. Detached
        // browsers outlive the app, so the delay between launch and cleanup
        // is large enough for the kernel to reuse the PID once the browser
        // has exited.
        if (Platform.isLinux) {
          final probe = await Process.run('kill', ['-0', '$pid']);
          if (probe.exitCode != 0) continue;
        }
        Process.killPid(pid, ProcessSignal.sigterm);
      } catch (_) {
        // Process may have already exited
      }
    }
    _detachedSessionPids.clear();
  }
}
