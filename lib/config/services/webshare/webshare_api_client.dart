import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:command_center/config/services/webshare/webshare_models.dart';

export 'package:command_center/config/services/webshare/webshare_models.dart';

/// HTTP transport layer for Webshare API.
/// Pure HTTP: makes requests, parses JSON, returns models or throws.
/// All methods receive the API key as a parameter.
class WebshareApiClient {
  static const String _baseUrlV2 = 'https://proxy.webshare.io/api/v2';
  static const String _baseUrlV3 = 'https://proxy.webshare.io/api/v3';

  Map<String, String> _headers(String apiKey) => {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'application/json',
      };

  /// GET /profile/ — returns status code (used by service to test connection).
  Future<int> getProfile(String apiKey) async {
    final response = await http.get(
      Uri.parse('$_baseUrlV2/profile/'),
      headers: _headers(apiKey),
    );
    return response.statusCode;
  }

  /// GET /proxy/list/ — fetches all proxy slots with pagination.
  Future<List<WebshareProxySlot>> getProxyList(String apiKey) async {
    final allProxies = <WebshareProxySlot>[];
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      final response = await http.get(
        Uri.parse(
            '$_baseUrlV2/proxy/list/?mode=backbone&page=$page&page_size=100'),
        headers: _headers(apiKey),
      );

      if (response.statusCode != 200) {
        throw WebshareApiException(
            'Failed to fetch proxies', response.statusCode, response.body);
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List<dynamic>;

      for (var i = 0; i < results.length; i++) {
        allProxies.add(WebshareProxySlot.fromJson(results[i],
            index: allProxies.length + 1));
      }

      hasMore = data['next'] != null;
      page++;
    }

    return allProxies;
  }

  /// POST /v3/proxy/replace/ — creates a proxy replacement request.
  /// Returns the parsed response body on success, throws on failure.
  Future<Map<String, dynamic>> createProxyReplacement(
    String apiKey,
    String ipAddress, {
    String? countryCode,
  }) async {
    final toReplace = {
      'type': 'ip_address',
      'ip_addresses': [ipAddress],
    };

    final List<Map<String, dynamic>> replaceWith;
    if (countryCode != null && countryCode.isNotEmpty) {
      replaceWith = [
        {'type': 'country', 'country_code': countryCode}
      ];
    } else {
      replaceWith = [
        {'type': 'any', 'count': 1}
      ];
    }

    final body = {
      'to_replace': toReplace,
      'replace_with': replaceWith,
      'dry_run': false,
    };

    final response = await http.post(
      Uri.parse('$_baseUrlV3/proxy/replace/'),
      headers: _headers(apiKey),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw WebshareApiException(
        'Failed to create replacement', response.statusCode, response.body);
  }

  /// GET /v3/proxy/replace/:id/ — polls replacement status.
  Future<Map<String, dynamic>> getReplacementStatus(
      String apiKey, dynamic replacementId) async {
    final response = await http.get(
      Uri.parse('$_baseUrlV3/proxy/replace/$replacementId/'),
      headers: _headers(apiKey),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw WebshareApiException(
        'Failed to poll replacement', response.statusCode, response.body);
  }

  /// POST /proxy/list/:id/replace/ — legacy v2 proxy replacement.
  Future<WebshareProxySlot> replaceProxy(String apiKey, String proxyId) async {
    final response = await http.post(
      Uri.parse('$_baseUrlV2/proxy/list/$proxyId/replace/'),
      headers: _headers(apiKey),
    );

    if (response.statusCode == 200) {
      return WebshareProxySlot.fromJson(jsonDecode(response.body));
    }

    throw WebshareApiException(
        'Failed to replace proxy', response.statusCode, response.body);
  }

  /// GET /proxy/list/:id/ — fetch proxy configuration.
  Future<WebshareProxyConfig> getProxyConfig(
      String apiKey, String proxyId) async {
    final response = await http.get(
      Uri.parse('$_baseUrlV2/proxy/list/$proxyId/'),
      headers: _headers(apiKey),
    );

    if (response.statusCode == 200) {
      return WebshareProxyConfig.fromJson(jsonDecode(response.body));
    }

    throw WebshareApiException(
        'Failed to fetch proxy config', response.statusCode, response.body);
  }

  /// GET /subscription/plan/ — fetch subscription plans.
  Future<List<Map<String, dynamic>>> getSubscriptionPlans(String apiKey) async {
    final response = await http.get(
      Uri.parse('$_baseUrlV2/subscription/plan/'),
      headers: _headers(apiKey),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List<dynamic>?;
      return results?.cast<Map<String, dynamic>>() ?? [];
    }

    throw WebshareApiException(
        'Failed to fetch plans', response.statusCode, response.body);
  }
}
