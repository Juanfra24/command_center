import 'package:get/get.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/webshare/webshare_api_client.dart';

// Re-export models so existing imports still work
export 'package:command_center/config/services/webshare/webshare_api_client.dart'
    show WebshareProxySlot, WebshareProxyConfig, WebsharePlanInfo;

/// Service for interacting with Webshare API
/// API Documentation: https://proxy.webshare.io/docs/
class WebshareService extends GetxService {
  final _apiClient = WebshareApiClient();

  var isConfigured = false.obs;
  var isLoading = false.obs;
  var isSyncing = false.obs;
  var lastSyncTime = Rxn<DateTime>();
  var lastError = Rxn<String>();

  String? _apiKey;
  AppConfigService? _configService;

  Future<WebshareService> init() async {
    await _loadApiKey();
    return this;
  }

  Future<void> _loadApiKey() async {
    try {
      // Try to get from AppConfigService first (Firestore)
      try {
        _configService = Get.find<AppConfigService>();
        if (_configService!.webshareApiKey.value != null) {
          _apiKey = _configService!.webshareApiKey.value;
          isConfigured.value = true;
          return;
        }
      } catch (_) {
        // AppConfigService not available yet
      }

      isConfigured.value = _apiKey != null && _apiKey!.isNotEmpty;
    } catch (e) {
      logger.e('Error loading Webshare API key: $e');
    }
  }

  /// Reload configuration from AppConfigService
  Future<void> reloadConfig() async {
    try {
      _configService ??= Get.find<AppConfigService>();
      _apiKey = _configService!.webshareApiKey.value;
      isConfigured.value = _apiKey != null && _apiKey!.isNotEmpty;
    } catch (e) {
      logger.e('Error reloading Webshare config: $e');
    }
  }

  /// Save API key to Firestore via AppConfigService
  Future<bool> saveApiKey(String apiKey) async {
    try {
      _configService ??= Get.find<AppConfigService>();
      final success = await _configService!.saveWebshareApiKey(apiKey);
      if (success) {
        _apiKey = apiKey;
        isConfigured.value = true;
      }
      return success;
    } catch (e) {
      logger.e('Error saving Webshare API key: $e');
      lastError.value = 'Failed to save API key: $e';
      return false;
    }
  }

  /// Clear API key (unlink)
  Future<bool> clearApiKey() async {
    try {
      _configService ??= Get.find<AppConfigService>();
      final success = await _configService!.clearWebshareApiKey();
      if (success) {
        _apiKey = null;
        isConfigured.value = false;
      }
      return success;
    } catch (e) {
      logger.e('Error clearing Webshare API key: $e');
      lastError.value = 'Failed to unlink: $e';
      return false;
    }
  }

  /// Test API connection and return detailed error message
  Future<({bool success, String? error})> testAndConnect(String apiKey) async {
    lastError.value = null;
    return _apiClient.testAndConnect(apiKey);
  }

  /// Test API connection with current key (legacy method)
  Future<bool> testConnection([String? tempApiKey]) async {
    final result = await testAndConnect(tempApiKey ?? _apiKey ?? '');
    return result.success;
  }

  /// Get all proxy slots from Webshare
  Future<List<WebshareProxySlot>> getProxyList() async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }

    isLoading.value = true;
    try {
      final proxies = await _apiClient.getProxyList(_apiKey!);
      lastSyncTime.value = DateTime.now();
      return proxies;
    } catch (e) {
      logger.e('Error fetching Webshare proxies: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Replace a proxy IP via the v3 Proxy Replacement API.
  Future<({bool success, String? error})> replaceProxyIp(
    String ipAddress, {
    String? countryCode,
  }) async {
    if (_apiKey == null) {
      return (success: false, error: 'Webshare API key not configured');
    }
    return _apiClient.replaceProxyIp(_apiKey!, ipAddress,
        countryCode: countryCode);
  }

  /// Legacy: Rotate/replace IP for a specific proxy using v2 API
  Future<WebshareProxySlot?> replaceProxy(String proxyId) async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }
    return _apiClient.replaceProxy(_apiKey!, proxyId);
  }

  /// Get proxy configuration for a specific proxy
  Future<WebshareProxyConfig?> getProxyConfig(String proxyId) async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }
    return _apiClient.getProxyConfig(_apiKey!, proxyId);
  }

  /// Fetch the active subscription plan to get replacement quotas
  Future<WebsharePlanInfo?> getActivePlan() async {
    if (_apiKey == null) return null;
    return _apiClient.getActivePlan(_apiKey!);
  }
}
