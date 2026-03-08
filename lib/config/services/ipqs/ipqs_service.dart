import 'package:command_center/config/services/ipqs/ipqs_api_client.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/repositories/config_repository.dart';
import 'package:get/get.dart';

// Re-export IpqsResult so existing imports still work
export 'package:command_center/config/services/ipqs/ipqs_api_client.dart'
    show IpqsResult;

/// Service for IPQualityScore API integration
class IpqsService extends GetxService {
  static const String _keyApiKey = 'ipqs_api_key';
  static const String _keyIsSetup = 'ipqs_is_setup';

  final _apiClient = IpqsApiClient();
  ConfigRepository? _configRepository;

  // Observable states
  final apiKey = Rxn<String>();
  final isConfigured = false.obs;
  final isLoading = false.obs;
  final lastError = Rxn<String>();

  Future<IpqsService> init() async {
    try {
      _configRepository = Get.find<DatabaseService>().configRepository;
      await loadConfig();
    } catch (e) {
      logger.e('Error initializing IpqsService: $e');
    }
    return this;
  }

  /// Load configuration from SQLite
  Future<void> loadConfig() async {
    try {
      if (_configRepository == null) return;

      apiKey.value = await _configRepository!.getValue(_keyApiKey);

      final setupValue = await _configRepository!.getValue(_keyIsSetup);
      isConfigured.value = setupValue == 'true' && apiKey.value != null;
    } catch (e) {
      logger.e('Error loading IPQS config: $e');
    }
  }

  /// Save API key
  Future<bool> saveApiKey(String key) async {
    try {
      if (_configRepository == null) return false;

      await _configRepository!.setValue(_keyApiKey, key);
      await _configRepository!.setValue(_keyIsSetup, 'true');

      apiKey.value = key;
      isConfigured.value = true;
      return true;
    } catch (e) {
      logger.e('Error saving IPQS API key: $e');
      return false;
    }
  }

  /// Clear API key (unlink)
  Future<bool> clearApiKey() async {
    try {
      if (_configRepository == null) return false;

      await _configRepository!.deleteValue(_keyApiKey);
      await _configRepository!.setValue(_keyIsSetup, 'false');

      apiKey.value = null;
      isConfigured.value = false;
      return true;
    } catch (e) {
      logger.e('Error clearing IPQS API key: $e');
      return false;
    }
  }

  /// Test API connection with current key
  Future<IpqsResult> testConnection(String key) async {
    try {
      // Use a test IP address (Google DNS)
      final result = await _apiClient.scoreIp(key, '8.8.8.8');
      return result;
    } catch (e) {
      return IpqsResult.error('Connection test failed: $e');
    }
  }

  /// Test connection and save key if successful
  Future<IpqsResult> testAndConnect(String key) async {
    isLoading.value = true;
    lastError.value = null;

    try {
      final result = await testConnection(key);

      if (result.success) {
        final saved = await saveApiKey(key);
        if (!saved) {
          return IpqsResult.error('Failed to save API key');
        }
      }

      return result;
    } catch (e) {
      lastError.value = e.toString();
      return IpqsResult.error(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// Score a single IP address
  Future<IpqsResult> scoreIp(String ipAddress) async {
    if (apiKey.value == null || apiKey.value!.isEmpty) {
      return IpqsResult.error('IPQS API key not configured');
    }

    isLoading.value = true;
    lastError.value = null;

    try {
      final result = await _apiClient.scoreIp(apiKey.value!, ipAddress);
      return result;
    } catch (e) {
      lastError.value = e.toString();
      return IpqsResult.error(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// Score multiple IP addresses with bounded concurrency
  Future<Map<String, IpqsResult>> scoreMultipleIps(
      List<String> ipAddresses) async {
    final results = <String, IpqsResult>{};
    const maxConcurrent = 3;

    // Process in batches of maxConcurrent
    for (var i = 0; i < ipAddresses.length; i += maxConcurrent) {
      final batch = ipAddresses.skip(i).take(maxConcurrent).toList();
      final batchResults = await Future.wait(
        batch.map((ip) => scoreIp(ip).then((r) => MapEntry(ip, r))),
      );
      for (final entry in batchResults) {
        results[entry.key] = entry.value;
      }
      // Small delay between batches to avoid rate limiting
      if (i + maxConcurrent < ipAddresses.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return results;
  }
}
