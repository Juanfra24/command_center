# Dev Tools — Database Viewer & SQL Runner

## Goal

Add an in-app developer tools screen for inspecting and modifying the local SQLite database. Debug-only (hidden in release builds).

## Approach

Hybrid: lightweight in-app table viewer with manual refresh + raw SQL runner for ad-hoc queries + "Open DB Folder" button for external tool access.

## Screen Layout

Single screen, two stacked sections:

```
┌──────────────────────────────────────────────┐
│  Dev Tools                    [Open DB Folder]│
├──────────────────────────────────────────────┤
│  Table Viewer                                │
│  [▼ Table dropdown] [Refresh]                │
│  ┌──────────────────────────────────────────┐│
│  │  col1  │  col2  │  col3  │  ...         ││
│  │  val   │  val   │  val   │  ...         ││
│  │  ...   │  ...   │  ...   │  ...         ││
│  └──────────────────────────────────────────┘│
│  Showing N rows                              │
├──────────────────────────────────────────────┤
│  SQL Runner                                  │
│  ┌──────────────────────────────────────────┐│
│  │  SELECT * FROM accounts_table LIMIT 10   ││
│  └──────────────────────────────────────────┘│
│  [Execute]                                   │
│  ┌──────────────────────────────────────────┐│
│  │  Results table or "N rows affected"      ││
│  └──────────────────────────────────────────┘│
│  Status: Query executed in 12ms              │
└──────────────────────────────────────────────┘
```

## Components

### Navigation Entry
- New `PaneItem` in the footer items of `app.dart`, added after the Settings pane item so the Settings index (3) remains unchanged.
- Gated: only added when `kDebugMode` is true (from `package:flutter/foundation.dart`).
- Icon: `FluentIcons.code` (verified in fluent_ui 4.13.0).

### DevToolsController (GetxController)

The controller accesses `AppDatabase` directly via `DatabaseService.database` rather than going through a service layer, since there is no business logic to encapsulate — this is a passthrough debug tool.

**Dependency injection:** Constructor injection — `DevToolsController(AppDatabase db)`, registered as `Get.lazyPut(() => DevToolsController(Get.find<DatabaseService>().database), fenix: true)`.

**State:**
- `tables`: `RxList<String>` — populated on init by querying `sqlite_master`.
- `selectedTable`: `RxString` — currently selected table name.
- `tableRows`: `RxList<Map<String, dynamic>>` — rows from the selected table.
- `tableColumns`: `RxList<String>` — column names for display.
- `queryResult`: `RxList<Map<String, dynamic>>` — SQL runner results.
- `queryColumns`: `RxList<String>` — SQL runner result columns.
- `queryStatus`: `RxString` — status message ("12 rows in 5ms", "Error: ...", etc.).
- `isLoading`: `RxBool`.

**Methods:**
- `loadTableList()` — `SELECT name FROM sqlite_master WHERE type='table' ORDER BY name`. Runs on init. Includes Drift internal tables (useful for debugging migrations).
- `loadTableData(String tableName)` — `SELECT * FROM <tableName> LIMIT 500`. Sanitize table name against the known table list to prevent injection.
- `executeQuery(String sql)` — For SELECT: use `customSelect(sql)` and convert results via `rows.map((r) => r.data).toList()` (Drift's `QueryRow.data` provides `Map<String, dynamic>`). For writes (INSERT/UPDATE/DELETE): use `customStatement(sql)`. Wrap in try-catch, populate `queryStatus` with result or error. Time the execution. Results limited to 500 rows.
- `openDbFolder()` — Get DB path from `getApplicationDocumentsDirectory()` (mirrors `_openConnection()` in `app_database.dart`), call `Process.run('explorer.exe', [path])`.

### DevToolsScreen
- Layout shell composing the two sections. Title bar with "Dev Tools" label and "Open DB Folder" button.
- Max 100 lines.

### TableViewerSection
- `ComboBox<String>` dropdown for table selection.
- `Button` for refresh.
- Horizontally scrollable `DataTable` (from Fluent UI or Flutter) rendering `tableColumns` as headers and `tableRows` as cells.
- Row count label below: "Showing N rows (limited to 500)".
- All cell values displayed as strings via `.toString()`.
- Max 200 lines.

### SqlRunnerSection
- `TextBox` (multiline, 3-4 lines) for SQL input.
- `FilledButton` "Execute".
- Results: rendered using `ResultDataTable`, or a text message for non-SELECT queries.
- `queryStatus` displayed below results.
- Max 200 lines.

### ResultDataTable (shared component)
- Reusable widget accepting `List<String> columns` and `List<Map<String, dynamic>> rows`.
- Horizontally and vertically scrollable.
- Handles NULL styling (italic grey), string truncation (100 chars with tooltip), and empty state.
- Used by both `TableViewerSection` and `SqlRunnerSection`.
- Max 150 lines.

## SQL Injection Prevention

The table viewer's `loadTableData` validates the table name against the list from `sqlite_master` before interpolating it into the query. The SQL runner intentionally allows arbitrary SQL — it's a developer power tool, not a user-facing feature.

## Data Display

All values rendered as strings. Nulls shown as `NULL` (italic/grey). Long strings truncated at 100 chars with tooltip for full value. Boolean columns show `true`/`false`. DateTime columns show ISO format.

## DI Registration

`DevToolsController` registered as `lazyPut` in `AppBindings`, gated behind `kDebugMode`.

## Error Handling

- SQL errors caught and displayed in `queryStatus` (red text).
- Table load errors shown as an InfoBar.
- DB folder open failure silently logged.

## Testing Strategy

- Controller unit tests: mock the database, verify `loadTableList`, `loadTableData`, `executeQuery` behavior.
- No widget tests needed — this is a debug-only dev tool.

## Files to Create

| File | Type | Purpose |
|------|------|---------|
| `lib/feature/dev_tools/controller/dev_tools_controller.dart` | Controller | Query execution, state |
| `lib/feature/dev_tools/views/dev_tools_screen.dart` | Screen | Layout shell |
| `lib/feature/dev_tools/views/sections/table_viewer_section.dart` | Section | Table dropdown + data grid |
| `lib/feature/dev_tools/views/sections/sql_runner_section.dart` | Section | SQL input + results |
| `lib/feature/dev_tools/views/components/result_data_table.dart` | Component | Shared scrollable data table |

## Files to Modify

| File | Change |
|------|--------|
| `lib/feature/app.dart` | Add Dev Tools nav item (gated on kDebugMode) |
| `lib/core/resource/dependency_injection.dart` | Register DevToolsController (gated on kDebugMode) |
