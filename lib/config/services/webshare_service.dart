import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/config/services/app_config_service.dart';

/// Service for interacting with Webshare API
/// API Documentation: https://proxy.webshare.io/docs/
class WebshareService extends GetxService {
  static const String _baseUrl = 'https://proxy.webshare.io/api/v2';

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

  Map<String, String> get _headers => {
        'Authorization': 'Token $_apiKey',
        'Content-Type': 'application/json',
      };

  Map<String, String> _headersWithKey(String apiKey) => {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'application/json',
      };

  /// Test API connection and return detailed error message
  Future<({bool success, String? error})> testAndConnect(String apiKey) async {
    lastError.value = null;

    if (apiKey.isEmpty) {
      return (success: false, error: 'API key cannot be empty');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile/'),
        headers: _headersWithKey(apiKey),
      );

      if (response.statusCode == 200) {
        return (success: true, error: null);
      } else if (response.statusCode == 401) {
        return (
          success: false,
          error: 'Invalid API key. Please check your Webshare dashboard.'
        );
      } else if (response.statusCode == 403) {
        return (
          success: false,
          error: 'Access denied. API key may have restricted permissions.'
        );
      } else if (response.statusCode == 429) {
        return (
          success: false,
          error: 'Rate limited. Please wait a moment and try again.'
        );
      } else {
        return (
          success: false,
          error: 'Connection failed (HTTP ${response.statusCode})'
        );
      }
    } on http.ClientException catch (e) {
      return (success: false, error: 'Network error: ${e.message}');
    } catch (e) {
      return (success: false, error: 'Connection error: $e');
    }
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
      final allProxies = <WebshareProxySlot>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await http.get(
          Uri.parse(
              '$_baseUrl/proxy/list/?mode=direct&page=$page&page_size=100'),
          headers: _headers,
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch proxies: ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;

        for (var i = 0; i < results.length; i++) {
          allProxies.add(WebshareProxySlot.fromJson(results[i],
              index: allProxies.length + 1));
        }

        // Check if there's a next page
        hasMore = data['next'] != null;
        page++;
      }

      lastSyncTime.value = DateTime.now();
      return allProxies;
    } catch (e) {
      logger.e('Error fetching Webshare proxies: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Rotate/replace IP for a specific proxy
  Future<WebshareProxySlot?> replaceProxy(String proxyId) async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/proxy/list/$proxyId/replace/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WebshareProxySlot.fromJson(data);
      } else {
        logger.e(
            'Failed to replace proxy: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      logger.e('Error replacing proxy: $e');
      rethrow;
    }
  }

  /// Get proxy configuration for a specific proxy
  Future<WebshareProxyConfig?> getProxyConfig(String proxyId) async {
    if (_apiKey == null) {
      throw Exception('Webshare API key not configured');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/proxy/list/$proxyId/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WebshareProxyConfig.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      logger.e('Error fetching proxy config: $e');
      return null;
    }
  }
}

/// Represents a proxy slot from Webshare API
class WebshareProxySlot {
  final String id;
  final String username;
  final String password;
  final String proxyAddress;
  final int port;
  final bool valid;
  final String countryCode;
  final String cityName;
  final String? asnName;
  final int? asnNumber;
  final DateTime createdAt;
  final DateTime? lastVerification;
  final int slotNumber; // Local tracking number

  WebshareProxySlot({
    required this.id,
    required this.username,
    required this.password,
    required this.proxyAddress,
    required this.port,
    required this.valid,
    required this.countryCode,
    required this.cityName,
    this.asnName,
    this.asnNumber,
    required this.createdAt,
    this.lastVerification,
    this.slotNumber = 0,
  });

  factory WebshareProxySlot.fromJson(Map<String, dynamic> json,
      {int index = 0}) {
    return WebshareProxySlot(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      proxyAddress: json['proxy_address'] ?? '',
      port: json['port'] ?? 0,
      valid: json['valid'] ?? false,
      countryCode: json['country_code'] ?? 'XX',
      cityName: json['city_name'] ?? '',
      asnName: json['asn_name'],
      asnNumber: json['asn_number'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      lastVerification: json['last_verification'] != null
          ? DateTime.tryParse(json['last_verification'])
          : null,
      slotNumber: index,
    );
  }

  /// Full proxy connection string
  String get connectionString => '$proxyAddress:$port';

  /// Full proxy URL with auth
  String get proxyUrl => 'http://$username:$password@$proxyAddress:$port';
}

/// Proxy configuration details
class WebshareProxyConfig {
  final String id;
  final int proxyListDownloadTokenDefaultTimeoutSeconds;
  final String proxyListDownloadToken;

  WebshareProxyConfig({
    required this.id,
    required this.proxyListDownloadTokenDefaultTimeoutSeconds,
    required this.proxyListDownloadToken,
  });

  factory WebshareProxyConfig.fromJson(Map<String, dynamic> json) {
    return WebshareProxyConfig(
      id: json['id'] ?? '',
      proxyListDownloadTokenDefaultTimeoutSeconds:
          json['proxy_list_download_token_default_timeout_seconds'] ?? 0,
      proxyListDownloadToken: json['proxy_list_download_token'] ?? '',
    );
  }
}
