import 'package:get/get.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/webshare/webshare_api_client.dart';
import 'package:command_center/config/services/webshare/webshare_replacement_handler.dart';

// Re-export models so existing imports still work
export 'package:command_center/config/services/webshare/webshare_api_client.dart'
    show
        WebshareProxySlot,
        WebshareProxyConfig,
        WebsharePlanInfo,
        WebshareApiException;

/// Service for interacting with Webshare API.
/// Handles API key management, config sync, error handling, and orchestration.
/// API Documentation: https://proxy.webshare.io/docs/
class WebshareService extends GetxService {
  final _apiClient = WebshareApiClient();
  late final WebshareReplacementHandler _replacementHandler;

  var isConfigured = false.obs;
  var isLoading = false.obs;
  DateTime? lastSyncTime;
  var lastError = Rxn<String>();

  String? _apiKey;
  AppConfigService? _configService;

  Future<WebshareService> init() async {
    _replacementHandler = WebshareReplacementHandler(_apiClient);
    await _loadApiKey();
    return this;
  }

  Future<void> _loadApiKey() async {
    try {
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

  /// Save API key to SQLite via AppConfigService
  Future<Result<void>> saveApiKey(String apiKey) async {
    try {
      _configService ??= Get.find<AppConfigService>();
      final result = await _configService!.saveWebshareApiKey(apiKey);
      switch (result) {
        case Success():
          _apiKey = apiKey;
          isConfigured.value = true;
          return Result.success(null);
        case Failure(:final message):
          lastError.value = message;
          return Result.failure(message);
      }
    } catch (e) {
      logger.e('Error saving Webshare API key: $e');
      lastError.value = 'Failed to save API key: $e';
      return Result.failure('Failed to save API key: $e', e);
    }
  }

  /// Clear API key (unlink)
  Future<Result<void>> clearApiKey() async {
    try {
      _configService ??= Get.find<AppConfigService>();
      final result = await _configService!.clearWebshareApiKey();
      switch (result) {
        case Success():
          _apiKey = null;
          isConfigured.value = false;
          return Result.success(null);
        case Failure(:final message):
          lastError.value = message;
          return Result.failure(message);
      }
    } catch (e) {
      logger.e('Error clearing Webshare API key: $e');
      lastError.value = 'Failed to unlink: $e';
      return Result.failure('Failed to unlink: $e', e);
    }
  }

  /// Test API connection and return detailed error message
  Future<Result<void>> testAndConnect(String apiKey) async {
    if (apiKey.isEmpty) {
      return Result.failure('API key cannot be empty');
    }

    lastError.value = null;

    try {
      final statusCode = await _apiClient.getProfile(apiKey);

      if (statusCode == 200) {
        return Result.success(null);
      } else if (statusCode == 401) {
        return Result.failure(
            'Invalid API key. Please check your Webshare dashboard.');
      } else if (statusCode == 403) {
        return Result.failure(
            'Access denied. API key may have restricted permissions.');
      } else if (statusCode == 429) {
        return Result.failure(
            'Rate limited. Please wait a moment and try again.');
      } else {
        return Result.failure('Connection failed (HTTP $statusCode)');
      }
    } catch (e) {
      final errorMsg = e.toString().contains('ClientException')
          ? 'Network error: $e'
          : 'Connection error: $e';
      return Result.failure(errorMsg, e);
    }
  }

  /// Test API connection with current key (legacy method)
  Future<Result<void>> testConnection([String? tempApiKey]) async {
    return testAndConnect(tempApiKey ?? _apiKey ?? '');
  }

  /// Get all proxy slots from Webshare
  Future<List<WebshareProxySlot>> getProxyList() async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }

    isLoading.value = true;
    try {
      final proxies = await _apiClient.getProxyList(_apiKey!);
      lastSyncTime = DateTime.now();
      return proxies;
    } catch (e) {
      logger.e('Error fetching Webshare proxies: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Replace a proxy IP via the v3 Proxy Replacement API.
  Future<Result<void>> replaceProxyIp(
    String ipAddress, {
    String? countryCode,
  }) async {
    if (_apiKey == null) {
      return Result.failure('Webshare API key not configured');
    }

    return _replacementHandler.replaceProxyIp(
      _apiKey!,
      ipAddress,
      countryCode: countryCode,
    );
  }

  /// Legacy: Rotate/replace IP for a specific proxy using v2 API
  Future<WebshareProxySlot?> replaceProxy(String proxyId) async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }
    try {
      return await _apiClient.replaceProxy(_apiKey!, proxyId);
    } catch (e) {
      logger.e('Error replacing proxy: $e');
      return null;
    }
  }

  /// Get proxy configuration for a specific proxy
  Future<WebshareProxyConfig?> getProxyConfig(String proxyId) async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }
    try {
      return await _apiClient.getProxyConfig(_apiKey!, proxyId);
    } catch (e) {
      logger.e('Error fetching proxy config: $e');
      return null;
    }
  }

  /// Fetch the active subscription plan to get replacement quotas
  Future<WebsharePlanInfo?> getActivePlan() async {
    if (_apiKey == null) return null;
    try {
      final plans = await _apiClient.getSubscriptionPlans(_apiKey!);
      if (plans.isEmpty) return null;

      final activePlan = plans.firstWhere(
        (p) => p['status'] == 'active',
        orElse: () => plans.first,
      );
      return WebsharePlanInfo.fromJson(activePlan);
    } catch (e) {
      logger.e('Error fetching subscription plan: $e');
      return null;
    }
  }
}
