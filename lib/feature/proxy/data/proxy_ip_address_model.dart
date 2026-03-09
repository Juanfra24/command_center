import 'package:equatable/equatable.dart';

/// IP Quality Score levels for quick reference
enum IpScoreLevel {
  excellent, // 90-100
  good, // 70-89
  fair, // 50-69
  poor, // 30-49
  bad, // 0-29
  unknown,
}

/// Represents an IP address that was/is assigned to a proxy slot
/// This stores historical and current IP information
class ProxyIpAddress extends Equatable {
  final String id;
  final String ipAddress;
  final String hostname;
  final String slotId; // Reference to the parent ProxySlot
  final bool isActive; // Is this the current active IP for the slot?

  // Geographic info
  final String countryCode;
  final String cityName;
  final String ipTimezone;
  final bool highCountryConfidence;

  // ASN info
  final String asnName;
  final int asnNumber;

  // Score information - crucial for decision making
  final double ipScore; // 0-100 score
  final IpScoreLevel scoreLevel;
  final bool isVpn;
  final bool isProxy;
  final bool isDatacenter;
  final bool isTor;
  final double fraudScore; // 0-100 fraud risk
  final int abuseConfidence; // 0-100 abuse probability

  // Timestamps
  final DateTime assignedAt;
  final DateTime? removedAt;
  final DateTime lastVerification;
  final DateTime? lastScoreCheck;

  // Usage statistics
  final int totalDaysUsed;
  final int timesAssigned; // How many times this IP was assigned to any slot

  const ProxyIpAddress({
    required this.id,
    required this.ipAddress,
    required this.hostname,
    required this.slotId,
    required this.isActive,
    required this.countryCode,
    required this.cityName,
    required this.ipTimezone,
    required this.highCountryConfidence,
    required this.asnName,
    required this.asnNumber,
    required this.ipScore,
    required this.scoreLevel,
    required this.isVpn,
    required this.isProxy,
    required this.isDatacenter,
    required this.isTor,
    required this.fraudScore,
    required this.abuseConfidence,
    required this.assignedAt,
    this.removedAt,
    required this.lastVerification,
    this.lastScoreCheck,
    required this.totalDaysUsed,
    required this.timesAssigned,
  });

  factory ProxyIpAddress.fromJson(Map<String, dynamic> json, {String? docId}) {
    if (json.isEmpty) return ProxyIpAddress.empty();

    final score = (json['ip_score'] ?? 0).toDouble();

    return ProxyIpAddress(
      id: docId ?? json['id'] ?? '',
      ipAddress: json['ip_address'] ?? json['proxy_address'] ?? '',
      hostname: json['hostname'] ?? '',
      slotId: json['slot_id'] ?? '',
      isActive: json['is_active'] ?? json['is_current'] ?? false,
      countryCode: json['country_code'] ?? 'XX',
      cityName: json['city_name'] ?? '',
      ipTimezone: json['ip_timezone'] ?? 'UTC',
      highCountryConfidence: json['high_country_confidence'] ?? false,
      asnName: json['asn_name'] ?? '',
      asnNumber: json['asn_number'] ?? 0,
      ipScore: score,
      scoreLevel: _getScoreLevel(score),
      isVpn: json['is_vpn'] ?? false,
      isProxy: json['is_proxy'] ?? true,
      isDatacenter: json['is_datacenter'] ?? false,
      isTor: json['is_tor'] ?? false,
      fraudScore: (json['fraud_score'] ?? 0).toDouble(),
      abuseConfidence: json['abuse_confidence'] ?? 0,
      assignedAt: _parseDateTime(json['assigned_at']),
      removedAt: json['removed_at'] != null
          ? _parseDateTime(json['removed_at'])
          : null,
      lastVerification: _parseDateTime(json['last_verification']),
      lastScoreCheck: json['last_score_check'] != null
          ? _parseDateTime(json['last_score_check'])
          : null,
      totalDaysUsed: json['total_days_used'] ?? 0,
      timesAssigned: json['times_assigned'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ip_address': ipAddress,
        'hostname': hostname,
        'slot_id': slotId,
        'is_active': isActive,
        'country_code': countryCode,
        'city_name': cityName,
        'ip_timezone': ipTimezone,
        'high_country_confidence': highCountryConfidence,
        'asn_name': asnName,
        'asn_number': asnNumber,
        'ip_score': ipScore,
        'score_level': scoreLevel.name,
        'is_vpn': isVpn,
        'is_proxy': isProxy,
        'is_datacenter': isDatacenter,
        'is_tor': isTor,
        'fraud_score': fraudScore,
        'abuse_confidence': abuseConfidence,
        'assigned_at': assignedAt.toIso8601String(),
        'removed_at': removedAt?.toIso8601String(),
        'last_verification': lastVerification.toIso8601String(),
        'last_score_check': lastScoreCheck?.toIso8601String(),
        'total_days_used': totalDaysUsed,
        'times_assigned': timesAssigned,
      };

  factory ProxyIpAddress.empty() {
    return ProxyIpAddress(
      id: '',
      ipAddress: '0.0.0.0',
      hostname: '',
      slotId: '',
      isActive: false,
      countryCode: 'XX',
      cityName: '',
      ipTimezone: 'UTC',
      highCountryConfidence: false,
      asnName: '',
      asnNumber: 0,
      ipScore: 0,
      scoreLevel: IpScoreLevel.unknown,
      isVpn: false,
      isProxy: false,
      isDatacenter: false,
      isTor: false,
      fraudScore: 0,
      abuseConfidence: 0,
      assignedAt: DateTime.now(),
      removedAt: null,
      lastVerification: DateTime.now(),
      lastScoreCheck: null,
      totalDaysUsed: 0,
      timesAssigned: 0,
    );
  }

  ProxyIpAddress copyWith({
    String? id,
    String? ipAddress,
    String? hostname,
    String? slotId,
    bool? isActive,
    String? countryCode,
    String? cityName,
    String? ipTimezone,
    bool? highCountryConfidence,
    String? asnName,
    int? asnNumber,
    double? ipScore,
    IpScoreLevel? scoreLevel,
    bool? isVpn,
    bool? isProxy,
    bool? isDatacenter,
    bool? isTor,
    double? fraudScore,
    int? abuseConfidence,
    DateTime? assignedAt,
    DateTime? removedAt,
    DateTime? lastVerification,
    DateTime? lastScoreCheck,
    int? totalDaysUsed,
    int? timesAssigned,
  }) {
    return ProxyIpAddress(
      id: id ?? this.id,
      ipAddress: ipAddress ?? this.ipAddress,
      hostname: hostname ?? this.hostname,
      slotId: slotId ?? this.slotId,
      isActive: isActive ?? this.isActive,
      countryCode: countryCode ?? this.countryCode,
      cityName: cityName ?? this.cityName,
      ipTimezone: ipTimezone ?? this.ipTimezone,
      highCountryConfidence:
          highCountryConfidence ?? this.highCountryConfidence,
      asnName: asnName ?? this.asnName,
      asnNumber: asnNumber ?? this.asnNumber,
      ipScore: ipScore ?? this.ipScore,
      scoreLevel: scoreLevel ?? this.scoreLevel,
      isVpn: isVpn ?? this.isVpn,
      isProxy: isProxy ?? this.isProxy,
      isDatacenter: isDatacenter ?? this.isDatacenter,
      isTor: isTor ?? this.isTor,
      fraudScore: fraudScore ?? this.fraudScore,
      abuseConfidence: abuseConfidence ?? this.abuseConfidence,
      assignedAt: assignedAt ?? this.assignedAt,
      removedAt: removedAt ?? this.removedAt,
      lastVerification: lastVerification ?? this.lastVerification,
      lastScoreCheck: lastScoreCheck ?? this.lastScoreCheck,
      totalDaysUsed: totalDaysUsed ?? this.totalDaysUsed,
      timesAssigned: timesAssigned ?? this.timesAssigned,
    );
  }

  /// Check if this IP needs a score refresh (older than specified days)
  bool needsScoreRefresh({int maxAgeDays = 7}) {
    if (lastScoreCheck == null) return true;
    return DateTime.now().difference(lastScoreCheck!).inDays > maxAgeDays;
  }

  /// Get a color representation for the score level
  String get scoreColorHex {
    switch (scoreLevel) {
      case IpScoreLevel.excellent:
        return '#00C853'; // Green
      case IpScoreLevel.good:
        return '#64DD17'; // Light Green
      case IpScoreLevel.fair:
        return '#FFD600'; // Yellow
      case IpScoreLevel.poor:
        return '#FF9100'; // Orange
      case IpScoreLevel.bad:
        return '#FF1744'; // Red
      case IpScoreLevel.unknown:
        return '#9E9E9E'; // Grey
    }
  }

  static IpScoreLevel _getScoreLevel(double score) {
    if (score >= 90) return IpScoreLevel.excellent;
    if (score >= 70) return IpScoreLevel.good;
    if (score >= 50) return IpScoreLevel.fair;
    if (score >= 30) return IpScoreLevel.poor;
    if (score > 0) return IpScoreLevel.bad;
    return IpScoreLevel.unknown;
  }

  @override
  List<Object?> get props => [
        id,
        ipAddress,
        hostname,
        slotId,
        isActive,
        countryCode,
        cityName,
        ipTimezone,
        highCountryConfidence,
        asnName,
        asnNumber,
        ipScore,
        scoreLevel,
        isVpn,
        isProxy,
        isDatacenter,
        isTor,
        fraudScore,
        abuseConfidence,
        assignedAt,
        removedAt,
        lastVerification,
        lastScoreCheck,
        totalDaysUsed,
        timesAssigned,
      ];
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
