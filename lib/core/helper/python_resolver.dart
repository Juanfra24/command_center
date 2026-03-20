import 'dart:io';

import 'package:command_center/core/helper/logger.dart';

/// Resolves the correct Python executable name for the current platform.
/// On Linux, `python3` is tried first (most distros don't have bare `python`).
/// On Windows, `python` is tried first (ships with the Python launcher).
/// Result is cached after first successful resolution.
class PythonResolver {
  static String? _cached;

  /// Get the cached Python executable, or resolve it.
  static Future<String> get executable async {
    return _cached ??= await resolve();
  }

  /// Resolve which Python command is available.
  static Future<String> resolve() async {
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

  /// Reset the cache (for testing).
  static void resetCache() => _cached = null;
}
