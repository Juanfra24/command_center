import 'dart:convert';
import 'package:command_center/core/helper/logger.dart';

class ResultParser {
  /// Extract JSON result from script output after the === RESULT === marker
  static Map<String, dynamic>? extractJsonResult(String output) {
    try {
      // Look for the result marker
      final resultMarker = '=== RESULT ===';
      final markerIndex = output.indexOf(resultMarker);

      if (markerIndex != -1) {
        final jsonStart = markerIndex + resultMarker.length;
        final jsonStr = output.substring(jsonStart).trim();

        // Find the JSON object
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

          final jsonObject = jsonStr.substring(openBrace, closeBrace + 1);
          return json.decode(jsonObject);
        }
      }
    } catch (e) {
      logger.e('Error parsing JSON result: $e');
    }
    return null;
  }
}
