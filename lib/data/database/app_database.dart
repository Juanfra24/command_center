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
          await _addColumnIfMissing('proxy_slots_table', 'is_deleted');
          await _addColumnIfMissing('proxy_slots_table', 'deleted_at');
        }
        if (from < 3) {
          // Recreate characters_table with ON DELETE CASCADE on accountId.
          // SQLite cannot ALTER foreign key constraints, so we use
          // the copy-and-recreate pattern.
          await customStatement('DROP TABLE IF EXISTS characters_backup');
          // Only recreate if the table lacks CASCADE (skip if a previous
          // crashed migration already recreated it).
          final tableInfo = await customSelect(
            "SELECT sql FROM sqlite_master "
            "WHERE type='table' AND name='characters_table'",
          ).getSingleOrNull();
          final needsRecreate = tableInfo != null &&
              !(tableInfo.data['sql'] as String? ?? '')
                  .toUpperCase()
                  .contains('CASCADE');
          if (needsRecreate) {
            await customStatement(
              'CREATE TABLE characters_backup '
              'AS SELECT * FROM characters_table',
            );
            await customStatement('DROP TABLE characters_table');
            await m.createTable(charactersTable);
            await customStatement(
              'INSERT INTO characters_table '
              'SELECT * FROM characters_backup',
            );
            await customStatement('DROP TABLE characters_backup');
          }
        }
        if (from < 4) {
          final exists = await customSelect(
            "SELECT 1 FROM sqlite_master "
            "WHERE type='table' AND name='notifications_table'",
          ).getSingleOrNull();
          if (exists == null) {
            await m.createTable(notificationsTable);
          }
        }
        if (from < 5) {
          // Add new IPQS columns to proxy_ip_addresses (idempotent)
          await _addColumnIfMissing('proxy_ip_addresses_table', 'is_crawler');
          await _addColumnIfMissing(
            'proxy_ip_addresses_table',
            'connection_type',
          );
          await _addColumnIfMissing('proxy_ip_addresses_table', 'isp');
          await _addColumnIfMissing(
            'proxy_ip_addresses_table',
            'organization',
          );
          await _addColumnIfMissing('proxy_ip_addresses_table', 'region');
          await _addColumnIfMissing(
            'proxy_ip_addresses_table',
            'recent_abuse',
          );
          // Populate recentAbuse from abuseConfidence (safe to re-run)
          await customStatement(
            'UPDATE proxy_ip_addresses_table SET recent_abuse = CASE '
            'WHEN abuse_confidence > 0 THEN 1 '
            'WHEN abuse_confidence = 0 THEN 0 '
            'ELSE NULL END '
            'WHERE recent_abuse IS NULL',
          );
          // Add defaultScriptName to characters
          await _addColumnIfMissing('characters_table', 'default_script_name');
        }
        if (from < 6) {
          await _addColumnIfMissing('proxy_slots_table', 'socks_port');
        }
        if (from < 7) {
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

  /// Idempotent column addition — skips if column already exists.
  /// Prevents crashes when a previous migration was interrupted.
  Future<void> _addColumnIfMissing(String table, String column) async {
    final cols = await customSelect('PRAGMA table_info($table)').get();
    final exists = cols.any((row) => row.data['name'] == column);
    if (!exists) {
      await customStatement(
        'ALTER TABLE "$table" ADD COLUMN "$column" TEXT NULL',
      );
    }
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
