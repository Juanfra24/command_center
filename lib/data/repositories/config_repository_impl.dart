import 'package:drift/drift.dart';

import '../../domain/repositories/config_repository.dart';
import '../database/app_database.dart';

/// Drift implementation of the ConfigRepository
class ConfigRepositoryImpl implements ConfigRepository {
  final AppDatabase _db;

  ConfigRepositoryImpl(this._db);

  @override
  Future<String?> getValue(String key) async {
    final query = _db.select(_db.appConfigTable)
      ..where((tbl) => tbl.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  @override
  Future<void> setValue(String key, String value) async {
    await _db.into(_db.appConfigTable).insertOnConflictUpdate(
          AppConfigTableCompanion.insert(
            key: key,
            value: value,
            lastUpdated: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> deleteValue(String key) async {
    await (_db.delete(_db.appConfigTable)..where((tbl) => tbl.key.equals(key)))
        .go();
  }

  @override
  Future<Map<String, String>> getAllConfig() async {
    final results = await _db.select(_db.appConfigTable).get();
    return {for (var row in results) row.key: row.value};
  }

  @override
  Future<void> clearAll() async {
    await _db.delete(_db.appConfigTable).go();
  }

  @override
  Stream<String?> watchValue(String key) {
    final query = _db.select(_db.appConfigTable)
      ..where((tbl) => tbl.key.equals(key));
    return query.watchSingleOrNull().map((row) => row?.value);
  }
}
