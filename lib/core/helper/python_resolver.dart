import 'dart:async';
import 'dart:io';

import 'package:command_center/core/helper/logger.dart';
import 'package:path/path.dart' as p;

/// Resolves the correct Python executable for the current platform.
///
/// On Linux, modern distros (Ubuntu 24.04+, Debian 12+) use PEP 668 which
/// blocks system-wide pip installs. To work around this, we create a virtual
/// environment in the app data directory and use its Python for all operations.
///
/// On Windows, the system Python is used directly (no venv needed).
class PythonResolver {
  static String? _cached;
  static String? _appDataDir;
  static Completer<String>? _resolving;

  /// Set the app data directory (called during DI initialization).
  /// Used to create/find the venv on Linux.
  static void setAppDataDir(String dir) => _appDataDir = dir;

  /// Get the cached Python executable, or resolve it.
  /// Uses a Completer to prevent concurrent callers from racing to create
  /// the venv simultaneously.
  static Future<String> get executable async {
    if (_cached != null) return _cached!;
    if (_resolving != null) return _resolving!.future;
    _resolving = Completer<String>();
    try {
      _cached = await resolve();
      _resolving!.complete(_cached!);
      return _cached!;
    } catch (e) {
      _resolving!.completeError(e);
      rethrow;
    } finally {
      _resolving = null;
    }
  }

  /// Resolve which Python command to use.
  /// On Linux: creates a venv if needed and returns the venv python.
  /// On Windows: returns system python.
  static Future<String> resolve() async {
    if (!Platform.isWindows && _appDataDir != null) {
      // Try venv python first
      final venvPython = await _resolveVenvPython();
      if (venvPython != null) return venvPython;
    }

    // System python fallback
    final candidates =
        Platform.isWindows ? ['python', 'python3'] : ['python3', 'python'];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, ['--version']);
        if (result.exitCode == 0) {
          logger.i(
              'Python resolved to: $candidate (${(result.stdout as String).trim()})');
          return candidate;
        }
      } catch (_) {}
    }
    throw Exception(
        'Python not found. Install Python 3.8+ and ensure it is in PATH.');
  }

  /// Find the system python3 binary (not the venv one).
  /// Used to create the venv itself.
  static Future<String> _findSystemPython() async {
    for (final candidate in ['python3', 'python']) {
      try {
        final result = await Process.run(candidate, ['--version']);
        if (result.exitCode == 0) return candidate;
      } catch (_) {}
    }
    throw Exception('Python not found');
  }

  /// Create a venv and return the venv python path, or return existing venv python.
  static Future<String?> _resolveVenvPython() async {
    final venvDir = p.join(_appDataDir!, 'python_venv');
    final venvPython = p.join(venvDir, 'bin', 'python');

    // If venv already exists and works, use it
    if (File(venvPython).existsSync()) {
      try {
        final result = await Process.run(venvPython, ['--version']);
        if (result.exitCode == 0) {
          logger.i(
              'Using venv Python: $venvPython (${(result.stdout as String).trim()})');
          return venvPython;
        }
      } catch (_) {}
    }

    // Create venv using system python
    try {
      final systemPython = await _findSystemPython();
      logger.i('Creating Python venv at $venvDir...');
      final result = await Process.run(
        systemPython,
        ['-m', 'venv', venvDir],
      );
      if (result.exitCode == 0 && File(venvPython).existsSync()) {
        logger.i('Python venv created successfully');
        return venvPython;
      }
      logger.w('Failed to create venv: ${result.stderr}');
    } catch (e) {
      logger.w('Venv creation error: $e');
    }

    return null;
  }

  /// Reset the cache (for testing/retry).
  static void resetCache() => _cached = null;
}
