import 'dart:convert';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/config/services/webshare/webshare_api_client.dart';

/// Handles the proxy IP replacement flow: create replacement + poll status.
class WebshareReplacementHandler {
  final WebshareApiClient _apiClient;

  WebshareReplacementHandler(this._apiClient);

  /// Replace a proxy IP via the v3 Proxy Replacement API.
  /// Orchestrates: create replacement -> poll until complete/failed.
  Future<Result<void>> replaceProxyIp(
    String apiKey,
    String ipAddress, {
    String? countryCode,
  }) async {
    try {
      logger.i('Creating proxy replacement for IP: $ipAddress');

      final data = await _apiClient.createProxyReplacement(
        apiKey,
        ipAddress,
        countryCode: countryCode,
      );

      final replacementId = data['id'];
      final state = data['state'] as String?;
      logger.i('Replacement created with ID: $replacementId, state: $state');

      return await _pollReplacementStatus(apiKey, replacementId);
    } on WebshareApiException catch (e) {
      final errorMsg = _parseErrorMessage(e.responseBody) ??
          'Failed to create replacement: HTTP ${e.statusCode}';
      logger.e('Failed to create replacement: $errorMsg');
      return Result.failure(errorMsg, e);
    } catch (e) {
      logger.e('Error replacing proxy: $e');
      return Result.failure('Error replacing proxy: $e', e);
    }
  }

  /// Poll the replacement status until completed or failed.
  Future<Result<void>> _pollReplacementStatus(
    String apiKey,
    dynamic replacementId,
  ) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      try {
        final data =
            await _apiClient.getReplacementStatus(apiKey, replacementId);
        final state = data['state'] as String?;

        logger.i('Replacement $replacementId state: $state');

        if (state == 'completed') {
          logger.i('Replacement completed: '
              '${data['proxies_removed']} removed, '
              '${data['proxies_added']} added');
          return Result.success(null);
        } else if (state == 'failed') {
          final error = data['error'] ?? 'Unknown error';
          final errorCode = data['error_code'] ?? '';
          logger.e('Replacement failed: $error ($errorCode)');
          return Result.failure('Replacement failed: $error');
        }
        // States: validating, validated, processing — keep polling
      } catch (e) {
        logger.w('Error polling replacement: $e');
      }
    }

    return Result.failure(
        'Replacement timed out after ${maxAttempts * pollInterval.inSeconds}s');
  }

  /// Parse error message from API response body.
  String? _parseErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        return (decoded['detail'] ?? decoded['error'] ?? decoded.toString())
            .toString();
      }
    } catch (_) {}
    return null;
  }
}
