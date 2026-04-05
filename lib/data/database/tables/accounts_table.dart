import 'package:drift/drift.dart';

import 'proxy_slots_table.dart';

/// Table for storing Jagex accounts
class AccountsTable extends Table {
  /// Auto-increment primary key
  IntColumn get id => integer().autoIncrement()();

  /// Account name/label
  TextColumn get accountName => text()();

  /// Birthday (stored as string, e.g., '01-01-2000')
  TextColumn get birthday => text().withDefault(const Constant('01-01-2000'))();

  /// Account email (unique)
  TextColumn get email => text().unique()();

  /// Account password
  TextColumn get password => text()();

  /// Reference to the proxy slot this account uses (nullable)
  IntColumn get proxySlotId =>
      integer().nullable().references(ProxySlotsTable, #id)();

  /// When this account was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this account was last updated
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  /// OAuth refresh token for Jagex account (long-lived, weeks/months)
  TextColumn get jagexRefreshToken => text().nullable()();

  /// Jagex account character ID from game-session API
  TextColumn get jagexCharacterId => text().nullable()();

  /// Jagex display name from game-session API
  TextColumn get jagexDisplayName => text().nullable()();
}

/// Table for storing game characters belonging to accounts
class CharactersTable extends Table {
  /// Auto-increment primary key
  IntColumn get id => integer().autoIncrement()();

  /// Reference to the account this character belongs to.
  /// Cascade delete: when an account is deleted, its characters are removed.
  IntColumn get accountId =>
      integer().references(AccountsTable, #id, onDelete: KeyAction.cascade)();

  /// Character name
  TextColumn get name => text()();

  /// Whether this character is banned
  BoolColumn get banned => boolean().withDefault(const Constant(false))();

  /// Actual skills stored as JSON string
  TextColumn get actualSkillsJson => text().withDefault(const Constant('{}'))();

  /// Target skills stored as JSON string
  TextColumn get targetSkillsJson => text().withDefault(const Constant('{}'))();

  /// When this character was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this character was last updated
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get defaultScriptName =>
      text().nullable().named('default_script_name')();
}
