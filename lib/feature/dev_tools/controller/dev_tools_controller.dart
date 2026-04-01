import 'dart:io';

import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/platform_open.dart';
import 'package:command_center/data/database/app_database.dart';
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
      await openInFileManager(dir.path);
    } catch (e) {
      logger.e('Failed to open DB folder: $e');
    }
  }

  /// Delete the database file and exit the app so setup re-runs on next launch.
  Future<void> resetDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/command_center.db');
      if (await dbFile.exists()) {
        await dbFile.delete();
        logger.i('Database deleted: ${dbFile.path}');
      }
      // Exit so the app restarts with a fresh DB + setup flow
      exit(0);
    } catch (e) {
      logger.e('Failed to reset database: $e');
    }
  }

  /// Clear Java/JAR config, force script re-extraction, and exit
  /// so setup re-downloads dependencies with latest code.
  Future<void> rerunSetup() async {
    try {
      final appConfig = Get.find<AppConfigService>();
      await appConfig.saveMicrobotJavaPath('');
      await appConfig.saveMicrobotJarPath('');
      await appConfig.saveMicrobotJarVersion('');
      // Delete scripts version marker to force re-extraction
      await _deleteScriptsVersionMarker();
      logger.i('Cleared setup config — restarting');
      exit(0);
    } catch (e) {
      logger.e('Failed to clear setup config: $e');
    }
  }

  Future<void> _deleteScriptsVersionMarker() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final marker = File('${dir.path}/scripts/.scripts_version');
      if (await marker.exists()) {
        await marker.delete();
        logger.i('Deleted scripts version marker');
      }
    } catch (e) {
      logger.w('Could not delete scripts version marker: $e');
    }
  }
}
