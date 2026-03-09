import 'package:drift/drift.dart';

/// Table for storing application configuration as key-value pairs
class AppConfigTable extends Table {
  /// The configuration key (unique identifier)
  TextColumn get key => text()();

  /// The configuration value (stored as JSON string for complex types)
  TextColumn get value => text()();

  /// When this config entry was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this config entry was last updated
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
