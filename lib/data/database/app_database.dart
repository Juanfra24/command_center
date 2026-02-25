import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/tables.dart';

part 'app_database.g.dart';

/// Main application database using Drift ORM
@DriftDatabase(
  tables: [
    AppConfigTable,
    ProxySlotsTable,
    ProxyIpAddressesTable,
    AccountsTable,
    CharactersTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add soft delete columns to proxy_slots_table
          await m.addColumn(proxySlotsTable, proxySlotsTable.isDeleted);
          await m.addColumn(proxySlotsTable, proxySlotsTable.deletedAt);
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'command_center.db'));
    return NativeDatabase.createInBackground(file);
  });
}
