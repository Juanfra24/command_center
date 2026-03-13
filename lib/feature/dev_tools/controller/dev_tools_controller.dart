import 'dart:io';

import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class DevToolsController extends GetxController {
  final AppDatabase _db;

  DevToolsController(this._db);

  final tables = <String>[].obs;
  final selectedTable = ''.obs;
  final tableColumns = <String>[].obs;
  final tableRows = <Map<String, dynamic>>[].obs;
  final queryColumns = <String>[].obs;
  final queryResult = <Map<String, dynamic>>[].obs;
  final queryStatus = ''.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadTableList();
  }

  Future<void> loadTableList() async {
    try {
      final result = await _db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .get();
      tables.value = result.map((r) => r.data['name'] as String).toList();
    } catch (e) {
      logger.e('Failed to load table list: $e');
    }
  }

  Future<void> selectTable(String tableName) async {
    selectedTable.value = tableName;
    await loadTableData(tableName);
  }

  Future<void> loadTableData(String tableName) async {
    if (!tables.contains(tableName)) {
      tableColumns.clear();
      tableRows.clear();
      return;
    }

    isLoading.value = true;
    try {
      final result =
          await _db.customSelect('SELECT * FROM "$tableName" LIMIT 500').get();

      if (result.isEmpty) {
        tableColumns.clear();
        tableRows.clear();
      } else {
        tableColumns.value = result.first.data.keys.toList();
        tableRows.value = result.map((r) => r.data).toList();
      }
    } catch (e) {
      logger.e('Failed to load table data: $e');
      tableColumns.clear();
      tableRows.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> executeQuery(String sql) async {
    final trimmed = sql.trim();
    if (trimmed.isEmpty) return;

    isLoading.value = true;
    queryResult.clear();
    queryColumns.clear();
    queryStatus.value = '';
    final stopwatch = Stopwatch()..start();

    try {
      final isSelect = trimmed.toUpperCase().startsWith('SELECT') ||
          trimmed.toUpperCase().startsWith('PRAGMA');

      if (isSelect) {
        final result = await _db.customSelect(trimmed).get();
        stopwatch.stop();

        if (result.isEmpty) {
          queryColumns.clear();
          queryResult.clear();
          queryStatus.value =
              '0 rows returned (${stopwatch.elapsedMilliseconds}ms)';
        } else {
          queryColumns.value = result.first.data.keys.toList();
          queryResult.value = result.map((r) => r.data).toList();
          queryStatus.value =
              '${result.length} rows returned (${stopwatch.elapsedMilliseconds}ms)';
        }
      } else {
        final affected = await _db.customUpdate(trimmed);
        stopwatch.stop();
        queryStatus.value =
            '$affected rows affected (${stopwatch.elapsedMilliseconds}ms)';
      }
    } catch (e) {
      stopwatch.stop();
      queryStatus.value = 'Error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openDbFolder() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await Process.run('explorer.exe', [dir.path]);
    } catch (e) {
      logger.e('Failed to open DB folder: $e');
    }
  }
}
