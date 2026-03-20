import 'package:drift/drift.dart';

import 'proxy_slots_table.dart';

/// Table for storing proxy IP addresses and their quality scores
class ProxyIpAddressesTable extends Table {
  /// Auto-increment primary key
  IntColumn get id => integer().autoIncrement()();

  /// The IP address
  TextColumn get ipAddress => text()();

  /// The hostname
  TextColumn get hostname => text().withDefault(const Constant(''))();

  /// Reference to the proxy slot this IP belongs to
  IntColumn get slotId => integer().references(ProxySlotsTable, #id)();

  /// Whether this IP is currently active for its slot
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  // Geographic information
  /// Country code (e.g., 'US', 'UK')
  TextColumn get countryCode => text().withDefault(const Constant('XX'))();

  /// City name
  TextColumn get cityName => text().withDefault(const Constant(''))();

  /// IP timezone
  TextColumn get ipTimezone => text().withDefault(const Constant('UTC'))();

  /// Whether country detection has high confidence
  BoolColumn get highCountryConfidence =>
      boolean().withDefault(const Constant(false))();

  // ASN information
  /// ASN name (e.g., 'Comcast')
  TextColumn get asnName => text().withDefault(const Constant(''))();

  /// ASN number
  IntColumn get asnNumber => integer().withDefault(const Constant(0))();

  // Score information
  /// IP quality score (0-100)
  RealColumn get ipScore => real().withDefault(const Constant(0.0))();

  /// Score level: excellent, good, fair, poor, bad, unknown
  TextColumn get scoreLevel => text().withDefault(const Constant('unknown'))();

  /// Whether detected as VPN
  BoolColumn get isVpn => boolean().withDefault(const Constant(false))();

  /// Whether detected as proxy
  BoolColumn get isProxy => boolean().withDefault(const Constant(true))();

  /// Whether detected as datacenter IP
  BoolColumn get isDatacenter => boolean().withDefault(const Constant(false))();

  /// Whether detected as TOR exit node
  BoolColumn get isTor => boolean().withDefault(const Constant(false))();

  /// Fraud score from IP quality service
  RealColumn get fraudScore => real().withDefault(const Constant(0.0))();

  /// Abuse confidence percentage (0-100)
  IntColumn get abuseConfidence => integer().withDefault(const Constant(0))();

  BoolColumn get isCrawler => boolean().nullable().named('is_crawler')();

  TextColumn get connectionType => text().nullable().named('connection_type')();

  TextColumn get isp => text().nullable()();

  TextColumn get organization => text().nullable()();

  TextColumn get region => text().nullable()();

  BoolColumn get recentAbuse => boolean().nullable().named('recent_abuse')();

  // Timestamps
  /// When this IP was assigned to the slot
  DateTimeColumn get assignedAt => dateTime().withDefault(currentDateAndTime)();

  /// When this IP was removed/replaced (null if still active)
  DateTimeColumn get removedAt => dateTime().nullable()();

  /// Last verification timestamp
  DateTimeColumn get lastVerification =>
      dateTime().withDefault(currentDateAndTime)();

  /// Last IP score check timestamp
  DateTimeColumn get lastScoreCheck => dateTime().nullable()();

  // Usage statistics
  /// Total days this IP has been used
  IntColumn get totalDaysUsed => integer().withDefault(const Constant(0))();

  /// Number of times this IP has been assigned
  IntColumn get timesAssigned => integer().withDefault(const Constant(1))();
}
