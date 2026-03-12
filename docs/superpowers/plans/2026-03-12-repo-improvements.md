# Repo Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden CI, standardize error handling, decompose oversized files, add tests, and polish docs/logging across the Command Center app.

**Architecture:** 5 sequential phases, each its own PR to `dev`. CI first for a safety net, then error handling contract, then file decomposition following the new patterns, then tests against the final code, then docs/polish last.

**Tech Stack:** Flutter 3.x, Dart 3.x, Fluent UI 4.13.0, GetX 4.6.5, Drift 2.22.1, logger 2.6.2, mocktail (new dev dep)

**Spec:** `docs/superpowers/specs/2026-03-12-repo-improvements-design.md`

---

## Chunk 1: Phase 1 — CI Hardening

### Task 1: Fix lint violations — replace `print()` with `logger`

**Files:**
- Modify: `lib/config/services/native_commands_service.dart:21,49,51,53`
- Modify: `lib/feature/Status/data/process_model.dart:32`
- Modify: `lib/feature/Status/controller/status_controller.dart:163`

- [ ] **Step 1: Add logger import and replace print() in native_commands_service.dart**

```dart
// Add at top:
import 'package:command_center/core/helper/logger.dart';

// Line 21: replace print('Failed to get Java processes: ${e.message}');
logger.e('Failed to get Java processes: ${e.message}');

// Line 49: replace print('Success: $result');
logger.i('Game client started: $result');

// Line 51: replace print('Failed to run game client: ${e.message}');
logger.e('Failed to run game client: ${e.message}');

// Line 53: replace print('An unexpected error occurred: $e');
logger.e('Unexpected error running game client: $e');
```

- [ ] **Step 2: Add logger import and replace print() in process_model.dart**

```dart
// Add at top:
import 'package:command_center/core/helper/logger.dart';

// Line 32: replace print(processes);
logger.d('Parsed ${processes.length} Java processes');
```

- [ ] **Step 3: Replace print() in status_controller.dart**

Logger is already imported in this file.

```dart
// Line 163: replace print('Failed to run game script: $e');
logger.e('Failed to run game script: $e');
```

- [ ] **Step 4: Run dart analyze to verify no avoid_print warnings**

Run: `flutter analyze lib/config/services/native_commands_service.dart lib/feature/Status/data/process_model.dart lib/feature/Status/controller/status_controller.dart`
Expected: No `avoid_print` infos

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/native_commands_service.dart lib/feature/Status/data/process_model.dart lib/feature/Status/controller/status_controller.dart
git commit -m "fix(lint): replace print() calls with logger"
```

---

### Task 2: Fix deprecated `printTime` in logger.dart

**Files:**
- Modify: `lib/core/helper/logger.dart:10`

- [ ] **Step 1: Replace deprecated printTime with dateTimeFormat**

In logger 2.x, `printTime: true` was deprecated in favor of `dateTimeFormat`.

```dart
// Before (line 10):
//   printTime: true,
// After:
//   dateTimeFormat: DateTimeFormat.dateAndTime,

final logger = Logger(
    printer: PrettyPrinter(
  methodCount: 0,
  errorMethodCount: 5,
  lineLength: 50,
  colors: true,
  printEmojis: true,
  dateTimeFormat: DateTimeFormat.dateAndTime,
));
```

- [ ] **Step 2: Run dart analyze to verify no deprecated_member_use**

Run: `flutter analyze lib/core/helper/logger.dart`
Expected: No `deprecated_member_use` info

- [ ] **Step 3: Commit**

```bash
git add lib/core/helper/logger.dart
git commit -m "fix(lint): replace deprecated printTime with dateTimeFormat in logger"
```

---

### Task 3: Fix `use_build_context_synchronously` warnings

**Files:**
- Modify: `lib/feature/app/views/dialogs/ipqs_config_dialog.dart:91-92,133-134`
- Modify: `lib/feature/app/views/dialogs/webshare_config_dialog.dart:107-108,174-175`

- [ ] **Step 1: Add mounted guards in ipqs_config_dialog.dart**

Two `showInfoBarToast(context, ...)` calls use the outer `context` after `await` without checking `mounted`.

```dart
// _handleUnlink — after Navigator.pop, before showInfoBarToast (around line 92):
if (dialogContext.mounted) Navigator.of(dialogContext).pop();
if (context.mounted) {
  showInfoBarToast(context,
      title: 'Unlinked',
      message: 'IPQualityScore has been disconnected.',
      severity: InfoBarSeverity.warning);
}

// _handleConnect — after Navigator.pop, before showInfoBarToast (around line 133-134):
if (dialogContext.mounted) Navigator.of(dialogContext).pop();
if (context.mounted) {
  showInfoBarToast(context,
      title: 'Success',
      message: 'IPQualityScore connected!',
      severity: InfoBarSeverity.success);
}
```

- [ ] **Step 2: Add mounted guards in webshare_config_dialog.dart**

Same pattern — two `showInfoBarToast(context, ...)` calls after `await`.

```dart
// _handleUnlink — around line 107-108:
if (dialogContext.mounted) Navigator.of(dialogContext).pop();
if (context.mounted) {
  showInfoBarToast(context,
      title: 'Unlinked',
      message: 'Webshare has been disconnected and all proxy data cleared.',
      severity: InfoBarSeverity.warning);
}

// _handleConnect — around line 174-175:
if (dialogContext.mounted) Navigator.of(dialogContext).pop();
if (context.mounted) {
  showInfoBarToast(context,
      title: syncSuccess ? 'Success' : 'Partial Success',
      message: syncSuccess
          ? 'Webshare connected and proxies synced!'
          : 'Webshare connected but sync failed. Try syncing from the Proxy page.',
      severity: syncSuccess
          ? InfoBarSeverity.success
          : InfoBarSeverity.warning);
}
```

- [ ] **Step 3: Run dart analyze on both files**

Run: `flutter analyze lib/feature/app/views/dialogs/ipqs_config_dialog.dart lib/feature/app/views/dialogs/webshare_config_dialog.dart`
Expected: No `use_build_context_synchronously` infos

- [ ] **Step 4: Commit**

```bash
git add lib/feature/app/views/dialogs/ipqs_config_dialog.dart lib/feature/app/views/dialogs/webshare_config_dialog.dart
git commit -m "fix(lint): add mounted guards for use_build_context_synchronously"
```

---

### Task 4: Verify zero lint violations across entire codebase

- [ ] **Step 1: Run flutter analyze on the full project**

Run: `flutter analyze`
Expected: 0 issues found (infos, warnings, or errors). If any remain, fix them before proceeding.

- [ ] **Step 2: Run dart format check**

Run: `dart format --set-exit-if-changed .`
Expected: Exit code 0 (no formatting changes needed). If files need formatting, run `dart format .` then commit the changes.

- [ ] **Step 3: Commit any formatting fixes**

```bash
# Only if Step 2 found changes:
git add -A
git commit -m "style: apply dart format to entire codebase"
```

---

### Task 5: Add lint job to CI workflow

**Files:**
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Add the lint job after lint-commits**

Insert a new `lint` job between `lint-commits` and `build`. The `build` job gets `needs: [lint-commits, lint]`.

```yaml
  lint:
    name: Lint & Test
    runs-on: ubuntu-latest
    needs: lint-commits
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install dependencies
        run: flutter pub get

      - name: Check formatting
        run: dart format --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test
```

- [ ] **Step 2: Update build job to depend on lint**

Change the `build` job's `needs` from `lint-commits` to `[lint-commits, lint]`:

```yaml
  build:
    name: Build Windows Application
    runs-on: windows-latest
    needs: [lint-commits, lint]
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add lint job with format, analyze, and test steps"
```

---

### Task 6: Create pre-commit hook

**Files:**
- Create: `scripts/hooks/pre-commit`

- [ ] **Step 1: Create the pre-commit hook script**

```bash
#!/bin/sh
# Pre-commit hook: check Dart formatting
# Install: cp scripts/hooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

echo "Running dart format check..."
dart format --set-exit-if-changed . 2>/dev/null
if [ $? -ne 0 ]; then
  echo ""
  echo "Formatting issues found. Run 'dart format .' to fix."
  exit 1
fi
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/hooks/pre-commit`

- [ ] **Step 3: Document in SETUP.md**

Add a "Pre-commit Hook" section after the "Development Notes" section:

```markdown
### Pre-commit Hook (Recommended)
Install the formatting pre-commit hook to catch issues before push:

```bash
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

This runs `dart format --set-exit-if-changed .` on every commit.
```

- [ ] **Step 4: Commit**

```bash
git add scripts/hooks/pre-commit SETUP.md
git commit -m "ci: add pre-commit hook for dart format"
```

---

### Task 7: Create Phase 1 PR

- [ ] **Step 1: Push and create PR**

```bash
git push -u origin dev
```

Then create a PR from `dev` to `main` with title "ci: Phase 1 — CI hardening" summarizing all changes. Or keep on `dev` if accumulating phases before merging.

---

## Chunk 2: Phase 2 — Error Handling Contract

> **Note:** Tasks 9-11 form a cascading migration (repos → services → controllers). Intermediate commits after Tasks 9 and 10 will not compile because consumers of the old signatures aren't updated yet. This is expected — only push to remote after Task 11 completes and the full codebase compiles.

### Task 8: Create `Result<T>` sealed class

**Files:**
- Create: `lib/core/resource/result.dart`

- [ ] **Step 1: Create the Result sealed class**

```dart
/// Unified result type for service/repository operations.
/// Use pattern matching in controllers to unwrap:
///
/// ```dart
/// switch (result) {
///   case Success(:final data): // handle success
///   case Failure(:final message): // handle failure
/// }
/// ```
sealed class Result<T> {
  const Result();
  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, [Object? error]) = Failure<T>;
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, [this.error]);
}
```

Note: using `extends` instead of `implements` so the `const Result()` constructor is available and `switch` exhaustiveness works with Dart 3 sealed classes.

- [ ] **Step 2: Commit**

```bash
git add lib/core/resource/result.dart
git commit -m "feat: add Result<T> sealed class for unified error handling"
```

---

### Task 9: Migrate repositories to `Result<T>`

**Files:**
- Modify: `lib/data/repositories/config_repository_impl.dart`
- Modify: `lib/domain/repositories/config_repository.dart`
- Modify: `lib/data/repositories/account_repository_impl.dart`
- Modify: `lib/domain/repositories/account_repository.dart`
- Modify: `lib/data/repositories/proxy_repository_impl.dart`
- Modify: `lib/domain/repositories/proxy_repository.dart`

This is the bottom of the call stack. Repositories wrap Drift operations in try-catch and return `Result<T>`.

- [ ] **Step 1: Read all repository interfaces and implementations**

Read the abstract interfaces in `lib/domain/repositories/` and the implementations in `lib/data/repositories/` to understand every method signature that needs to change.

- [ ] **Step 2: Update ConfigRepository interface and implementation**

`ConfigRepositoryImpl` is the simplest — key-value CRUD. Change methods that currently return raw types to return `Result<T>`:

- `Future<String?> getValue(key)` → `Future<Result<String?>> getValue(key)`
- `Future<void> setValue(key, value)` → `Future<Result<void>> setValue(key, value)`
- `Future<void> deleteValue(key)` → `Future<Result<void>> deleteValue(key)`
- `Future<Map<String, String>> getAllConfig()` → `Future<Result<Map<String, String>>> getAllConfig()`
- `Future<void> clearAll()` → `Future<Result<void>> clearAll()`
- `Stream<String?> watchValue(key)` — keep as stream (reactive, not request-response)

Update both the interface and implementation. Wrap each Drift call in try-catch, return `Result.success(data)` or `Result.failure(message, error)`.

- [ ] **Step 3: Update AccountRepository interface and implementation**

Same pattern. Wrap Drift calls, return `Result<T>`. The `jsonDecode` try-catch in `_mapCharacterRow` already exists from the bug-fix phase — keep it.

- [ ] **Step 4: Update ProxyRepository interface and implementation**

Same pattern. This is the largest repository — read it first to understand all methods.

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze`
Expected: Compilation errors in services/controllers that consume repositories — this is expected and will be fixed in Tasks 10-11.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/ lib/data/repositories/
git commit -m "refactor: migrate repositories to Result<T> return types"
```

---

### Task 10: Migrate services to `Result<T>`

**Files:**
- Modify: `lib/config/services/webshare/webshare_service.dart`
- Modify: `lib/config/services/ipqs/ipqs_service.dart`
- Modify: `lib/config/services/app_config_service.dart`
- Modify: `lib/config/services/onboarding_service.dart`
- Modify: `lib/config/services/proxy/proxy_replacement_service.dart`

- [ ] **Step 1: Read all service files to understand current patterns**

Read each service file. Identify:
- Methods returning `({bool success, String? error})` → change to `Result<void>` or `Result<T>`
- Methods returning `Future<bool>` for success/failure → change to `Result<void>`
- Methods that call updated repositories → update to handle `Result<T>` from repos

- [ ] **Step 2: Update WebshareService**

Replace `({bool success, String? error})` pattern in `testAndConnect`, `replaceProxyIp`, `_pollReplacementStatus`:
- `Future<({bool success, String? error})> testAndConnect(...)` → `Future<Result<void>> testAndConnect(...)`
- `Future<({bool success, String? error})> replaceProxyIp(...)` → `Future<Result<void>> replaceProxyIp(...)`

Also update `saveApiKey` and `clearApiKey` from `Future<bool>` to `Future<Result<void>>`.

Services catch exceptions and return `Result.failure(message, error)`. No error observables — remove `lastError` observable from service (move to controllers in Task 11).

- [ ] **Step 3: Update IpqsService**

Change only `saveApiKey` and `clearApiKey` from `Future<bool>` to `Future<Result<void>>`. Keep `IpqsResult` for scoring responses — `testAndConnect` returns `Future<IpqsResult>` (not the record pattern) and should NOT be changed.

- [ ] **Step 4: Update AppConfigService**

Change methods that return `Future<bool>` to `Result<void>`. Update calls to `ConfigRepository` to handle `Result<T>`.

- [ ] **Step 5: Update OnboardingService**

Update calls to underlying services/repos to handle `Result<T>`.

- [ ] **Step 6: Update ProxyReplacementService**

Change `Future<({bool success, String? error})> replaceProxyIp(...)` to `Future<Result<void>> replaceProxyIp(...)`.

- [ ] **Step 7: Verify compilation**

Run: `flutter analyze`
Expected: Compilation errors in controllers that consume services — fix in Task 11.

- [ ] **Step 8: Commit**

```bash
git add lib/config/services/
git commit -m "refactor: migrate services to Result<T> return types"
```

---

### Task 11: Migrate controllers to consume `Result<T>`

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_controller.dart`
- Modify: `lib/feature/Status/controller/status_controller.dart`
- Modify: `lib/feature/proxy/controller/proxy_scoring_controller.dart`
- Modify: `lib/feature/proxy/controller/proxy_replacement_controller.dart`

- [ ] **Step 1: Read all controller files**

Identify every call site that consumes a service/repo method that now returns `Result<T>`.

- [ ] **Step 2: Update ProxyController**

Use exhaustive `switch` on `Result<T>`:

```dart
final result = await _webshareService.testAndConnect(apiKey);
switch (result) {
  case Success():
    lastError.value = null;
    // proceed
  case Failure(:final message):
    lastError.value = message;
    logger.e(message);
}
```

- [ ] **Step 3: Update StatusController**

Same pattern. Unwrap `Result`, set UI observables.

- [ ] **Step 4: Update ProxyScoringController**

Same pattern.

- [ ] **Step 5: Update ProxyReplacementController**

Same pattern.

- [ ] **Step 6: Update dialogs that directly call services**

Config dialogs call services directly. Only update call sites where the return type actually changed:
- `webshare_config_dialog.dart`: `testAndConnect` now returns `Result<void>` (was record), `saveApiKey`/`clearApiKey` now return `Result<void>` (was `bool`)
- `ipqs_config_dialog.dart`: `clearApiKey` now returns `Result<void>` (was `bool`). `testAndConnect` returns `IpqsResult` — unchanged, no migration needed.
- `ipqs_onboarding_dialog.dart`: Same as `ipqs_config_dialog.dart` — only `saveApiKey`/`clearApiKey` change.

**Files:**
- Modify: `lib/feature/app/views/dialogs/webshare_config_dialog.dart`
- Modify: `lib/feature/app/views/dialogs/ipqs_config_dialog.dart`
- Modify: `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart`

- [ ] **Step 7: Run flutter analyze — zero issues**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 8: Run flutter build windows to verify compilation**

Run: `flutter build windows --release`
Expected: Build succeeds

- [ ] **Step 9: Commit**

```bash
git add lib/feature/
git commit -m "refactor: migrate controllers and dialogs to consume Result<T>"
```

---

## Chunk 3: Phase 3 — Architecture Decomposition

### Task 12: Decompose `main_menu_screen.dart` (405 → ~80 lines)

**Files:**
- Modify: `lib/feature/main_menu/views/main_menu_screen.dart`
- Create: `lib/feature/main_menu/views/sections/system_overview_section.dart`
- Create: `lib/feature/main_menu/views/sections/characters_status_section.dart`
- Create: `lib/feature/main_menu/views/sections/recent_activity_section.dart`

- [ ] **Step 1: Create sections directory**

Run: `ls lib/feature/main_menu/views/` — verify structure, then create `sections/` if needed.

- [ ] **Step 2: Extract SystemOverviewSection**

Move `_buildOverviewStats`, `_getAccountCount`, `_getProxyCount`, `_getIssuesCount`, `_getIssuesTooltip`, `_buildStatCard` into `system_overview_section.dart`. Accept `onNavigateToIndex` callback as constructor param.

- [ ] **Step 3: Extract CharactersStatusSection**

Move `_buildCharacterStatusSection`, `_getCharacterCounts`, `_buildCharacterStatusCard` into `characters_status_section.dart`.

- [ ] **Step 4: Extract RecentActivitySection**

Move `_buildRecentActivityPlaceholder` into `recent_activity_section.dart`.

- [ ] **Step 5: Update main_menu_screen.dart to compose sections**

The screen becomes a thin layout shell:

```dart
@override
Widget build(BuildContext context) {
  return ScaffoldPage.scrollable(
    header: const PageHeader(title: Text('Overview')),
    children: [
      SystemOverviewSection(onNavigateToIndex: onNavigateToIndex),
      const SizedBox(height: 16),
      const CharactersStatusSection(),
      const SizedBox(height: 16),
      const RecentActivitySection(),
    ],
  );
}
```

- [ ] **Step 6: Verify file sizes are within ceilings**

Screen ≤ 150 lines, each section ≤ 300 lines.

- [ ] **Step 7: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 8: Commit**

```bash
git add lib/feature/main_menu/
git commit -m "refactor: decompose main_menu_screen into 3 sections"
```

---

### Task 13: Decompose `proxy_screen.dart` (380 → ~100 lines)

**Files:**
- Modify: `lib/feature/proxy/views/proxy_screen.dart`
- Create: `lib/feature/proxy/views/sections/proxy_command_bar.dart`
- Create: `lib/feature/proxy/views/sections/integration_required_view.dart`
- Create: `lib/feature/proxy/views/helpers/proxy_screen_actions.dart`

- [ ] **Step 1: Extract ProxyCommandBar widget**

Move `_buildCommandBar()` (~43 lines) into `proxy_command_bar.dart`. Accept `scoringController`, `controller`, and `onScoreAll`/`onSync` callbacks.

- [ ] **Step 2: Extract IntegrationRequiredView widget**

Move `_buildIntegrationRequiredView()` (~66 lines) into `integration_required_view.dart`. Accept `controller` and `onNavigateToSettings` callback.

- [ ] **Step 3: Extract action callbacks into a mixin**

Create `proxy_screen_actions.dart` with a mixin `ProxyScreenActions on State<ProxyScreen>` containing `_launchBrowserWithProxy`, `_refreshIpScore`, `_scoreAllIps`, `_showAddSlotDialog`, `_showChangeIpDialog`, `_showReplaceProxyDialog`.

- [ ] **Step 4: Update proxy_screen.dart**

Mix in `ProxyScreenActions`. Screen becomes a thin layout shell calling the extracted widgets and mixin methods.

- [ ] **Step 5: Verify file sizes are within ceilings**

Screen ≤ 150 lines, sections ≤ 300 lines, mixin ≤ 200 lines.

- [ ] **Step 6: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 7: Commit**

```bash
git add lib/feature/proxy/views/
git commit -m "refactor: decompose proxy_screen into sections and action mixin"
```

---

### Task 14: Decompose `ip_score_analysis.dart` (359 → 3 files)

**Files:**
- Modify: `lib/feature/proxy/views/components/ip_score_analysis.dart`
- Create: `lib/feature/proxy/views/components/score_summary.dart`
- Create: `lib/feature/proxy/views/components/score_detail_table.dart`
- Create: `lib/feature/proxy/views/components/score_flags.dart`

- [ ] **Step 1: Read ip_score_analysis.dart to identify logical splits**

- [ ] **Step 2: Extract ScoreSummary widget**

Top-level score display (number, level, color indicator).

- [ ] **Step 3: Extract ScoreDetailTable widget**

The detail grid/table showing individual scoring factors.

- [ ] **Step 4: Extract ScoreFlags widget**

Boolean flag indicators (VPN, proxy, datacenter, Tor).

- [ ] **Step 5: Update ip_score_analysis.dart to compose the 3 widgets**

Or remove the file entirely if the parent can compose directly.

- [ ] **Step 6: Verify each file ≤ 200 lines**

- [ ] **Step 7: Run flutter analyze**

- [ ] **Step 8: Commit**

```bash
git add lib/feature/proxy/views/components/
git commit -m "refactor: decompose ip_score_analysis into 3 components"
```

---

### Task 15: Decompose `proxy_slot_card.dart` (293 → ~150 + extracted)

**Files:**
- Modify: `lib/feature/proxy/views/components/proxy_slot_card.dart`
- Create: `lib/feature/proxy/views/components/proxy_slot_card_header.dart`
- Create: `lib/feature/proxy/views/components/proxy_slot_card_body.dart`
- Create: `lib/feature/proxy/views/components/proxy_slot_card_actions.dart`

- [ ] **Step 1: Read proxy_slot_card.dart to identify logical splits**

- [ ] **Step 2: Extract card header, body, and actions**

- [ ] **Step 3: Update proxy_slot_card.dart to compose the parts**

- [ ] **Step 4: Verify each file ≤ 200 lines**

- [ ] **Step 5: Commit**

```bash
git add lib/feature/proxy/views/components/
git commit -m "refactor: decompose proxy_slot_card into header, body, actions"
```

---

### Task 16: Extract `CurrentIpCard` from `slot_header.dart`

**Files:**
- Modify: `lib/feature/proxy/views/components/slot_header.dart`
- Create: `lib/feature/proxy/views/components/current_ip_card.dart`

- [ ] **Step 1: Move CurrentIpCard class (lines 194-237) to its own file**

Move the `CurrentIpCard` class and its `_buildSimpleInfoRow` helper. Add the `formatDate` import if needed.

- [ ] **Step 2: Update slot_header.dart imports**

Remove `CurrentIpCard` from `slot_header.dart`, import it from the new file where used.

- [ ] **Step 3: Update any imports of CurrentIpCard from slot_header.dart**

Search for `import '...slot_header.dart'` in files that use `CurrentIpCard` and update to import from `current_ip_card.dart`.

Run: `grep -r 'CurrentIpCard' lib/` to find all usage.

- [ ] **Step 4: Verify slot_header.dart ≤ 200 lines**

- [ ] **Step 5: Commit**

```bash
git add lib/feature/proxy/views/components/
git commit -m "refactor: extract CurrentIpCard from slot_header.dart"
```

---

### Task 17: Decompose `about_card.dart` (235 → ~100 + extracted)

**Files:**
- Modify: `lib/feature/app/views/components/about_card.dart`
- Create: `lib/feature/app/views/components/about_version_info.dart`
- Create: `lib/feature/app/views/components/about_links_section.dart`

- [ ] **Step 1: Read about_card.dart to identify logical splits**

- [ ] **Step 2: Extract version info and links section widgets**

- [ ] **Step 3: Update about_card.dart to compose the parts**

- [ ] **Step 4: Verify each file ≤ 200 lines**

- [ ] **Step 5: Commit**

```bash
git add lib/feature/app/views/components/
git commit -m "refactor: decompose about_card into version info and links"
```

---

### Task 18: Decompose services

**Files:**
- Modify: `lib/config/services/python_setup_service.dart`
- Create: `lib/config/services/python_dependency_checker.dart`
- Modify: `lib/config/services/webshare/webshare_service.dart`
- Create: `lib/config/services/webshare/webshare_replacement_handler.dart`

- [ ] **Step 1: Read python_setup_service.dart to identify extraction target**

- [ ] **Step 2: Extract dependency checker logic into helper**

Move the logic that checks Python, pip, patchright, and Chromium availability into `python_dependency_checker.dart`.

- [ ] **Step 3: Read webshare_service.dart and extract replacement handler**

Move `replaceProxyIp`, `_pollReplacementStatus`, and `_parseErrorMessage` (~110 lines) into `webshare_replacement_handler.dart`.

- [ ] **Step 4: Verify each service ≤ 250 lines**

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/
git commit -m "refactor: extract python dependency checker and webshare replacement handler"
```

---

### Task 19: Decompose `ipqs_onboarding_dialog.dart` (231 → ≤200)

**Files:**
- Modify: `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart`
- Create: `lib/feature/app/views/components/scoring_progress_display.dart`

- [ ] **Step 1: Read ipqs_onboarding_dialog.dart to identify extraction target**

- [ ] **Step 2: Extract scoring progress UI into a reusable widget**

- [ ] **Step 3: Verify dialog ≤ 200 lines**

- [ ] **Step 4: Commit**

```bash
git add lib/feature/app/views/
git commit -m "refactor: extract scoring progress display from ipqs_onboarding_dialog"
```

---

### Task 20: Verify all decomposed files are within ceilings

- [ ] **Step 1: Check line counts for all modified/created files**

Run: `wc -l` on each file and verify against CLAUDE.md ceilings: Screen ≤ 150, Section ≤ 300, Component ≤ 200, Dialog ≤ 200, Service ≤ 250.

- [ ] **Step 2: Run flutter analyze and build**

Run: `flutter analyze && flutter build windows --release`
Expected: 0 issues, build succeeds

- [ ] **Step 3: Commit any final fixes**

---

## Chunk 4: Phase 4 — Tests

### Task 21: Set up test infrastructure

**Files:**
- Modify: `pubspec.yaml`
- Create: `test/helpers/test_helpers.dart`

- [ ] **Step 1: Add mocktail to dev_dependencies**

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

Run: `flutter pub get`

- [ ] **Step 2: Create test helpers with mock factories**

```dart
// test/helpers/test_helpers.dart
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/config/services/webshare/webshare_api_client.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_api_client.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/config_repository.dart';

class MockWebshareService extends Mock implements WebshareService {}
class MockWebshareApiClient extends Mock implements WebshareApiClient {}
class MockIpqsService extends Mock implements IpqsService {}
class MockIpqsApiClient extends Mock implements IpqsApiClient {}
class MockAppConfigService extends Mock implements AppConfigService {}
class MockProxyRepository extends Mock implements ProxyRepository {}
class MockAccountRepository extends Mock implements AccountRepository {}
class MockConfigRepository extends Mock implements ConfigRepository {}
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml test/
git commit -m "test: add mocktail and test helper mock factories"
```

---

### Task 22: Test `Result<T>` sealed class

**Files:**
- Create: `test/core/resource/result_test.dart`

- [ ] **Step 1: Write tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/resource/result.dart';

void main() {
  group('Result', () {
    test('Success holds data', () {
      final result = Result<int>.success(42);
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).data, 42);
    });

    test('Failure holds message', () {
      final result = Result<int>.failure('something went wrong');
      expect(result, isA<Failure<int>>());
      expect((result as Failure<int>).message, 'something went wrong');
    });

    test('Failure holds optional error', () {
      final error = Exception('original');
      final result = Result<int>.failure('wrapped', error);
      expect((result as Failure<int>).error, error);
    });

    test('exhaustive switch works', () {
      final Result<String> result = Result.success('hello');
      late String output;
      switch (result) {
        case Success(:final data):
          output = data;
        case Failure(:final message):
          output = message;
      }
      expect(output, 'hello');
    });

    test('Result<void> success', () {
      // ignore: void_checks
      final result = Result<void>.success(null);
      expect(result, isA<Success<void>>());
    });
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/core/resource/result_test.dart`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add test/core/resource/result_test.dart
git commit -m "test: add Result<T> unit tests"
```

---

### Task 23: Test repositories with in-memory Drift database

**Files:**
- Create: `test/data/repositories/config_repository_impl_test.dart`
- Create: `test/data/repositories/proxy_repository_impl_test.dart`
- Create: `test/data/repositories/account_repository_impl_test.dart`

- [ ] **Step 1: Write ConfigRepositoryImpl tests**

Use `AppDatabase.forTesting(NativeDatabase.memory())` or equivalent in-memory setup. Test CRUD operations, verify `Result.success` and `Result.failure` returns.

- [ ] **Step 2: Write ProxyRepositoryImpl tests**

Test slot CRUD, IP address management, soft delete, recovery, `getAllSlotsIncludingDeleted`.

- [ ] **Step 3: Write AccountRepositoryImpl tests**

Test account CRUD, character with corrupted JSON (verify graceful degradation returns `SkillsEntity.empty()`), soft delete.

- [ ] **Step 4: Run all repository tests**

Run: `flutter test test/data/repositories/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add test/data/repositories/
git commit -m "test: add repository tests with in-memory Drift database"
```

---

### Task 24: Test services

**Files:**
- Create: `test/config/services/webshare_service_test.dart`
- Create: `test/config/services/ipqs_service_test.dart`
- Create: `test/config/services/app_config_service_test.dart`
- Create: `test/config/services/proxy_sync_service_test.dart`

- [ ] **Step 1: Write WebshareService tests**

Mock `WebshareApiClient`. Test `testAndConnect` success/failure paths, `saveApiKey`, `clearApiKey`, `replaceProxyIp` success/timeout/failure.

- [ ] **Step 2: Write IpqsService tests**

Mock `IpqsApiClient`. Test `testAndConnect`, `saveApiKey`, `clearApiKey`, `scoreIp`.

- [ ] **Step 3: Write AppConfigService tests**

Mock `ConfigRepository`. Test reading/writing config values, default handling.

- [ ] **Step 4: Write ProxySyncService tests**

Mock `ProxyRepository` and `WebshareService`. Test sync scenarios: new slots created, existing updated, stale soft-deleted, recovered slots, manual slots preserved.

- [ ] **Step 5: Run all service tests**

Run: `flutter test test/config/services/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add test/config/services/
git commit -m "test: add service unit tests"
```

---

### Task 25: Test controllers

**Files:**
- Create: `test/feature/proxy/controller/proxy_controller_test.dart`
- Create: `test/feature/Status/controller/status_controller_test.dart`
- Create: `test/feature/proxy/controller/proxy_scoring_controller_test.dart`

- [ ] **Step 1: Write ProxyController tests**

Mock services. Test `loadData`, `syncWithWebshare` (slot selection preservation), `selectSlot`, error state propagation.

Note: GetX controllers need `Get.testMode = true` in `setUp`.

- [ ] **Step 2: Write StatusController tests**

Mock services. Test `loadAccounts`, `runGameClient`, `stopGameClient`, process tracking.

- [ ] **Step 3: Write ProxyScoringController tests**

Mock services. Test `scoreIpWithIpqs`, `scoreAllCurrentIps` (batch with `skipReload`), `isClosed` check.

- [ ] **Step 4: Run all controller tests**

Run: `flutter test test/feature/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add test/feature/
git commit -m "test: add controller unit tests"
```

---

### Task 26: Widget tests for critical dialogs and components

**Files:**
- Create: `test/feature/app/views/dialogs/webshare_config_dialog_test.dart`
- Create: `test/feature/app/views/dialogs/add_slot_dialog_test.dart`
- Create: `test/feature/proxy/views/components/ip_history_list_test.dart`
- Create: `test/feature/proxy/views/components/proxy_slot_card_test.dart`

- [ ] **Step 1: Write WebshareConfigDialog widget tests**

Test validation (empty API key), error states, successful connection flow. Requires wrapping in `FluentApp` for Fluent UI theme context and mocking `WebshareService` via GetX DI (`Get.put(MockWebshareService())`).

- [ ] **Step 2: Write AddSlotDialog widget tests**

Test form validation: empty name, empty username/password, invalid port range, successful submission.

- [ ] **Step 3: Write IpHistoryList widget tests**

Test rendering with empty list, with <10 entries, with >10 entries (verify truncation indicator).

- [ ] **Step 4: Write ProxySlotCard widget tests**

Test rendering with various slot states: active/inactive, with/without IP, with/without score.

- [ ] **Step 5: Run widget tests**

Run: `flutter test test/feature/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add test/feature/
git commit -m "test: add widget tests for critical dialogs and components"
```

---

### Task 27: Run full test suite

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 2: Commit**

```bash
git commit --allow-empty -m "test: Phase 4 complete — test suite passing"
```

---

## Chunk 5: Phase 5 — Docs & Polish

### Task 28: Create `scripts/README.md`

**Files:**
- Create: `scripts/README.md`

- [ ] **Step 1: Write Python scripts documentation**

Cover:
- How to run each subcommand (`validate`, `create-account`, `session`)
- Proxy format: `username:password@p.webshare.io:80`
- Expected output: JSON after `=== RESULT ===` marker
- Dependency setup: `pip install -r requirements.txt`
- Debugging tips: common errors, how to test manually

- [ ] **Step 2: Commit**

```bash
git add scripts/README.md
git commit -m "docs: add Python scripts README"
```

---

### Task 29: Create `docs/DATABASE.md`

**Files:**
- Create: `docs/DATABASE.md`

- [ ] **Step 1: Write database documentation**

Cover:
- ERD of 5 tables (`AppConfigTable`, `ProxySlotsTable`, `ProxyIpAddressesTable`, `AccountsTable`, `CharactersTable`)
- Relationships: ProxySlots ↔ ProxyIpAddresses (1:N), Accounts ↔ Characters (1:N), Accounts ↔ ProxySlots (N:1)
- Migration strategy: Drift's `MigrationStrategy`, how to bump schema version
- How to add new tables/columns
- Backup location: `getApplicationDocumentsDirectory()/command_center.db`

- [ ] **Step 2: Commit**

```bash
git add docs/DATABASE.md
git commit -m "docs: add database schema documentation"
```

---

### Task 30: Enhance SETUP.md

**Files:**
- Modify: `SETUP.md`

- [ ] **Step 1: Add development environment section**

Add sections for:
- How to set up Flutter development environment
- How to run locally (`flutter run -d windows`)
- How to run tests (`flutter test`)
- How to run analyzer (`flutter analyze`)
- Drift code generation (`dart run build_runner build --delete-conflicting-outputs`)

- [ ] **Step 2: Commit**

```bash
git add SETUP.md
git commit -m "docs: enhance SETUP.md with dev environment and testing instructions"
```

---

### Task 31: Add file logging with rotation to logger

**Files:**
- Modify: `lib/core/helper/logger.dart`

- [ ] **Step 1: Read logger.dart and design file output**

Add an optional file output using the `logger` package's `FileOutput` or a custom output class. Write to `getApplicationDocumentsDirectory()/logs/command_center.log`. Add log rotation: max 5MB per file, keep 3 files.

Note: `path_provider` is likely already a dependency. Check `pubspec.yaml`.

- [ ] **Step 2: Implement file logging**

Create a `LoggerSetup` class or init function that configures both console and file outputs. The file output should:
- Create the logs directory if it doesn't exist
- Rotate when file exceeds 5MB
- Keep max 3 rotated files

- [ ] **Step 3: Commit**

```bash
git add lib/core/helper/logger.dart
git commit -m "feat: add file logging with rotation to logger"
```

---

### Task 32: Mask passwords in ValidationStatusIndicator

**Files:**
- Modify: `lib/feature/Status/views/components/validation_status_indicator.dart`

- [ ] **Step 1: Read the file to find password display location**

- [ ] **Step 2: Mask the password field in result display**

Replace plaintext password display with `'••••••••'`.

- [ ] **Step 3: Commit**

```bash
git add lib/feature/Status/views/components/validation_status_indicator.dart
git commit -m "fix(security): mask account passwords in validation result display"
```

---

### Task 33: Add cascade delete for Characters → Accounts

**Files:**
- Modify: `lib/data/database/tables/accounts_table.dart` (contains both `AccountsTable` and `CharactersTable`)
- Modify: `lib/data/database/app_database.dart` — bump `schemaVersion` to 3, add migration

- [ ] **Step 1: Read the Characters table definition in accounts_table.dart**

- [ ] **Step 2: Add cascade delete on the account foreign key**

In the Drift table definition, add `customConstraint` or `references` with `onDelete: KeyAction.cascade`.

- [ ] **Step 3: Bump schema version and add data-preserving migration**

SQLite doesn't support `ALTER TABLE` to modify constraints, so use the copy approach:

In `AppDatabase`:
```dart
@override
int get schemaVersion => 3;

// In the migration strategy, add from2To3:
from2To3: (m, schema) async {
  // 1. Create temp table with same structure
  await m.issueCustomQuery('CREATE TABLE characters_backup AS SELECT * FROM characters_table');
  // 2. Drop old table
  await m.issueCustomQuery('DROP TABLE characters_table');
  // 3. Create new table with cascade delete (via Drift schema)
  await m.createTable(schema.charactersTable);
  // 4. Copy data back
  await m.issueCustomQuery('INSERT INTO characters_table SELECT * FROM characters_backup');
  // 5. Drop backup
  await m.issueCustomQuery('DROP TABLE characters_backup');
},
```

This preserves all existing character data while adding the cascade delete constraint.

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Commit**

```bash
git add lib/data/database/
git commit -m "feat(db): add cascade delete for characters, bump schema to v3"
```

---

### Task 34: Investigate fluent_ui pin

- [ ] **Step 1: Check if fluent_ui 4.14+ is available and what breaks**

Run: `flutter pub outdated` to see available versions. Try upgrading temporarily and see what breaks.

- [ ] **Step 2: Document findings**

Either upgrade the pin or add a comment in `pubspec.yaml` explaining why it's pinned.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "docs: document fluent_ui version pin rationale"
```

---

### Task 35: Final verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All pass

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 3: Build**

Run: `flutter build windows --release`
Expected: Build succeeds

- [ ] **Step 4: Check formatting**

Run: `dart format --set-exit-if-changed .`
Expected: Exit code 0
