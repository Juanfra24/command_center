import 'dart:convert';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/repositories/config_repository.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// Response model for IPQualityScore API
class IpqsResult {
  final bool success;
  final String? message;
  final double fraudScore;
  final bool isProxy;
  final bool isVpn;
  final bool isTor;
  final bool isDatacenter;
  final bool isCrawler;
  final bool recentAbuse;
  final String? connectionType;
  final String? isp;
  final String? organization;
  final String? countryCode;
  final String? city;
  final String? region;
  final String? error;

  IpqsResult({
    this.success = false,
    this.message,
    this.fraudScore = 0,
    this.isProxy = false,
    this.isVpn = false,
    this.isTor = false,
    this.isDatacenter = false,
    this.isCrawler = false,
    this.recentAbuse = false,
    this.connectionType,
    this.isp,
    this.organization,
    this.countryCode,
    this.city,
    this.region,
    this.error,
  });

  factory IpqsResult.fromJson(Map<String, dynamic> json) {
    return IpqsResult(
      success: json['success'] == true,
      message: json['message'] as String?,
      fraudScore: (json['fraud_score'] as num?)?.toDouble() ?? 0,
      isProxy: json['proxy'] == true,
      isVpn: json['vpn'] == true,
      isTor: json['tor'] == true,
      isDatacenter: json['connection_type']?.toString().toLowerCase() ==
              'datacenter' ||
          json['connection_type']?.toString().toLowerCase() == 'data center',
      isCrawler: json['is_crawler'] == true,
      recentAbuse: json['recent_abuse'] == true,
      connectionType: json['connection_type'] as String?,
      isp: json['ISP'] as String?,
      organization: json['organization'] as String?,
      countryCode: json['country_code'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
    );
  }

  factory IpqsResult.error(String errorMessage) {
    return IpqsResult(
      success: false,
      error: errorMessage,
    );
  }

  /// Normalized score from 0-100 where lower is better (safer)
  /// IPQualityScore returns 0-100 where higher is more risky
  /// We invert it so 100 = safest, 0 = riskiest
  double get normalizedScore => 100 - fraudScore;

  /// Get a quality rating based on fraud score
  String get qualityRating {
    if (fraudScore < 25) return 'Excellent';
    if (fraudScore < 50) return 'Good';
    if (fraudScore < 75) return 'Fair';
    if (fraudScore < 85) return 'Poor';
    return 'Very Poor';
  }
}

/// Service for IPQualityScore API integration
class IpqsService extends GetxService {
  static const String _keyApiKey = 'ipqs_api_key';
  static const String _keyIsSetup = 'ipqs_is_setup';
  static const String _baseUrl = 'https://ipqualityscore.com/api/json/ip';

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
      final result = await _makeRequest(key, '8.8.8.8');
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
      final result = await _makeRequest(apiKey.value!, ipAddress);
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

  /// Make API request
  Future<IpqsResult> _makeRequest(String key, String ipAddress) async {
    try {
      final uri = Uri.parse('$_baseUrl/$key/$ipAddress?strictness=1');

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return IpqsResult.fromJson(json);
      } else {
        return IpqsResult.error('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('IPQS API request failed: $e');
      return IpqsResult.error('Request failed: $e');
    }
  }
}
