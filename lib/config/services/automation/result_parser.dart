import 'dart:convert';

import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/core/helper/logger.dart';

class ResultParser {
  /// Extract JSON result from script output after the === RESULT === marker
  static Map<String, dynamic>? extractJsonResult(String output) {
    try {
      final resultMarker = '=== RESULT ===';
      final markerIndex = output.indexOf(resultMarker);

      if (markerIndex != -1) {
        final jsonStart = markerIndex + resultMarker.length;
        final jsonStr = output.substring(jsonStart).trim();

        final openBrace = jsonStr.indexOf('{');
        if (openBrace != -1) {
          var braceCount = 0;
          var closeBrace = openBrace;

          for (var i = openBrace; i < jsonStr.length; i++) {
            if (jsonStr[i] == '{') braceCount++;
            if (jsonStr[i] == '}') braceCount--;
            if (braceCount == 0) {
              closeBrace = i;
              break;
            }
          }

          // If braces never balanced, closeBrace == openBrace — skip
          if (braceCount != 0) return null;

          final jsonObject = jsonStr.substring(openBrace, closeBrace + 1);
          return json.decode(jsonObject);
        }
      }
    } catch (e) {
      logger.e('Error parsing JSON result: $e');
    }
    return null;
  }

  /// Process the full output of a completed script run into an [AutomationResult].
  ///
  /// Checks stderr for module errors, verifies exit code, then parses JSON.
  /// [onLog] is called for diagnostic messages.
  static AutomationResult processScriptOutput({
    required int exitCode,
    required String stdout,
    required String stderr,
    required void Function(String) onLog,
    String timeoutMessage = 'Operation timed out.',
  }) {
    onLog('Script exit code: $exitCode');

    if (stderr.isNotEmpty) {
      // Log only a summary — raw stderr may contain credentials from tracebacks
      onLog(
          'Script reported ${stderr.split('\n').length} error line(s). See log file for details.');
      logger.e('Python stderr: $stderr');

      // Module import errors are fatal — no JSON result will exist
      if (stderr.contains('ModuleNotFoundError') ||
          stderr.contains('No module named')) {
        return AutomationResult.error(
          'Python dependency error: $stderr\n\n'
          'Please ensure Python dependencies are installed correctly. '
          'Try running: python -m pip install -r scripts/requirements.txt',
        );
      }
    }

    // Always try to parse JSON result first — Python writes structured
    // results even on failure (exit code 1). The JSON contains the real
    // error info (captcha_required, proxy_validation_failed, etc).
    final resultJson = extractJsonResult(stdout);
    if (resultJson != null) {
      final result = AutomationResult.fromJson(resultJson);
      onLog('Result: ${result.status.name} - ${result.message}');
      return result;
    }

    // No JSON found — fall back to exit code + stderr
    if (exitCode != 0) {
      return AutomationResult.error(
        'Script failed with exit code $exitCode:\n$stderr',
      );
    }

    return AutomationResult.error(
      'Could not parse script output: $stdout',
    );
  }
}
