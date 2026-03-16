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

/// Domain entity for a proxy IP address
/// This is a pure Dart class with no database dependencies
class ProxyIpAddressEntity extends Equatable {
  final int? id;
  final String ipAddress;
  final String hostname;
  final int slotId;
  final bool isActive;

  // Geographic info
  final String countryCode;
  final String cityName;
  final String ipTimezone;
  final bool highCountryConfidence;

  // ASN info
  final String asnName;
  final int asnNumber;

  // Score information
  final double ipScore;
  final IpScoreLevel scoreLevel;
  final bool isVpn;
  final bool isProxy;
  final bool isDatacenter;
  final bool isTor;
  final bool? isCrawler;
  final String? connectionType;
  final String? isp;
  final String? organization;
  final String? region;
  final bool? recentAbuse;
  final double fraudScore;

  // Timestamps
  final DateTime assignedAt;
  final DateTime? removedAt;
  final DateTime lastVerification;
  final DateTime? lastScoreCheck;

  // Usage statistics
  final int totalDaysUsed;
  final int timesAssigned;

  /// Returns true if this IP has been scored by IPQS
  bool get hasBeenScored => lastScoreCheck != null;

  const ProxyIpAddressEntity({
    this.id,
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
    this.isCrawler,
    this.connectionType,
    this.isp,
    this.organization,
    this.region,
    this.recentAbuse,
    required this.fraudScore,
    required this.assignedAt,
    this.removedAt,
    required this.lastVerification,
    this.lastScoreCheck,
    required this.totalDaysUsed,
    required this.timesAssigned,
  });

  factory ProxyIpAddressEntity.empty() {
    return ProxyIpAddressEntity(
      id: null,
      ipAddress: '0.0.0.0',
      hostname: '',
      slotId: 0,
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
      isProxy: true,
      isDatacenter: false,
      isTor: false,
      isCrawler: null,
      connectionType: null,
      isp: null,
      organization: null,
      region: null,
      recentAbuse: null,
      fraudScore: 0,
      assignedAt: DateTime.now(),
      removedAt: null,
      lastVerification: DateTime.now(),
      lastScoreCheck: null,
      totalDaysUsed: 0,
      timesAssigned: 1,
    );
  }

  static IpScoreLevel getScoreLevel(double score) {
    if (score >= 90) return IpScoreLevel.excellent;
    if (score >= 70) return IpScoreLevel.good;
    if (score >= 50) return IpScoreLevel.fair;
    if (score >= 30) return IpScoreLevel.poor;
    if (score > 0) return IpScoreLevel.bad;
    return IpScoreLevel.unknown;
  }

  static String getFraudScoreLabel(double fraudScore) {
    if (fraudScore <= 30) return 'Excellent';
    if (fraudScore <= 60) return 'Fair';
    if (fraudScore <= 80) return 'Poor';
    return 'Bad';
  }

  ProxyIpAddressEntity copyWith({
    int? id,
    String? ipAddress,
    String? hostname,
    int? slotId,
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
    bool? isCrawler,
    String? connectionType,
    String? isp,
    String? organization,
    String? region,
    bool? recentAbuse,
    double? fraudScore,
    DateTime? assignedAt,
    DateTime? removedAt,
    DateTime? lastVerification,
    DateTime? lastScoreCheck,
    int? totalDaysUsed,
    int? timesAssigned,
  }) {
    return ProxyIpAddressEntity(
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
      isCrawler: isCrawler ?? this.isCrawler,
      connectionType: connectionType ?? this.connectionType,
      isp: isp ?? this.isp,
      organization: organization ?? this.organization,
      region: region ?? this.region,
      recentAbuse: recentAbuse ?? this.recentAbuse,
      fraudScore: fraudScore ?? this.fraudScore,
      assignedAt: assignedAt ?? this.assignedAt,
      removedAt: removedAt ?? this.removedAt,
      lastVerification: lastVerification ?? this.lastVerification,
      lastScoreCheck: lastScoreCheck ?? this.lastScoreCheck,
      totalDaysUsed: totalDaysUsed ?? this.totalDaysUsed,
      timesAssigned: timesAssigned ?? this.timesAssigned,
    );
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
        isCrawler,
        connectionType,
        isp,
        organization,
        region,
        recentAbuse,
        fraudScore,
        assignedAt,
        removedAt,
        lastVerification,
        lastScoreCheck,
        totalDaysUsed,
        timesAssigned,
      ];
}
