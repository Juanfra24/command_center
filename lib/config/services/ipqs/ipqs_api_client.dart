import 'dart:convert';
import 'package:command_center/core/helper/logger.dart';
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

/// HTTP transport layer for IPQualityScore API.
class IpqsApiClient {
  static const String _baseUrl = 'https://ipqualityscore.com/api/json/ip';

  /// Score a single IP address
  Future<IpqsResult> scoreIp(String apiKey, String ipAddress) async {
    try {
      final uri = Uri.parse('$_baseUrl/$apiKey/$ipAddress?strictness=1');

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
