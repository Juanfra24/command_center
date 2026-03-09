import 'package:drift/drift.dart';

/// Table for storing proxy slots from Webshare
class ProxySlotsTable extends Table {
  /// Auto-increment primary key
  IntColumn get id => integer().autoIncrement()();

  /// Webshare proxy ID (unique)
  TextColumn get webshareId => text().unique()();

  /// Slot name/label
  TextColumn get slotName => text().withDefault(const Constant(''))();

  /// Slot number (unique, used for ordering)
  IntColumn get slotNumber => integer().unique()();

  /// Reference to the current active IP address (nullable)
  IntColumn get currentIpAddressId => integer().nullable()();

  /// Proxy username
  TextColumn get username => text()();

  /// Proxy password
  TextColumn get password => text()();

  /// Proxy port
  IntColumn get port => integer().withDefault(const Constant(0))();

  /// When this slot was first created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this slot was last updated
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  /// Total number of IP changes for this slot
  IntColumn get totalIpChanges => integer().withDefault(const Constant(0))();

  /// Whether this slot is active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Whether this slot has been soft-deleted
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// When this slot was soft-deleted
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
