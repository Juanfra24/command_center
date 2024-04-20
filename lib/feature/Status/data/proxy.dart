import 'package:equatable/equatable.dart';

class Proxy extends Equatable {
  final String asnName;
  final int asnNumber;
  final String cityName;
  final String countryCode;
  final DateTime createdAt;
  final bool highCountryConfidence;
  final String hostname;
  final String id;
  final String ipTimezone;
  final DateTime lastVerification;
  final List<String> linkedChars;
  final String password;
  final int port;
  final String proxyAddress;
  final String username;
  final bool valid;

  const Proxy({
    required this.asnName,
    required this.asnNumber,
    required this.cityName,
    required this.countryCode,
    required this.createdAt,
    required this.highCountryConfidence,
    required this.hostname,
    required this.id,
    required this.ipTimezone,
    required this.lastVerification,
    required this.linkedChars,
    required this.password,
    required this.port,
    required this.proxyAddress,
    required this.username,
    required this.valid,
  });

  factory Proxy.fromJson(Map<String, dynamic> json) {
    return Proxy(
      asnName: json['asn_name'],
      asnNumber: json['asn_number'],
      cityName: json['city_name'],
      countryCode: json['country_code'],
      createdAt: DateTime.parse(json['created_at']),
      highCountryConfidence: json['high_country_confidence'],
      hostname: json['hostname'],
      id: json['id'],
      ipTimezone: json['ip_timezone'],
      lastVerification: DateTime.parse(json['last_verification']),
      linkedChars: List<String>.from(json['linked_chars']),
      password: json['password'],
      port: json['port'],
      proxyAddress: json['proxy_address'],
      username: json['username'],
      valid: json['valid'],
    );
  }

  @override
  List<Object?> get props => [
        asnName,
        asnNumber,
        cityName,
        countryCode,
        createdAt,
        highCountryConfidence,
        hostname,
        id,
        ipTimezone,
        lastVerification,
        linkedChars,
        password,
        port,
        proxyAddress,
        username,
        valid,
      ];
}
