import 'dart:convert';
import 'package:command_center/core/helper/logger.dart';
import 'package:http/http.dart' as http;

/// Response model for ProxyCheck.io API (mapped from ProxyCheck v2 fields).
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

  /// Parses the IP-level sub-object from a ProxyCheck.io v2 response.
  /// Call this on `json[ipAddress]`, not the top-level response.
  factory IpqsResult.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? '').toLowerCase();
    final proxyStr = (json['proxy'] as String? ?? '').toLowerCase();
    return IpqsResult(
      success: true,
      fraudScore: (json['risk'] as num?)?.toDouble() ?? 0,
      isProxy: proxyStr == 'yes',
      isVpn: typeStr == 'vpn',
      isTor: typeStr == 'tor',
      isDatacenter: typeStr == 'data center' || typeStr == 'hosting',
      isCrawler: false,
      recentAbuse: false,
      connectionType: json['type'] as String?,
      isp: json['provider'] as String?,
      organization: json['organisation'] as String?,
      countryCode: json['isocode'] as String?,
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

  /// Normalized score from 0-100 where lower is better (safer).
  /// ProxyCheck returns 0-100 where higher is more risky — we invert it.
  double get normalizedScore => 100 - fraudScore;

  /// Quality rating based on risk score.
  String get qualityRating {
    if (fraudScore < 25) return 'Excellent';
    if (fraudScore < 50) return 'Good';
    if (fraudScore < 75) return 'Fair';
    if (fraudScore < 85) return 'Poor';
    return 'Very Poor';
  }
}

/// HTTP transport layer for ProxyCheck.io v2 API.
class IpqsApiClient {
  static const String _baseUrl = 'https://proxycheck.io/v2';

  /// Score a single IP address using the ProxyCheck.io v2 API.
  ///
  /// `GET /v2/{ip}?key={apiKey}&vpn=1&risk=1&asn=1`
  /// The API key is a query parameter. Exception messages are sanitized below
  /// to prevent the key from leaking into logs.
  Future<IpqsResult> scoreIp(String apiKey, String ipAddress) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/$ipAddress?key=$apiKey&vpn=1&risk=1&asn=1',
      );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] as String? ?? '';
        if (status == 'ok' || status == 'warning') {
          final ipData = json[ipAddress] as Map<String, dynamic>?;
          if (ipData != null) return IpqsResult.fromJson(ipData);
          return IpqsResult.error('No data returned for IP');
        }
        final msg = json['message'] as String? ?? 'API status: $status';
        return IpqsResult.error(msg);
      } else {
        return IpqsResult.error('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      // Scrub API key from exception messages — key appears in the query string.
      final sanitized = e.toString().replaceAll(apiKey, '***');
      logger.e('ProxyCheck API request failed: $sanitized');
      return IpqsResult.error(
          'ProxyCheck request failed. Check logs for details.');
    }
  }
}
