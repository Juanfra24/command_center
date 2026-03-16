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
  final int slotNumber;

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

  String get connectionString => '$proxyAddress:$port';
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

/// Subscription plan info with replacement quotas
class WebsharePlanInfo {
  final int id;
  final String status;
  final int proxyCount;
  final int proxyReplacementsTotal;
  final int proxyReplacementsUsed;
  final int proxyReplacementsAvailable;
  final int onDemandRefreshesTotal;
  final int onDemandRefreshesUsed;
  final int onDemandRefreshesAvailable;

  WebsharePlanInfo({
    required this.id,
    required this.status,
    required this.proxyCount,
    required this.proxyReplacementsTotal,
    required this.proxyReplacementsUsed,
    required this.proxyReplacementsAvailable,
    required this.onDemandRefreshesTotal,
    required this.onDemandRefreshesUsed,
    required this.onDemandRefreshesAvailable,
  });

  factory WebsharePlanInfo.fromJson(Map<String, dynamic> json) {
    return WebsharePlanInfo(
      id: json['id'] ?? 0,
      status: json['status'] ?? '',
      proxyCount: json['proxy_count'] ?? 0,
      proxyReplacementsTotal: json['proxy_replacements_total'] ?? 0,
      proxyReplacementsUsed: json['proxy_replacements_used'] ?? 0,
      proxyReplacementsAvailable: json['proxy_replacements_available'] ?? 0,
      onDemandRefreshesTotal: json['on_demand_refreshes_total'] ?? 0,
      onDemandRefreshesUsed: json['on_demand_refreshes_used'] ?? 0,
      onDemandRefreshesAvailable: json['on_demand_refreshes_available'] ?? 0,
    );
  }
}

/// Exception thrown by WebshareApiClient on non-success HTTP responses.
class WebshareApiException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  WebshareApiException(this.message, this.statusCode, this.responseBody);

  @override
  String toString() => 'WebshareApiException: $message (HTTP $statusCode)';
}
