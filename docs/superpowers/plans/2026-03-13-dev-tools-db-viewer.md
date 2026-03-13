# Dev Tools — Database Viewer & SQL Runner Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a debug-only in-app database viewer with table browsing, raw SQL execution, and "Open DB Folder" button.

**Architecture:** New `dev_tools` feature with a controller that runs raw SQL via Drift's `customSelect`/`customStatement`. Two sections (table viewer + SQL runner) share a `ResultDataTable` component. Gated behind `kDebugMode`.

**Tech Stack:** Flutter, Fluent UI, GetX, Drift ORM (customSelect/customStatement)

---

## File Map

| File | Type | Responsibility |
|------|------|----------------|
| `lib/feature/dev_tools/controller/dev_tools_controller.dart` | Controller | Query `sqlite_master`, load table data, execute arbitrary SQL, open DB folder |
| `lib/feature/dev_tools/views/dev_tools_screen.dart` | Screen | Layout shell composing sections |
| `lib/feature/dev_tools/views/sections/table_viewer_section.dart` | Section | Table dropdown + refresh + data grid |
| `lib/feature/dev_tools/views/sections/sql_runner_section.dart` | Section | SQL text input + execute + results |
| `lib/feature/dev_tools/views/components/result_data_table.dart` | Component | Shared scrollable data table with NULL styling |
| `lib/feature/app.dart` | Modify | Add Dev Tools nav item in footer (gated on kDebugMode) |
| `lib/core/resource/dependency_injection.dart` | Modify | Register DevToolsController (gated on kDebugMode) |

---

## Chunk 1: Controller + Shared Component + Tests

### Task 1: Create DevToolsController

**Files:**
- Create: `lib/feature/dev_tools/controller/dev_tools_controller.dart`
- Test: `test/feature/dev_tools/controller/dev_tools_controller_test.dart`

- [ ] **Step 1: Write controller test file**

```dart
// test/feature/dev_tools/controller/dev_tools_controller_test.dart
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
      // Should include our app tables
      expect(controller.tables, contains('app_config_table'));
      expect(controller.tables, contains('proxy_slots_table'));
      expect(controller.tables, contains('accounts_table'));
      expect(controller.tables, contains('notifications_table'));
    });

    test('loadTableData returns rows for a valid table', () async {
      await controller.loadTableList();

      // Insert a config row first
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
      // Insert test data
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

      // Verify the insert worked
      final rows =
          await db.select(db.appConfigTable).get();
      expect(rows.any((r) => r.key == 'a'), isTrue);
    });

    test('executeQuery catches SQL errors gracefully', () async {
      await controller.executeQuery('SELECT * FROM nonexistent_table_xyz');

      expect(controller.queryStatus.value, contains('Error'));
      expect(controller.queryResult, isEmpty);
    });

    test('selectedTable updates and loads data', () async {
      await controller.loadTableList();
      await controller.selectTable('app_config_table');

      expect(controller.selectedTable.value, 'app_config_table');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/feature/dev_tools/controller/dev_tools_controller_test.dart`
Expected: FAIL — `dev_tools_controller.dart` does not exist

- [ ] **Step 3: Write DevToolsController implementation**

```dart
// lib/feature/dev_tools/controller/dev_tools_controller.dart
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
      final result = await _db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      ).get();
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
    // Validate against known tables to prevent injection
    if (!tables.contains(tableName)) {
      tableColumns.clear();
      tableRows.clear();
      return;
    }

    isLoading.value = true;
    try {
      final result = await _db.customSelect(
        'SELECT * FROM "$tableName" LIMIT 500',
      ).get();

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
      final isSelect =
          trimmed.toUpperCase().startsWith('SELECT') ||
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/feature/dev_tools/controller/dev_tools_controller_test.dart`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/feature/dev_tools/controller/dev_tools_controller.dart \
        test/feature/dev_tools/controller/dev_tools_controller_test.dart
git commit -m "feat(dev-tools): add DevToolsController with table list, data loading, and SQL execution"
```

---

### Task 2: Create ResultDataTable shared component

**Files:**
- Create: `lib/feature/dev_tools/views/components/result_data_table.dart`

- [ ] **Step 1: Write ResultDataTable component**

```dart
// lib/feature/dev_tools/views/components/result_data_table.dart
import 'package:fluent_ui/fluent_ui.dart';

class ResultDataTable extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;

  const ResultDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (columns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No data', style: theme.typography.caption),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
              ),
              children: columns
                  .map((col) => _buildHeaderCell(col))
                  .toList(),
            ),
            // Data rows
            ...rows.map((row) => TableRow(
                  children: columns
                      .map((col) => _buildDataCell(row[col], theme))
                      .toList(),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildDataCell(dynamic value, FluentThemeData theme) {
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'NULL',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: theme.resources.textFillColorDisabled,
            fontSize: 12,
          ),
        ),
      );
    }

    final text = value.toString();
    final display = text.length > 100 ? '${text.substring(0, 100)}...' : text;

    return Tooltip(
      message: text.length > 100 ? text : '',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(display, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/dev_tools/views/components/result_data_table.dart
git commit -m "feat(dev-tools): add ResultDataTable shared component"
```

---

## Chunk 2: Screen, Sections, and Integration

### Task 3: Create TableViewerSection

**Files:**
- Create: `lib/feature/dev_tools/views/sections/table_viewer_section.dart`

- [ ] **Step 1: Write TableViewerSection**

```dart
// lib/feature/dev_tools/views/sections/table_viewer_section.dart
import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/components/result_data_table.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class TableViewerSection extends StatelessWidget {
  final DevToolsController controller;

  const TableViewerSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.table, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('Table Viewer', style: theme.typography.bodyLarge),
            ],
          ),
          const SizedBox(height: 12),
          _buildControls(),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.isLoading.value &&
                controller.selectedTable.isNotEmpty) {
              return const Center(child: ProgressRing());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ResultDataTable(
                    columns: controller.tableColumns.toList(),
                    rows: controller.tableRows.toList(),
                  ),
                ),
                if (controller.tableRows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing ${controller.tableRows.length} rows (limited to 500)',
                      style: theme.typography.caption,
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Obx(() => Row(
          children: [
            SizedBox(
              width: 250,
              child: ComboBox<String>(
                value: controller.selectedTable.value.isEmpty
                    ? null
                    : controller.selectedTable.value,
                placeholder: const Text('Select a table...'),
                items: controller.tables
                    .map((t) => ComboBoxItem<String>(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.selectTable(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: controller.selectedTable.value.isEmpty
                  ? null
                  : () =>
                      controller.loadTableData(controller.selectedTable.value),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 14),
                  SizedBox(width: 4),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ));
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/dev_tools/views/sections/table_viewer_section.dart
git commit -m "feat(dev-tools): add TableViewerSection with dropdown and data grid"
```

---

### Task 4: Create SqlRunnerSection

**Files:**
- Create: `lib/feature/dev_tools/views/sections/sql_runner_section.dart`

- [ ] **Step 1: Write SqlRunnerSection**

```dart
// lib/feature/dev_tools/views/sections/sql_runner_section.dart
import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/components/result_data_table.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SqlRunnerSection extends StatefulWidget {
  final DevToolsController controller;

  const SqlRunnerSection({super.key, required this.controller});

  @override
  State<SqlRunnerSection> createState() => _SqlRunnerSectionState();
}

class _SqlRunnerSectionState extends State<SqlRunnerSection> {
  final _sqlController = TextEditingController();

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.code, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('SQL Runner', style: theme.typography.bodyLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextBox(
            controller: _sqlController,
            placeholder: 'Enter SQL query...',
            maxLines: 4,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: () =>
                    widget.controller.executeQuery(_sqlController.text),
                child: const Text('Execute'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () {
                  _sqlController.clear();
                  widget.controller.queryResult.clear();
                  widget.controller.queryColumns.clear();
                  widget.controller.queryStatus.value = '';
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (widget.controller.isLoading.value &&
                widget.controller.queryStatus.isEmpty) {
              return const Center(child: ProgressRing());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.controller.queryColumns.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ResultDataTable(
                      columns: widget.controller.queryColumns.toList(),
                      rows: widget.controller.queryResult.toList(),
                    ),
                  ),
                if (widget.controller.queryStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.controller.queryStatus.value,
                      style: TextStyle(
                        color:
                            widget.controller.queryStatus.value.startsWith('Error')
                                ? Colors.red
                                : theme.resources.textFillColorSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/dev_tools/views/sections/sql_runner_section.dart
git commit -m "feat(dev-tools): add SqlRunnerSection with text input and results"
```

---

### Task 5: Create DevToolsScreen

**Files:**
- Create: `lib/feature/dev_tools/views/dev_tools_screen.dart`

- [ ] **Step 1: Write DevToolsScreen**

```dart
// lib/feature/dev_tools/views/dev_tools_screen.dart
import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/sections/sql_runner_section.dart';
import 'package:command_center/feature/dev_tools/views/sections/table_viewer_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class DevToolsScreen extends StatelessWidget {
  const DevToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DevToolsController>();
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Dev Tools'),
        commandBar: Button(
          onPressed: controller.openDbFolder,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.open_folder_horizontal, size: 14),
              SizedBox(width: 4),
              Text('Open DB Folder'),
            ],
          ),
        ),
      ),
      children: [
        TableViewerSection(controller: controller),
        const SizedBox(height: 16),
        SqlRunnerSection(controller: controller),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/dev_tools/views/dev_tools_screen.dart
git commit -m "feat(dev-tools): add DevToolsScreen layout shell"
```

---

### Task 6: Register in DI and add navigation entry

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart`
- Modify: `lib/feature/app.dart`

- [ ] **Step 1: Register DevToolsController in DI**

In `lib/core/resource/dependency_injection.dart`, add import at the top:

```dart
import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:flutter/foundation.dart';
```

At the end of the `dependencies()` method (after the `ProxyAutoRotationService` registration, before the closing `}`), add:

```dart
    // Dev tools (debug only)
    if (kDebugMode) {
      Get.lazyPut<DevToolsController>(
        () => DevToolsController(Get.find<DatabaseService>().database),
        fenix: true,
      );
    }
```

- [ ] **Step 2: Add Dev Tools nav item in app.dart**

In `lib/feature/app.dart`, add imports:

```dart
import 'package:command_center/feature/dev_tools/views/dev_tools_screen.dart';
import 'package:flutter/foundation.dart';
```

In `_buildMainContent`, in the `footerItems` list, after the Settings `PaneItem` closing parenthesis, add:

```dart
            if (kDebugMode)
              PaneItem(
                icon: const Icon(FluentIcons.code),
                title: const Text('Dev Tools'),
                body: const DevToolsScreen(),
              ),
```

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass (including the new dev_tools_controller_test)

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/core/resource/dependency_injection.dart lib/feature/app.dart
git commit -m "feat(dev-tools): register controller in DI and add navigation entry (debug only)"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 2: Run analyzer**

Run: `dart analyze`
Expected: No issues found

- [ ] **Step 3: Run dart format**

Run: `dart format --set-exit-if-changed .`
Fix any formatting issues.

- [ ] **Step 4: Commit any format fixes**

```bash
git add -A
git commit -m "chore: apply dart format to dev tools files"
```
