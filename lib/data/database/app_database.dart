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
    NotificationsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create performance indices
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ip_slot_active '
          'ON proxy_ip_addresses_table (slot_id, is_active)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_char_account '
          'ON characters_table (account_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_notif_is_read '
          'ON notifications_table (is_read)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add soft delete columns to proxy_slots_table
          await m.addColumn(proxySlotsTable, proxySlotsTable.isDeleted);
          await m.addColumn(proxySlotsTable, proxySlotsTable.deletedAt);
        }
        if (from < 3) {
          // Recreate characters_table with ON DELETE CASCADE on accountId.
          // SQLite cannot ALTER foreign key constraints, so we use
          // the copy-and-recreate pattern.
          await customStatement(
            'CREATE TABLE characters_backup AS SELECT * FROM characters_table',
          );
          await customStatement('DROP TABLE characters_table');
          await m.createTable(charactersTable);
          await customStatement(
            'INSERT INTO characters_table SELECT * FROM characters_backup',
          );
          await customStatement('DROP TABLE characters_backup');
        }
        if (from < 4) {
          await m.createTable(notificationsTable);
        }
        if (from < 5) {
          // Add new IPQS columns to proxy_ip_addresses
          await m.addColumn(
            proxyIpAddressesTable,
            proxyIpAddressesTable.isCrawler,
          );
          await m.addColumn(
            proxyIpAddressesTable,
            proxyIpAddressesTable.connectionType,
          );
          await m.addColumn(
            proxyIpAddressesTable,
            proxyIpAddressesTable.isp,
          );
          await m.addColumn(
            proxyIpAddressesTable,
            proxyIpAddressesTable.organization,
          );
          await m.addColumn(
            proxyIpAddressesTable,
            proxyIpAddressesTable.region,
          );
          await m.addColumn(
            proxyIpAddressesTable,
            proxyIpAddressesTable.recentAbuse,
          );
          // Populate recentAbuse from abuseConfidence
          // NOTE: Drift table name is `proxy_ip_addresses_table` (snake_case of class name)
          await customStatement(
            'UPDATE proxy_ip_addresses_table SET recent_abuse = CASE '
            'WHEN abuse_confidence > 0 THEN 1 '
            'WHEN abuse_confidence = 0 THEN 0 '
            'ELSE NULL END',
          );
          // Add defaultScriptName to characters
          await m.addColumn(
            charactersTable,
            charactersTable.defaultScriptName,
          );
        }
        if (from < 6) {
          await m.addColumn(proxySlotsTable, proxySlotsTable.socksPort);
        }
        if (from < 7) {
          // Add indices for the most-queried columns
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_ip_slot_active '
            'ON proxy_ip_addresses_table (slot_id, is_active)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_char_account '
            'ON characters_table (account_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notif_is_read '
            'ON notifications_table (is_read)',
          );
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
