# UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unified UX improvement pass across 5 areas — shared UI patterns, accounts table, proxy detail, dashboard, and status feedback — with accurate IPQS data display and default-script-based bulk launch.

**Architecture:** Bottom-up implementation: data layer first (migration, entities, repos), then shared widgets, then feature-by-feature UI rewrites. Each chunk produces compilable, testable code.

**Tech Stack:** Flutter (Windows desktop), Fluent UI, GetX (state management), Drift ORM (SQLite), Patchright (automation)

**Spec:** `docs/superpowers/specs/2026-03-15-ux-improvements-design.md`

---

## Chunk 1: Data Layer Foundation

### Task 1: DB Migration v5 — New IPQS Columns + defaultScriptName

**Files:**
- Modify: `lib/data/database/tables/proxy_ip_addresses_table.dart`
- Modify: `lib/data/database/tables/accounts_table.dart`
- Modify: `lib/data/database/app_database.dart`
- Test: `test/data/database/migration_v5_test.dart` (new)

- [ ] **Step 1: Add new columns to ProxyIpAddressesTable**

In `lib/data/database/tables/proxy_ip_addresses_table.dart`, add after the `abuseConfidence` column (line 66):

```dart
BoolColumn get isCrawler =>
    boolean().nullable().named('is_crawler')();

TextColumn get connectionType =>
    text().nullable().named('connection_type')();

TextColumn get isp => text().nullable()();

TextColumn get organization => text().nullable()();

TextColumn get region => text().nullable()();

BoolColumn get recentAbuse =>
    boolean().nullable().named('recent_abuse')();
```

- [ ] **Step 2: Add defaultScriptName to CharactersTable**

In `lib/data/database/tables/accounts_table.dart`, in the **`CharactersTable`** class (lines 34-62, NOT `AccountsTable`), add after `lastUpdated` column (line 61):

```dart
TextColumn get defaultScriptName =>
    text().nullable().named('default_script_name')();
```

- [ ] **Step 3: Write migration v5 in app_database.dart**

In `lib/data/database/app_database.dart`, change `schemaVersion` from `4` to `5` (line 30).

Add migration block after the `from < 4` block (after line 60):

```dart
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
  // (codebase only ever stores 0 or 100, but use > 0 defensively)
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
```

- [ ] **Step 4: Run Drift code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `.g.dart` files with new column mappings.

- [ ] **Step 5: Commit**

```bash
git add lib/data/database/
git commit -m "feat(db): migration v5 — add IPQS columns and defaultScriptName"
```

---

### Task 2: Update ProxyIpAddressEntity

**Files:**
- Modify: `lib/domain/entities/proxy_ip_address.dart`
- Test: `test/domain/entities/proxy_ip_address_entity_test.dart` (new)

- [ ] **Step 1: Write test for new fields and factory**

Create `test/domain/entities/proxy_ip_address_entity_test.dart`:

```dart
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProxyIpAddressEntity', () {
    test('empty factory includes new IPQS fields as null/false', () {
      final entity = ProxyIpAddressEntity.empty();
      expect(entity.isCrawler, isNull);
      expect(entity.connectionType, isNull);
      expect(entity.isp, isNull);
      expect(entity.organization, isNull);
      expect(entity.region, isNull);
      expect(entity.recentAbuse, isNull);
    });

    test('copyWith updates new fields', () {
      final entity = ProxyIpAddressEntity.empty();
      final updated = entity.copyWith(
        isCrawler: true,
        connectionType: 'datacenter',
        isp: 'AT&T',
        organization: 'AT&T Corp',
        region: 'New York',
        recentAbuse: false,
      );
      expect(updated.isCrawler, true);
      expect(updated.connectionType, 'datacenter');
      expect(updated.isp, 'AT&T');
      expect(updated.organization, 'AT&T Corp');
      expect(updated.region, 'New York');
      expect(updated.recentAbuse, false);
    });

    test('getFraudScoreLabel returns correct labels', () {
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(10),
        'Excellent',
      );
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(45),
        'Fair',
      );
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(70),
        'Poor',
      );
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(90),
        'Bad',
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/proxy_ip_address_entity_test.dart`
Expected: FAIL — fields don't exist yet.

- [ ] **Step 3: Add new fields to ProxyIpAddressEntity**

In `lib/domain/entities/proxy_ip_address.dart`, add fields after `isTor` (around line 38):

```dart
final bool? isCrawler;
final String? connectionType;
final String? isp;
final String? organization;
final String? region;
final bool? recentAbuse;
```

**Do NOT remove `abuseConfidence` yet** — the repository layer (Task 4) still references it. It will be removed in Task 4 alongside the repository update to avoid broken intermediate commits. Similarly, **do NOT** add `@Deprecated` to `ipScore`/`IpScoreLevel`/`getScoreLevel()` — they are still actively used in the DB layer and UI. Just add the new fields alongside existing ones.

Add static method:

```dart
static String getFraudScoreLabel(double fraudScore) {
  if (fraudScore <= 30) return 'Excellent';
  if (fraudScore <= 60) return 'Fair';
  if (fraudScore <= 80) return 'Poor';
  return 'Bad';
}
```

Update the constructor to include new fields (nullable, not required). Update `empty()` factory to initialize them as `null`. Update `copyWith()` to handle new fields. Update `props` list to include new fields. Keep `abuseConfidence` in `props` for now (removed in Task 4).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/proxy_ip_address_entity_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/proxy_ip_address.dart test/domain/entities/
git commit -m "feat(entity): add IPQS fields to ProxyIpAddressEntity"
```

---

### Task 3: Update CharacterEntity

**Files:**
- Modify: `lib/domain/entities/character.dart`

- [ ] **Step 1: Add defaultScriptName field**

In `lib/domain/entities/character.dart`, add field after `banned` (line 11):

```dart
final String? defaultScriptName;
```

Update constructor to include `this.defaultScriptName`. Update `empty()` to return `defaultScriptName: null`. Update `copyWith()` to include `defaultScriptName`. Update `props` to include `defaultScriptName`.

- [ ] **Step 2: Verify existing tests still pass**

Run: `flutter test test/`
Expected: PASS (entity still has `abuseConfidence` — it will be removed in Task 4).

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/character.dart
git commit -m "feat(entity): add defaultScriptName to CharacterEntity"
```

---

### Task 4: Update Repository Layer

**Files:**
- Modify: `lib/data/repositories/proxy_repository_impl.dart`
- Test: `test/data/repositories/proxy_repository_impl_test.dart` (update)

- [ ] **Step 0: Remove `abuseConfidence` from ProxyIpAddressEntity**

Now that the repository is being updated in the same commit, remove `abuseConfidence` from `lib/domain/entities/proxy_ip_address.dart`: delete the field, remove it from the constructor, `empty()`, `copyWith()`, and `props`. This keeps the codebase compilable at every commit boundary.

- [ ] **Step 1: Update _mapIpAddressRow (lines 316-347)**

Add new field mappings after the existing fields:

```dart
isCrawler: row.isCrawler,
connectionType: row.connectionType,
isp: row.isp,
organization: row.organization,
region: row.region,
recentAbuse: row.recentAbuse,
```

Remove: `abuseConfidence: row.abuseConfidence`

- [ ] **Step 2: Update insertIpAddress (lines 193-222)**

Add to the companion insert:

```dart
isCrawler: Value(ip.isCrawler),
connectionType: Value(ip.connectionType),
isp: Value(ip.isp),
organization: Value(ip.organization),
region: Value(ip.region),
recentAbuse: Value(ip.recentAbuse),
```

Remove: `abuseConfidence: Value(ip.abuseConfidence)`

- [ ] **Step 3: Update updateIpAddress (lines 225-258)**

Same pattern as insertIpAddress — add new Value() wraps, remove abuseConfidence.

- [ ] **Step 4: Update existing repository tests**

In `test/data/repositories/proxy_repository_impl_test.dart`, update any entity construction to use `recentAbuse` instead of `abuseConfidence`, and add the new nullable fields.

- [ ] **Step 5: Run tests**

Run: `flutter test test/data/repositories/proxy_repository_impl_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/proxy_repository_impl.dart test/data/repositories/
git commit -m "feat(repo): map new IPQS columns in proxy repository"
```

---

### Task 4.5: Update Account Repository + Character Presentation Model

**Files:**
- Modify: `lib/domain/repositories/account_repository.dart` (interface)
- Modify: `lib/data/repositories/account_repository_impl.dart`
- Modify: `lib/feature/Status/data/character_model.dart`
- Modify: `lib/feature/Status/controller/status_controller.dart`
- Test: `test/data/repositories/account_repository_impl_test.dart` (update)

- [ ] **Step 1: Add updateCharacterDefaultScript to AccountRepository interface**

In `lib/domain/repositories/account_repository.dart`, add:

```dart
Future<void> updateCharacterDefaultScript(int characterId, String? scriptName);
```

- [ ] **Step 2: Update AccountRepositoryImpl**

In `lib/data/repositories/account_repository_impl.dart`:

Update `_mapCharacterRow()` (around line 205) to include:
```dart
defaultScriptName: row.defaultScriptName,
```

Update `_insertCharacter()` (around line 170) to include:
```dart
defaultScriptName: Value(character.defaultScriptName),
```

Add new method (note: `AccountRepositoryImpl` is not a `DatabaseAccessor` — access DB via `_db`):
```dart
@override
Future<void> updateCharacterDefaultScript(
  int characterId,
  String? scriptName,
) async {
  await (_db.update(_db.charactersTable)
        ..where((t) => t.id.equals(characterId)))
      .write(CharactersTableCompanion(
    defaultScriptName: Value(scriptName),
    lastUpdated: Value(DateTime.now()),
  ));
}
```

- [ ] **Step 3: Update Character presentation model**

In `lib/feature/Status/data/character_model.dart`, add `defaultScriptName` field:

```dart
final String? defaultScriptName;
```

Update constructor, factory, and any mapping methods.

- [ ] **Step 4: Update StatusController mapping**

In `lib/feature/Status/controller/status_controller.dart`, update `getAccountsData()` (around line 87) to pass `defaultScriptName` through when mapping `CharacterEntity` to the `Character` presentation model.

Add method:
```dart
Future<void> updateDefaultScript(int characterId, String scriptName) async {
  await _accountRepository.updateCharacterDefaultScript(characterId, scriptName);
  await getAccountsData();
}
```

- [ ] **Step 5: Update existing account repository tests**

In `test/data/repositories/account_repository_impl_test.dart`, update entity construction to include `defaultScriptName: null`.

- [ ] **Step 6: Run tests**

Run: `flutter test test/data/repositories/account_repository_impl_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/account_repository.dart lib/data/repositories/account_repository_impl.dart lib/feature/Status/data/character_model.dart lib/feature/Status/controller/status_controller.dart test/data/repositories/account_repository_impl_test.dart
git commit -m "feat(repo): add defaultScriptName to account repository and character model"
```

---

### Task 5: Update Services (abuseConfidence → recentAbuse, ipScore → fraudScore)

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_scoring_controller.dart`
- Modify: `lib/config/services/proxy/proxy_auto_rotation_service.dart`
- Modify: `lib/config/services/proxy/proxy_sync_service.dart`
- Test: Update `test/feature/proxy/controller/proxy_scoring_controller_test.dart`
- Test: Update `test/config/services/proxy_auto_rotation_service_test.dart`
- Test: Update `test/config/services/proxy_sync_service_test.dart`

- [ ] **Step 1: Update ProxyScoringController.scoreIpWithIpqs()**

In `lib/feature/proxy/controller/proxy_scoring_controller.dart`, update the `copyWith` block (around lines 140-152):

Replace:
```dart
abuseConfidence: result.recentAbuse ? 100 : 0,
```
With:
```dart
recentAbuse: result.recentAbuse,
isCrawler: result.isCrawler,
connectionType: result.connectionType,
isp: result.isp,
organization: result.organization,
region: result.region,
```

- [ ] **Step 2: Rename `averageIpScore` → `averageFraudScore` and update `_recalculateStats()`**

In `_recalculateStats()` (lines 87-105):
- Change `if (ip.ipScore < 50) lowCount++` to `if (ip.fraudScore > 60) lowCount++`
- Rename observable: `final averageFraudScore = 0.0.obs;` (was `averageIpScore`)
- Calculate average from `fraudScore` instead of `ipScore`

**Search for all `averageIpScore` references and update them.** Known consumers:
- `lib/feature/proxy/views/sections/proxy_list_section.dart` (stats display)
- `test/feature/proxy/controller/proxy_scoring_controller_test.dart`

- [ ] **Step 3: Update getLowScoreSlotDetails() and ScoredIpResult usage**

Change threshold from `ip.ipScore < 50` to `ip.fraudScore > 60`.
Update format string to show fraud score.

Also update `scoreAllCurrentIps()` (around lines 233-243): the `ScoredIpResult` constructed there uses `score: currentIp.ipScore`. Change to `score: currentIp.fraudScore`. The auto-rotation threshold comparison in `_processResults()` already uses `score < threshold`, so update it to `score > threshold` (since higher fraud score = worse). The `autoRotationThreshold` config value semantics flip: it now represents the fraud score above which rotation triggers (e.g., 60 instead of 50).

**Important:** Also update the default value for `autoRotationThreshold` in `AppConfigService`. The old default was 50 (normalized score below which rotation triggers). The new default should be 60 (fraud score above which rotation triggers). Check `app_config_service.dart` for the default constant and update it. Users who already have a stored threshold of 50 will get equivalent behavior since the comparison operator also flips.

- [ ] **Step 4: Update ProxyAutoRotationService**

In `lib/config/services/proxy/proxy_auto_rotation_service.dart`:

Line 128 — replace:
```dart
abuseConfidence: scoreResult.recentAbuse ? 100 : 0,
```
With:
```dart
recentAbuse: scoreResult.recentAbuse,
isCrawler: scoreResult.isCrawler,
connectionType: scoreResult.connectionType,
isp: scoreResult.isp,
organization: scoreResult.organization,
region: scoreResult.region,
```

Lines 63-66 — invert threshold comparison:
```dart
// Was: r.score < threshold (where score was inverted ipScore)
// Now: r.score > threshold (where score is raw fraudScore, higher = worse)
```

Line 122 — remove `ProxyIpAddressEntity.getScoreLevel(newScore)` usage, use `getFraudScoreLabel()` if needed.

- [ ] **Step 5: Update ProxySyncService**

In `lib/config/services/proxy/proxy_sync_service.dart`:
- Line 130: Replace `abuseConfidence: 0` with `recentAbuse: false`
- Line 211: Same replacement

- [ ] **Step 6: Update all test files**

Update entity construction in:
- `test/feature/proxy/controller/proxy_scoring_controller_test.dart`
- `test/config/services/proxy_auto_rotation_service_test.dart`
- `test/config/services/proxy_sync_service_test.dart`

Replace `abuseConfidence: <value>` with `recentAbuse: <bool>` in all test entity factories and assertions.

- [ ] **Step 7: Run all tests**

Run: `flutter test test/`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add lib/feature/proxy/controller/proxy_scoring_controller.dart lib/config/services/proxy/ test/
git commit -m "refactor: migrate abuseConfidence→recentAbuse, ipScore→fraudScore in services"
```

---

### Task 6: Delete Legacy Model + Migrate Proxy UI ipScore References

**Files:**
- Delete: `lib/feature/proxy/data/proxy_ip_address_model.dart`
- Modify: `lib/feature/proxy/views/components/slot_header.dart`
- Modify: `lib/feature/proxy/views/components/proxy_slot_card_header.dart`
- Modify: `lib/feature/proxy/views/components/ip_history_list.dart`
- Modify: `lib/feature/proxy/views/components/replace_proxy_button.dart`
- Modify: `lib/feature/proxy/views/dialogs/replace_proxy_dialog.dart`
- Modify: `lib/feature/proxy/views/components/ip_score_indicator.dart`
- Modify: `lib/feature/proxy/controller/proxy_controller.dart`

- [ ] **Step 1: Delete legacy model**

Delete `lib/feature/proxy/data/proxy_ip_address_model.dart`. Search for any imports of this file and remove them.

- [ ] **Step 2: Update ip_score_indicator.dart**

Change `getScoreColor` helper to use `fraudScore` (lower = better, invert the color logic):
- fraudScore 0-30 → green (excellent)
- fraudScore 31-60 → yellow (fair)
- fraudScore 61-80 → orange (poor)
- fraudScore 81-100 → red (bad)

- [ ] **Step 3: Update slot_header.dart**

Replace `ipScore < 50` condition (for showing replace button) with `fraudScore > 60`.

- [ ] **Step 4: Update proxy_slot_card_header.dart**

Replace score badge display from `ipScore` to `fraudScore`. Update color logic to match new ranges.

- [ ] **Step 5: Update ip_history_list.dart**

Replace `ipScore` display with `fraudScore` in history rows. Use updated `getScoreColor` helper.

- [ ] **Step 6: Update replace_proxy_button.dart**

Change visibility condition from `ip.ipScore <= 0 || ip.ipScore >= 50` to show when `ip.fraudScore > 60 && ip.hasBeenScored`.

- [ ] **Step 7: Update replace_proxy_dialog.dart**

Update any score display/threshold references from `ipScore` to `fraudScore`.

- [ ] **Step 8: Update proxy_controller.dart sort comparator**

Line 259-264: Change sort from `ipScore` descending to `fraudScore` ascending (lower fraud = better, should be first):
```dart
list.sort((a, b) {
  final scoreA = ipA?.fraudScore ?? 100;
  final scoreB = ipB?.fraudScore ?? 100;
  return scoreA.compareTo(scoreB);
});
```

- [ ] **Step 9: Run all tests**

Run: `flutter test test/`
Expected: All PASS

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "refactor: delete legacy proxy model, migrate all ipScore→fraudScore in proxy UI"
```

---

## Chunk 2: Shared UI Patterns

### Task 7: Toast Notification System

**Files:**
- Create: `lib/core/widgets/toast_data.dart` (shared model — decouples widgets from service)
- Modify: `lib/config/services/notification_service.dart`
- Create: `lib/core/widgets/toast_overlay.dart`
- Create: `lib/core/widgets/toast_card.dart`
- Modify: `lib/feature/app.dart`
- Test: `test/config/services/notification_service_test.dart` (update)

- [ ] **Step 1a: Create shared toast data model**

Create `lib/core/widgets/toast_data.dart` (this avoids coupling the widget layer to the service layer):

```dart
enum ToastSeverity { success, info, warning, error }

class ToastData {
  final String title;
  final String? subtitle;
  final ToastSeverity severity;
  final DateTime timestamp;

  ToastData({
    required this.title,
    this.subtitle,
    required this.severity,
  }) : timestamp = DateTime.now();
}
```

- [ ] **Step 1b: Add toast stream to NotificationService**

In `lib/config/services/notification_service.dart`, import the shared model and add stream:

```dart
import 'dart:async';
import 'package:command_center/core/widgets/toast_data.dart';
```

Add to the service class:

```dart
final _toastController = StreamController<ToastData>.broadcast();
Stream<ToastData> get toastStream => _toastController.stream;

Future<void> showToast({
  required String title,
  String? subtitle,
  required ToastSeverity severity,
}) async {
  _toastController.add(ToastData(
    title: title,
    subtitle: subtitle,
    severity: severity,
  ));

  // Persist error/warning toasts as notifications
  if (severity == ToastSeverity.error ||
      severity == ToastSeverity.warning) {
    await createNotification(
      type: NotificationType.system,
      severity: severity == ToastSeverity.error
          ? NotificationSeverity.error
          : NotificationSeverity.warning,
      title: title,
      message: subtitle ?? '',
    );
  }
}
```

**Note on StreamController lifecycle:** `NotificationService` is a permanent `GetxService` (registered with `permanent: true`). Its `onClose()` is never called by GetX. The broadcast StreamController will be reclaimed by the OS on app exit. Do NOT add an `onClose()` override — it would be dead code. If explicit cleanup is ever needed, call `dispose()` from `App.onWindowClose()` instead.

- [ ] **Step 2: Create ToastCard widget**

Create `lib/core/widgets/toast_card.dart`:

```dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:command_center/core/widgets/toast_data.dart';

class ToastCard extends StatelessWidget {
  final ToastData toast;
  final VoidCallback onDismiss;

  const ToastCard({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final colors = _severityColors(theme);

    return Container(
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(colors.icon, color: colors.foreground, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toast.title,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (toast.subtitle != null)
                  Text(
                    toast.subtitle!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 12),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  _SeverityColors _severityColors(FluentThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return switch (toast.severity) {
      ToastSeverity.success => _SeverityColors(
          background: isDark ? const Color(0xFF1e3a1e) : const Color(0xFFe8f5e9),
          border: isDark ? const Color(0xFF2d5a2d) : const Color(0xFF81c784),
          foreground: isDark ? const Color(0xFF4ade80) : const Color(0xFF2e7d32),
          icon: FluentIcons.completed,
        ),
      ToastSeverity.error => _SeverityColors(
          background: isDark ? const Color(0xFF3a1e1e) : const Color(0xFFffebee),
          border: isDark ? const Color(0xFF5a2d2d) : const Color(0xFFe57373),
          foreground: isDark ? const Color(0xFFf87171) : const Color(0xFFc62828),
          icon: FluentIcons.error_badge,
        ),
      ToastSeverity.warning => _SeverityColors(
          background: isDark ? const Color(0xFF3a2d1e) : const Color(0xFFFFF8E1),
          border: isDark ? const Color(0xFF5a4a2d) : const Color(0xFFFFD54F),
          foreground: isDark ? const Color(0xFFfbbf24) : const Color(0xFFf57f17),
          icon: FluentIcons.warning,
        ),
      ToastSeverity.info => _SeverityColors(
          background: isDark ? const Color(0xFF1e2d3a) : const Color(0xFFE3F2FD),
          border: isDark ? const Color(0xFF2d4a5a) : const Color(0xFF64B5F6),
          foreground: isDark ? const Color(0xFF60a5fa) : const Color(0xFF1565C0),
          icon: FluentIcons.info,
        ),
    };
  }
}

class _SeverityColors {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const _SeverityColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });
}
```

- [ ] **Step 3: Create ToastOverlay widget**

Create `lib/core/widgets/toast_overlay.dart`:

```dart
import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/core/widgets/toast_card.dart';
import 'package:command_center/core/widgets/toast_data.dart';

class ToastOverlay extends StatefulWidget {
  final Widget child;

  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  final List<_ActiveToast> _toasts = [];
  StreamSubscription<ToastData>? _subscription;

  @override
  void initState() {
    super.initState();
    final service = Get.find<NotificationService>();
    _subscription = service.toastStream.listen(_onToast);
  }

  void _onToast(ToastData toast) {
    final active = _ActiveToast(toast: toast);
    setState(() => _toasts.add(active));

    // Auto-dismiss non-errors after 5s
    if (toast.severity != ToastSeverity.error) {
      Future.delayed(const Duration(seconds: 5), () {
        _dismiss(active);
      });
    }
  }

  void _dismiss(_ActiveToast active) {
    if (mounted && _toasts.contains(active)) {
      setState(() => _toasts.remove(active));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _toasts.reversed
                .take(5)
                .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ToastCard(
                        toast: t.toast,
                        onDismiss: () => _dismiss(t),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ActiveToast {
  final ToastData toast;
  _ActiveToast({required this.toast});
}
```

- [ ] **Step 4: Wire ToastOverlay into app.dart**

In `lib/feature/app.dart`, wrap the content area. Find the `Expanded` widget (around line 198) which currently reads:

```dart
Expanded(
  child: _initialized
      ? _buildMainContent(isDark)
      : _buildLoadingScreen(),
),
```

Wrap only the initialized path with `ToastOverlay`:

```dart
Expanded(
  child: _initialized
      ? ToastOverlay(child: _buildMainContent(isDark))
      : _buildLoadingScreen(),
),
```

Add import: `import 'package:command_center/core/widgets/toast_overlay.dart';`

- [ ] **Step 5: Run app to verify compilation**

Run: `flutter run -d windows`
Expected: App compiles and launches. No visual changes yet (no toasts being triggered).

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/toast_data.dart lib/config/services/notification_service.dart lib/core/widgets/toast_overlay.dart lib/core/widgets/toast_card.dart lib/feature/app.dart
git commit -m "feat: add toast notification system (ToastOverlay + ToastCard)"
```

---

### Task 8: LoadingButton Widget

**Files:**
- Create: `lib/core/widgets/loading_button.dart`
- Test: `test/core/widgets/loading_button_test.dart`

- [ ] **Step 1: Write widget test**

Create `test/core/widgets/loading_button_test.dart`:

```dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/widgets/loading_button.dart';

void main() {
  group('LoadingButton', () {
    testWidgets('shows label in idle state', (tester) async {
      await tester.pumpWidget(
        FluentApp(
          home: LoadingButton(
            label: 'Score IP',
            onPressed: () async {},
          ),
        ),
      );
      expect(find.text('Score IP'), findsOneWidget);
    });

    testWidgets('shows loading text when pressed', (tester) async {
      await tester.pumpWidget(
        FluentApp(
          home: LoadingButton(
            label: 'Score IP',
            loadingLabel: 'Scoring...',
            onPressed: () async {
              await Future.delayed(const Duration(seconds: 2));
            },
          ),
        ),
      );

      await tester.tap(find.text('Score IP'));
      await tester.pump();
      expect(find.text('Scoring...'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/loading_button_test.dart`
Expected: FAIL — LoadingButton doesn't exist.

- [ ] **Step 3: Create LoadingButton widget**

Create `lib/core/widgets/loading_button.dart`:

```dart
import 'package:fluent_ui/fluent_ui.dart';

enum LoadingButtonStyle { filled, outline }

class LoadingButton extends StatefulWidget {
  final String label;
  final String? loadingLabel;
  final String? successLabel;
  final Future<void> Function()? onPressed;
  final LoadingButtonStyle style;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.label,
    this.loadingLabel,
    this.successLabel,
    this.onPressed,
    this.style = LoadingButtonStyle.filled,
    this.icon,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

enum _ButtonState { idle, loading, success, error }

class _LoadingButtonState extends State<LoadingButton> {
  _ButtonState _state = _ButtonState.idle;

  Future<void> _handlePress() async {
    if (_state == _ButtonState.loading || widget.onPressed == null) return;

    setState(() => _state = _ButtonState.loading);
    try {
      await widget.onPressed!();
      if (!mounted) return;
      setState(() => _state = _ButtonState.success);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _state = _ButtonState.idle);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _ButtonState.error);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _state = _ButtonState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_state == _ButtonState.loading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: ProgressRing(strokeWidth: 2),
            ),
          )
        else if (_state == _ButtonState.success)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(FluentIcons.completed, size: 14),
          )
        else if (widget.icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(widget.icon, size: 14),
          ),
        Text(_currentLabel),
      ],
    );

    final onPressed =
        _state == _ButtonState.loading ? null : _handlePress;

    return widget.style == LoadingButtonStyle.filled
        ? FilledButton(onPressed: onPressed, child: child)
        : Button(onPressed: onPressed, child: child);
  }

  String get _currentLabel => switch (_state) {
        _ButtonState.loading =>
          widget.loadingLabel ?? widget.label,
        _ButtonState.success =>
          widget.successLabel ?? 'Done',
        _ButtonState.error => 'Failed',
        _ => widget.label,
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/loading_button_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/loading_button.dart test/core/widgets/
git commit -m "feat: add LoadingButton widget with loading/success/error states"
```

---

### Task 9: SelectionToolbar Widget

**Files:**
- Create: `lib/core/widgets/selection_toolbar.dart`

- [ ] **Step 1: Create SelectionToolbar**

Create `lib/core/widgets/selection_toolbar.dart`:

```dart
import 'package:fluent_ui/fluent_ui.dart';

class SelectionAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const SelectionAction({
    required this.label,
    this.icon,
    required this.onPressed,
  });
}

class SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final List<SelectionAction> actions;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final bool allSelected;

  const SelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.actions,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.allSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).accentColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Checkbox(
            checked: allSelected,
            onChanged: (_) =>
                allSelected ? onClearSelection() : onSelectAll(),
          ),
          const SizedBox(width: 8),
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(width: 16),
          ...actions.map((action) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Button(
                  onPressed: action.onPressed,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      Colors.white.withValues(alpha: 0.15),
                    ),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (action.icon != null) ...[
                        Icon(action.icon, size: 12, color: Colors.white),
                        const SizedBox(width: 6),
                      ],
                      Text(action.label),
                    ],
                  ),
                ),
              )),
          const Spacer(),
          HyperlinkButton(
            onPressed: onClearSelection,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                Colors.white.withValues(alpha: 0.6),
              ),
            ),
            child: const Text('Clear selection'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/selection_toolbar.dart
git commit -m "feat: add SelectionToolbar widget for multi-select tables"
```

---

### Task 10: CollapsibleSection Widget

**Files:**
- Create: `lib/core/widgets/collapsible_section.dart`

- [ ] **Step 1: Create CollapsibleSection**

Create `lib/core/widgets/collapsible_section.dart`:

```dart
import 'package:fluent_ui/fluent_ui.dart';

class CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget? badge;
  final Widget content;
  final bool initiallyExpanded;

  const CollapsibleSection({
    super.key,
    required this.title,
    this.badge,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: _expanded
                    ? Border(
                        bottom: BorderSide(
                          color: theme.resources.dividerStrokeColorDefault,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? FluentIcons.chevron_down
                        : FluentIcons.chevron_right,
                    size: 10,
                    color: theme.resources.textFillColorSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: theme.typography.bodyStrong,
                  ),
                  const Spacer(),
                  if (widget.badge != null) widget.badge!,
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: widget.content,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/collapsible_section.dart
git commit -m "feat: add CollapsibleSection widget with animated expand/collapse"
```

---

## Chunk 3: Proxy Detail Pane Redesign

> **Prerequisite:** Chunk 1 (Tasks 1-6) must be fully complete and Drift code generation re-run before starting this chunk. Tasks 11-12 reference entity fields (`isCrawler`, `recentAbuse`, `region`, `connectionType`, `isp`, `organization`, `getFraudScoreLabel()`) that are added in Chunk 1.

### Task 11: Create FraudAnalysis Widget (replaces 4 old components)

**Files:**
- Create: `lib/feature/proxy/views/components/fraud_analysis.dart`
- Delete: `lib/feature/proxy/views/components/ip_score_analysis.dart`
- Delete: `lib/feature/proxy/views/components/score_summary.dart`
- Delete: `lib/feature/proxy/views/components/score_detail_table.dart`
- Delete: `lib/feature/proxy/views/components/score_flags.dart`

- [ ] **Step 1: Create fraud_analysis.dart**

Create `lib/feature/proxy/views/components/fraud_analysis.dart`:

```dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:command_center/core/widgets/loading_button.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';

class FraudAnalysis extends StatelessWidget {
  final ProxyIpAddressEntity ip;
  final Future<void> Function() onRefreshScore;
  final Future<void> Function() onScoreIp;

  const FraudAnalysis({
    super.key,
    required this.ip,
    required this.onRefreshScore,
    required this.onScoreIp,
  });

  @override
  Widget build(BuildContext context) {
    if (!ip.hasBeenScored) return _buildNotScored(context);
    return _buildScored(context);
  }

  Widget _buildNotScored(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
                width: 3,
              ),
            ),
            child: Center(
              child: Text('?',
                  style: theme.typography.title?.copyWith(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Not Scored Yet', style: theme.typography.bodyStrong),
          const SizedBox(height: 4),
          Text(
            'Run an IPQS fraud check to analyze this IP',
            style: theme.typography.caption,
          ),
          const SizedBox(height: 12),
          LoadingButton(
            label: 'Score IP',
            loadingLabel: 'Scoring...',
            successLabel: 'Scored',
            onPressed: onScoreIp,
          ),
        ],
      ),
    );
  }

  Widget _buildScored(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFraudCircle(theme),
            const SizedBox(width: 20),
            Expanded(child: _buildFlags(theme)),
          ],
        ),
        const SizedBox(height: 14),
        Divider(
          style: DividerThemeData(
            horizontalMargin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Last checked: ${_formatDate(ip.lastScoreCheck)}',
              style: theme.typography.caption,
            ),
            LoadingButton(
              label: 'Refresh Score',
              loadingLabel: 'Refreshing...',
              successLabel: 'Refreshed',
              style: LoadingButtonStyle.outline,
              onPressed: onRefreshScore,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFraudCircle(FluentThemeData theme) {
    final color = _fraudScoreColor(ip.fraudScore);
    final label = ProxyIpAddressEntity.getFraudScoreLabel(ip.fraudScore);

    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ip.fraudScore.round().toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'FRAUD RISK',
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '0 = clean, 100 = fraud',
          style: TextStyle(
            fontSize: 9,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFlags(FluentThemeData theme) {
    final flags = [
      _Flag('VPN', ip.isVpn),
      _Flag('Proxy', ip.isProxy),
      _Flag('Tor', ip.isTor),
      _Flag('Datacenter', ip.isDatacenter),
      _Flag('Crawler', ip.isCrawler ?? false),
      _Flag('Recent Abuse', ip.recentAbuse ?? false),
    ];

    // Sort detected flags first
    flags.sort((a, b) {
      if (a.detected == b.detected) return 0;
      return a.detected ? -1 : 1;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETECTION FLAGS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: flags.map((f) => _buildFlagChip(f, theme)).toList(),
        ),
      ],
    );
  }

  Widget _buildFlagChip(_Flag flag, FluentThemeData theme) {
    if (flag.detected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFf87171).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFFf87171).withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.status_error_full,
                size: 12, color: Color(0xFFf87171)),
            const SizedBox(width: 6),
            Text(
              '${flag.name} Detected',
              style: const TextStyle(
                color: Color(0xFFf87171),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.completed,
              size: 12, color: Color(0xFF4ade80)),
          const SizedBox(width: 6),
          Text(
            'Not ${flag.name}',
            style: TextStyle(
              color: theme.resources.textFillColorPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _fraudScoreColor(double score) {
    if (score <= 30) return const Color(0xFF4ade80);
    if (score <= 60) return const Color(0xFFfbbf24);
    if (score <= 80) return const Color(0xFFfb923c);
    return const Color(0xFFf87171);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _Flag {
  final String name;
  final bool detected;
  const _Flag(this.name, this.detected);
}
```

- [ ] **Step 2: Delete old score components**

Delete these 4 files:
- `lib/feature/proxy/views/components/ip_score_analysis.dart`
- `lib/feature/proxy/views/components/score_summary.dart`
- `lib/feature/proxy/views/components/score_detail_table.dart`
- `lib/feature/proxy/views/components/score_flags.dart`

Update imports in `proxy_detail_section.dart` to use `FraudAnalysis` instead.

**Note:** The existing `IpScoreAnalysis` takes `VoidCallback onRefreshScore` (sync). The new `FraudAnalysis` takes `Future<void> Function()` callbacks (async, needed for `LoadingButton`). When updating `proxy_detail_section.dart`, also change the callback type from `void Function(ProxyIpAddressEntity)` to `Future<void> Function(ProxyIpAddressEntity)`, and propagate the change to the call site in `proxy_screen.dart`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: create FraudAnalysis widget, delete 4 old score components"
```

---

### Task 12: Merge Connection Info into Slot Header + Collapsible Detail Pane

**Files:**
- Delete: `lib/feature/proxy/views/components/current_ip_card.dart`
- Modify: `lib/feature/proxy/views/components/slot_header.dart`
- Create: `lib/feature/proxy/views/components/linked_characters_section.dart`
- Modify: `lib/feature/proxy/views/sections/proxy_detail_section.dart`

- [ ] **Step 1: Update slot_header.dart — merge connection info inline**

Add a row of compact badges below the slot name/IP row in `slot_header.dart`:
- Location: `${ip.cityName}, ${ip.region ?? ''}, ${ip.countryCode}` (use new region field)
- ISP: `ip.isp ?? ip.asnName` (fallback to old ASN name)
- Connection type: color-coded pill badge
- Assigned age: relative time from `ip.assignedAt`

Add low-score warning bar when `ip.fraudScore > 60`:
- Red left border on the entire card
- Warning InfoBar inside the card

Delete `lib/feature/proxy/views/components/current_ip_card.dart`.

- [ ] **Step 2: Create LinkedCharactersSection**

Create `lib/feature/proxy/views/components/linked_characters_section.dart`:

A simple widget that takes a `List<CharacterEntity>` and displays each character's name, status (from WatchdogService), and default script. Each row is clickable (calls `onNavigateToCharacter` callback).

- [ ] **Step 3: Rewrite proxy_detail_section.dart with collapsible layout**

Replace the current `SingleChildScrollView > Column` layout with:

```
Column
  ├─ SlotHeader (always visible, merged with connection info)
  ├─ CollapsibleSection("Fraud Analysis", badge: score badge, expanded: true)
  │   └─ FraudAnalysis widget
  ├─ CollapsibleSection("IP History", badge: "N rotations · Avg: X", expanded: false)
  │   └─ IpHistoryList widget
  └─ CollapsibleSection("Linked Characters", badge: "N characters", expanded: false)
      └─ LinkedCharactersSection widget
```

Remove import of `current_ip_card.dart`. Update imports to use `CollapsibleSection` and `FraudAnalysis`.

- [ ] **Step 4: Run app to verify proxy detail pane**

Run: `flutter run -d windows`
Navigate to Proxies tab, select a slot. Verify:
- Slot header shows connection info badges
- Fraud Analysis section is expanded with circle + flags
- IP History and Linked Characters are collapsed with summary badges

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: redesign proxy detail pane — collapsible sections, merged header"
```

---

## Chunk 4: Accounts Table Redesign

### Task 13: StatusSelectionController

**Files:**
- Create: `lib/feature/Status/controller/status_selection_controller.dart`
- Modify: `lib/core/resource/dependency_injection.dart`
- Test: `test/feature/Status/controller/status_selection_controller_test.dart`

- [ ] **Step 1: Write test for selection logic**

Create `test/feature/Status/controller/status_selection_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';

void main() {
  late StatusSelectionController controller;

  setUp(() {
    controller = StatusSelectionController();
  });

  group('selection', () {
    test('toggleSelection adds and removes IDs', () {
      controller.toggleSelection(1);
      expect(controller.selectedIds, contains(1));
      controller.toggleSelection(1);
      expect(controller.selectedIds, isEmpty);
    });

    test('selectAll sets all provided IDs', () {
      controller.selectAll([1, 2, 3]);
      expect(controller.selectedIds.length, 3);
    });

    test('clearSelection empties selection', () {
      controller.selectAll([1, 2, 3]);
      controller.clearSelection();
      expect(controller.selectedIds, isEmpty);
    });

    test('isSelected returns correct state', () {
      controller.toggleSelection(1);
      expect(controller.isSelected(1), isTrue);
      expect(controller.isSelected(2), isFalse);
    });
  });

  group('filtering', () {
    test('searchQuery is observable', () {
      controller.searchQuery.value = 'test';
      expect(controller.searchQuery.value, 'test');
    });

    test('statusFilter defaults to all', () {
      expect(controller.statusFilter.value, 'all');
    });

    test('scriptFilter defaults to all', () {
      expect(controller.scriptFilter.value, 'all');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/feature/Status/controller/status_selection_controller_test.dart`
Expected: FAIL

- [ ] **Step 3: Create StatusSelectionController**

Create `lib/feature/Status/controller/status_selection_controller.dart`:

```dart
import 'package:get/get.dart';

class StatusSelectionController extends GetxController {
  final selectedIds = <int>{}.obs;
  final searchQuery = ''.obs;
  final statusFilter = 'all'.obs;
  final scriptFilter = 'all'.obs;

  bool isSelected(int id) => selectedIds.contains(id);

  void toggleSelection(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectAll(List<int> ids) {
    selectedIds.addAll(ids);
  }

  void clearSelection() {
    selectedIds.clear();
  }

  bool get hasSelection => selectedIds.isNotEmpty;

  int get selectedCount => selectedIds.length;
}
```

- [ ] **Step 4: Register in DI**

In `lib/core/resource/dependency_injection.dart`, add after StatusController registration:

```dart
Get.lazyPut(() => StatusSelectionController(), fenix: true);
```

Add import.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/feature/Status/controller/status_selection_controller_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/feature/Status/controller/status_selection_controller.dart lib/core/resource/dependency_injection.dart test/feature/Status/controller/
git commit -m "feat: add StatusSelectionController for multi-select and filtering"
```

---

### Task 14: SearchFilterBar + ScriptChip + ScriptPickerFlyout

**Files:**
- Create: `lib/feature/Status/views/components/search_filter_bar.dart`
- Create: `lib/feature/Status/views/components/script_chip.dart`
- Create: `lib/feature/Status/views/components/script_picker_flyout.dart`

- [ ] **Step 1: Create SearchFilterBar**

Create `lib/feature/Status/views/components/search_filter_bar.dart`:

A row with:
- TextBox (search, 300px max-width, debounced 300ms via `debounce()` worker on `searchQuery`)
- ComboBox for status filter (All / Running / Stopped / Banned / Awaiting)
- ComboBox for script filter (All / list of script names from AppConfigService.scriptRegistry)
- "Showing X of Y" text aligned right

Reads/writes to `StatusSelectionController` observables.

- [ ] **Step 2: Create ScriptChip**

Create `lib/feature/Status/views/components/script_chip.dart`:

A `StatelessWidget` that shows:
- If `scriptName != null`: blue chip with gear icon + script name, clickable
- If `scriptName == null && hasCharacter`: dashed yellow "+ Assign script" chip
- If `banned`: script name with strikethrough
- If no character: plain "—" text

`onTap` callback opens ScriptPickerFlyout.

- [ ] **Step 3: Create ScriptPickerFlyout**

Create `lib/feature/Status/views/components/script_picker_flyout.dart`:

Wraps the existing `ScriptSelector` widget inside a `Flyout`. When a script is selected, calls `onScriptSelected(String scriptName)` callback and closes the flyout.

- [ ] **Step 4: Commit**

```bash
git add lib/feature/Status/views/components/search_filter_bar.dart lib/feature/Status/views/components/script_chip.dart lib/feature/Status/views/components/script_picker_flyout.dart
git commit -m "feat: add SearchFilterBar, ScriptChip, ScriptPickerFlyout for accounts table"
```

---

### Task 15: BulkStartConfirmationDialog

**Files:**
- Create: `lib/feature/Status/views/dialogs/bulk_start_confirmation_dialog.dart`

- [ ] **Step 1: Create dialog**

Create `lib/feature/Status/views/dialogs/bulk_start_confirmation_dialog.dart`:

A `ContentDialog` that:
- Shows: "X of Y characters have no script assigned. Start the Z that do?"
- Two actions: "Start Z" (FilledButton) and "Cancel" (Button)
- Returns `true` via `Navigator.pop(context, true)` on confirm, `false` on cancel

Constructor params: `int withScripts`, `int withoutScripts`.

- [ ] **Step 2: Commit**

```bash
git add lib/feature/Status/views/dialogs/
git commit -m "feat: add BulkStartConfirmationDialog for missing-script confirmation"
```

---

### Task 16: Rewrite Account List Section + Status Screen Integration

**Files:**
- Modify: `lib/feature/Status/views/sections/account_list_section.dart`
- Modify: `lib/feature/Status/views/components/bot_farm_summary_bar.dart`
- Modify: `lib/feature/Status/views/status_screen.dart`
- Modify: `lib/feature/Status/controller/status_controller.dart`

- [ ] **Step 1: Update StatusController with bulk start logic**

In `lib/feature/Status/controller/status_controller.dart`:

Note: `updateDefaultScript()` was already added in Task 4.5 Step 4.

Add a return type for bulk launch readiness check:

```dart
/// Returns (withScripts, withoutScripts) counts for the given character IDs.
/// If characterIds is null, checks all characters.
({int withScripts, int withoutScripts}) getBulkLaunchReadiness([
  Set<int>? characterIds,
]) {
  // filter accountList to get relevant characters
  // count those with/without defaultScriptName
}

/// Launches characters that have default scripts assigned.
/// Returns the number successfully started.
Future<int> launchWithDefaultScripts([Set<int>? characterIds]) async {
  // get characters with defaultScriptName != null
  // for each, build a LaunchConfig from character.defaultScriptName
  // pass it to the existing launchCharacter(account, character, config)
  // show toast per character
  // return count
}
```

**Do NOT modify `launchCharacter()`'s existing signature.** Instead, `launchWithDefaultScripts()` should construct a `LaunchConfig` from the character's `defaultScriptName` and call the existing `launchCharacter(account, character, config)`. This avoids breaking existing callers.

- [ ] **Step 2: Rewrite account_list_section.dart table columns**

In `lib/feature/Status/views/sections/account_list_section.dart` (currently at 300 lines — the ceiling):

**First, extract existing cell builders** into `lib/feature/Status/views/components/account_table_cells.dart` before adding new features. This reduces the section file enough to add the new columns.

Then replace the 7-column layout with 8 columns (checkbox + Account + Credentials + Character + Script + Proxy + Status + Actions).

The extracted `account_table_cells.dart` should contain:
- `CredentialsCell` — email + password stacked with copy icons
- `ProxyCell` — slot name + country code display
- `ActionsCell` — contextual action buttons (start/stop/delete)

The section file focuses on: column layout, header row, filter logic, row builder, banned row tinting.

**Filter logic:** Read `StatusSelectionController.searchQuery`, `statusFilter`, `scriptFilter` to filter displayed rows. Apply predicate before building list.

**Banned row tinting:** `if (character.banned)` apply subtle red background.

- [ ] **Step 3: Update bot_farm_summary_bar.dart with LoadingButton**

Replace `FilledButton("Start All")` with `LoadingButton(label: "Start All", loadingLabel: "Starting...", ...)`.
Same for "Stop All".

- [ ] **Step 4: Update status_screen.dart with SearchFilterBar + SelectionToolbar + BulkStart flow**

Add `SearchFilterBar` between the PageHeader and the table.

Add conditional rendering: `Obx(() => selectionController.hasSelection ? SelectionToolbar(...) : BotFarmSummaryBar(...))`.

Wire "Start Selected" in SelectionToolbar to the bulk launch flow:
```dart
onStartSelected: () async {
  final readiness = statusController.getBulkLaunchReadiness(
    selectionController.selectedIds.toSet(),
  );
  if (readiness.withoutScripts > 0) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => BulkStartConfirmationDialog(
        withScripts: readiness.withScripts,
        withoutScripts: readiness.withoutScripts,
      ),
    );
    if (confirmed != true) return;
  }
  await statusController.launchWithDefaultScripts(
    selectionController.selectedIds.toSet(),
  );
}
```

Wire "Start All" in BotFarmSummaryBar with same pattern but passing `null` for all characters.

- [ ] **Step 5: Run app to verify accounts table**

Run: `flutter run -d windows`
Navigate to Accounts tab. Verify:
- Search and filter bar visible
- Merged credentials column
- Script chips visible (or "+ Assign script" for unassigned)
- Checkbox column works
- Selection toolbar appears on selection
- Banned rows have red tint

- [ ] **Step 6: Commit**

```bash
git add lib/feature/Status/
git commit -m "feat: redesign accounts table — search, filter, multi-select, script column"
```

---

## Chunk 5: Dashboard Redesign

### Task 17: MainMenuController Overhaul

**Files:**
- Modify: `lib/feature/main_menu/controller/main_menu_controller.dart`

- [ ] **Step 1: Add observable state to MainMenuController**

Rewrite `lib/feature/main_menu/controller/main_menu_controller.dart` to expose:

```dart
class MainMenuController extends GetxController {
  // Follow codebase defensive pattern: nullable + try-catch (matches status_controller.dart)
  StatusController? _statusController;
  ProxyController? _proxyController;
  ProxyScoringController? _scoringController;
  WatchdogService? _watchdogService;

  // Bot status data
  RxList<BotTileData> get botTiles => _botTiles;
  final _botTiles = <BotTileData>[].obs;

  // Proxy health data
  Rx<ProxyHealthData> get proxyHealth => _proxyHealth;
  final _proxyHealth = ProxyHealthData.empty().obs;

  // Quick action loading states
  final isScoringAll = false.obs;
  final isSyncing = false.obs;

  @override
  void onInit() {
    super.onInit();
    try {
      _statusController = Get.find<StatusController>();
      _proxyController = Get.find<ProxyController>();
      _scoringController = Get.find<ProxyScoringController>();
      _watchdogService = Get.find<WatchdogService>();
    } catch (e) {
      // Dependencies may not be registered yet during startup
    }
    _refreshData();
    // Re-compute when tracked clients change
    if (_watchdogService != null) {
      ever(_watchdogService!.trackedClients, (_) => _refreshBotTiles());
    }
  }

  void _refreshData() {
    _refreshBotTiles();
    _refreshProxyHealth();
  }

  // ... tile/health computation methods — use null-aware access on controllers
}
```

Define data classes in `lib/feature/main_menu/data/`:

`bot_tile_data.dart`:
```dart
class BotTileData {
  final int characterId;
  final String characterName;
  final String? defaultScriptName;
  final String? proxySlotName;
  final String? countryCode;
  final String status; // running, stopped, restarting, banned
  final Duration? uptime; // null if not running or unknown
}
```

`proxy_health_data.dart`:
```dart
class ProxyHealthData {
  final int excellentCount; // fraudScore 0-30
  final int fairCount;      // fraudScore 31-60
  final int poorCount;      // fraudScore 61-80
  final int badCount;       // fraudScore 81-100
  final int unscoredCount;
  final List<ProxyAttentionItem> attentionItems;

  factory ProxyHealthData.empty() => ProxyHealthData(/* zeros */);
}

class ProxyAttentionItem {
  final int slotId;
  final String slotName;
  final double? fraudScore;
  final String? connectionType;
  final bool isUnscored;
}
```

Add methods to controller:

```dart
Future<void> startAll() async {
  // Delegates to StatusController.launchWithDefaultScripts()
  // Same bulk-start flow as accounts table (readiness check + dialog)
}

Future<void> stopAll() async {
  // Delegates to StatusController.stopAll()
}

Future<void> scoreAllIps() async {
  isScoringAll.value = true;
  try {
    await Get.find<ProxyScoringController>().scoreAllCurrentIps();
  } finally {
    isScoringAll.value = false;
  }
}

Future<void> syncProxies() async {
  isSyncing.value = true;
  try {
    await Get.find<ProxyController>().syncWithWebshare();
  } finally {
    isSyncing.value = false;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/main_menu/controller/
git commit -m "feat: overhaul MainMenuController with bot status and proxy health state"
```

---

### Task 18: Dashboard UI Components

**Files:**
- Create: `lib/feature/main_menu/views/components/bot_status_tile.dart`
- Create: `lib/feature/main_menu/views/sections/bot_status_grid_section.dart`
- Create: `lib/feature/main_menu/views/sections/proxy_health_overview_section.dart`
- Create: `lib/feature/main_menu/views/sections/quick_actions_section.dart`
- Delete: `lib/feature/main_menu/views/sections/system_overview_section.dart`
- Delete: `lib/feature/main_menu/views/sections/characters_status_section.dart`
- Delete: `lib/feature/main_menu/views/sections/recent_activity_section.dart`

- [ ] **Step 1: Create BotStatusTile**

Create `lib/feature/main_menu/views/components/bot_status_tile.dart`:

A card widget showing:
- Character name (bold), default script name, proxy slot + country, uptime
- Color-coded left border based on status
- Clickable (calls `onTap` callback)

- [ ] **Step 2: Create BotStatusGrid section**

Create `lib/feature/main_menu/views/sections/bot_status_grid_section.dart`:

- Header row: "Bot Farm Status" + status count badges + Start All / Stop All (LoadingButton)
- Responsive `Wrap` or `GridView` of `BotStatusTile` widgets
- Reads from `MainMenuController.botTiles`

- [ ] **Step 3: Create ProxyHealthOverview section**

Create `lib/feature/main_menu/views/sections/proxy_health_overview_section.dart`:

- Stacked health bar (Row of colored Expanded containers, proportional to counts)
- "Needs Attention" card (only if issues exist) with inline LoadingButton actions
- Hidden entirely when all proxies are healthy

- [ ] **Step 4: Create QuickActions section**

Create `lib/feature/main_menu/views/sections/quick_actions_section.dart`:

- Grid of action cards (New Character, Score All IPs, Sync Proxies, Settings)
- Each card shows icon + title + description
- Score/Sync cards use loading state from MainMenuController

- [ ] **Step 5: Do NOT delete old sections yet**

The old sections (`system_overview_section.dart`, `characters_status_section.dart`, `recent_activity_section.dart`) are still imported by `main_menu_screen.dart`. Deleting them here would break compilation before Task 19 rewrites the screen. The deletions are deferred to Task 19 where they happen atomically with the screen rewrite.

- [ ] **Step 6: Commit**

```bash
git add lib/feature/main_menu/views/components/bot_status_tile.dart lib/feature/main_menu/views/sections/bot_status_grid_section.dart lib/feature/main_menu/views/sections/proxy_health_overview_section.dart lib/feature/main_menu/views/sections/quick_actions_section.dart
git commit -m "feat: create dashboard components — BotStatusGrid, ProxyHealth, QuickActions"
```

---

### Task 19: Rewrite MainMenuScreen + Delete Old Sections

**Files:**
- Modify: `lib/feature/main_menu/views/main_menu_screen.dart`
- Delete: `lib/feature/main_menu/views/sections/system_overview_section.dart`
- Delete: `lib/feature/main_menu/views/sections/characters_status_section.dart`
- Delete: `lib/feature/main_menu/views/sections/recent_activity_section.dart`

- [ ] **Step 1: Replace screen content and delete old sections atomically**

Delete the old section files first, then rewrite the screen in the same commit:

Rewrite `lib/feature/main_menu/views/main_menu_screen.dart` to compose the new sections:

```dart
class MainMenuScreen extends GetView<MainMenuController> {
  final Function(int)? onNavigateToIndex;

  const MainMenuScreen({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Command Center')),
      children: [
        BotStatusGridSection(
          onNavigateToAccounts: () => onNavigateToIndex?.call(1),
          onStartAll: controller.startAll,
          onStopAll: controller.stopAll,
        ),
        const SizedBox(height: 16),
        ProxyHealthOverviewSection(
          onNavigateToProxies: () => onNavigateToIndex?.call(2),
        ),
        const SizedBox(height: 16),
        QuickActionsSection(
          onNavigateToIndex: onNavigateToIndex,
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Update MainMenuScreen call sites**

In `lib/feature/app.dart` (around lines 290-295), update the `MainMenuScreen()` instantiation to remove the old controller params (`statusController`, `proxyController`, `proxyScoringController`) since the new screen reads them via `Get.find()` internally. Keep only `onNavigateToIndex`.

Also update `lib/config/routes/app_routes.dart` (line 18): `MainMenuScreen()` is called with no args there. Since `onNavigateToIndex` is optional, it will still compile. However, quick action clicks would not navigate. Either pass a valid callback or remove `MainMenuScreen` from `app_routes.dart` if navigation is fully handled by `app.dart`'s `NavigationPane` (which it is).

- [ ] **Step 3: Run app to verify dashboard**

Run: `flutter run -d windows`
Navigate to Home tab. Verify:
- Bot status grid shows character tiles with color borders
- Proxy health bar shows fleet health
- Quick actions are visible and functional
- Clicking tiles navigates to Accounts tab

- [ ] **Step 4: Commit**

```bash
git rm lib/feature/main_menu/views/sections/system_overview_section.dart lib/feature/main_menu/views/sections/characters_status_section.dart lib/feature/main_menu/views/sections/recent_activity_section.dart
git add lib/feature/main_menu/ lib/feature/app.dart
git commit -m "feat: redesign dashboard — bot grid, proxy health, quick actions, delete old sections"
```

---

### Task 20: Final Integration & Cleanup

**Files:**
- Various cleanup across all modified files

- [ ] **Step 1: Run full test suite**

Run: `flutter test test/`
Expected: All tests PASS. Fix any remaining compilation errors from entity field changes.

- [ ] **Step 2: Run the app end-to-end**

Run: `flutter run -d windows`

Test each feature:
- Home: bot grid, proxy health, quick actions all functional
- Accounts: search, filter, script assignment, multi-select, bulk start/stop
- Proxies: collapsible detail pane, fraud analysis with correct flags, slot header with connection info
- Toast notifications appear on actions (score IP, replace proxy, etc.)
- LoadingButtons show correct states

- [ ] **Step 3: Verify no dead imports**

Run: `dart analyze`
Fix any warnings about unused imports from deleted files.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup — fix dead imports, resolve analyzer warnings"
```
