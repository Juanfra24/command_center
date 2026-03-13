import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DevToolsController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    controller = DevToolsController(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DevToolsController', () {
    test('loadTableList populates tables from sqlite_master', () async {
      await controller.loadTableList();

      expect(controller.tables, isNotEmpty);
      expect(controller.tables, contains('app_config_table'));
      expect(controller.tables, contains('proxy_slots_table'));
      expect(controller.tables, contains('accounts_table'));
      expect(controller.tables, contains('notifications_table'));
    });

    test('loadTableData returns rows for a valid table', () async {
      await controller.loadTableList();

      await db.into(db.appConfigTable).insert(
            AppConfigTableCompanion.insert(
              key: 'test_key',
              value: 'test_value',
            ),
          );

      await controller.loadTableData('app_config_table');

      expect(controller.tableColumns, isNotEmpty);
      expect(controller.tableColumns, contains('key'));
      expect(controller.tableColumns, contains('value'));
      expect(controller.tableRows.length, 1);
      expect(controller.tableRows[0]['key'], 'test_key');
    });

    test('loadTableData rejects unknown table names', () async {
      await controller.loadTableList();
      await controller.loadTableData('robert; DROP TABLE students;--');

      expect(controller.tableRows, isEmpty);
    });

    test('executeQuery runs SELECT and returns results', () async {
      await db.into(db.appConfigTable).insert(
            AppConfigTableCompanion.insert(
              key: 'hello',
              value: 'world',
            ),
          );

      await controller.executeQuery(
          "SELECT key, value FROM app_config_table WHERE key = 'hello'");

      expect(controller.queryColumns, contains('key'));
      expect(controller.queryResult.length, 1);
      expect(controller.queryResult[0]['value'], 'world');
      expect(controller.queryStatus.value, contains('1'));
    });

    test('executeQuery runs INSERT and reports rows affected', () async {
      await controller.executeQuery(
          "INSERT INTO app_config_table (key, value) VALUES ('a', 'b')");

      expect(controller.queryStatus.value, contains('affected'));

      final rows = await db.select(db.appConfigTable).get();
      expect(rows.any((r) => r.key == 'a'), isTrue);
    });

    test('executeQuery catches SQL errors gracefully', () async {
      await controller.executeQuery('SELECT * FROM nonexistent_table_xyz');

      expect(controller.queryStatus.value, contains('Error'));
      expect(controller.queryResult, isEmpty);
    });

    test('selectTable updates selectedTable and loads data', () async {
      await controller.loadTableList();
      await controller.selectTable('app_config_table');

      expect(controller.selectedTable.value, 'app_config_table');
    });
  });
}
