# Layered Atomic Architecture Refactor - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Decompose 7 heavy files (500-1,774 lines) into ~38 focused files with enforced line ceilings per the layered atomic architecture design.

**Architecture:** Bottom-up refactoring — extract services first (no UI deps), then controllers, then UI. Each task moves existing code into a new file and updates imports. Pure structural refactoring — no behavior changes.

**Tech Stack:** Flutter, GetX, Fluent UI, Drift ORM

**Verification:** `flutter analyze --no-fatal-infos` must pass after every task. No new warnings.

---

## Phase 1: Services Layer (Tasks 1-8)

Services have no UI dependencies, so they can be refactored first without touching screens.

### Task 1: Extract AutomationResult + AutomationStatus

**Files:**
- Create: `lib/config/services/automation/automation_result.dart`
- Modify: `lib/config/services/automation_service.dart`

**Step 1: Create the automation directory**

```bash
mkdir -p lib/config/services/automation
```

**Step 2: Create automation_result.dart**

Move `AutomationStatus` enum (lines 17-44) and `AutomationResult` class (lines 47-83) from `automation_service.dart` into the new file. Add the `dart:convert` import for `json`. The new file should export both classes.

**Step 3: Update automation_service.dart**

Replace the moved code with:
```dart
import 'package:command_center/config/services/automation/automation_result.dart';
```

Remove the `AutomationStatus` enum and `AutomationResult` class from the file. Keep everything else.

**Step 4: Update all imports across the codebase**

Search for files importing `automation_service.dart` that use `AutomationResult` or `AutomationStatus`. Add the new import alongside the existing one. Key files:
- `lib/feature/proxy/views/proxy_screen.dart`
- `lib/feature/Status/views/status_screen.dart`

**Step 5: Verify**

```bash
flutter analyze --no-fatal-infos
```

**Step 6: Commit**

```bash
git add lib/config/services/automation/
git add lib/config/services/automation_service.dart
git add -u  # updated imports
git commit -m "refactor: extract AutomationResult into automation/automation_result.dart"
```

---

### Task 2: Extract ResultParser

**Files:**
- Create: `lib/config/services/automation/result_parser.dart`
- Modify: `lib/config/services/automation_service.dart`

**Step 1: Create result_parser.dart**

Move `_extractJsonResult()` (lines 590-623) into a new top-level class:

```dart
import 'dart:convert';
import 'package:command_center/core/helper/logger.dart';

class ResultParser {
  /// Extract JSON result from script output after the === RESULT === marker
  static Map<String, dynamic>? extractJsonResult(String output) {
    // ... exact same logic from _extractJsonResult
  }
}
```

**Step 2: Update automation_service.dart**

Replace `_extractJsonResult(output)` calls with `ResultParser.extractJsonResult(output)`. Add import. Remove the private method.

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/config/services/automation/result_parser.dart lib/config/services/automation_service.dart
git commit -m "refactor: extract ResultParser from AutomationService"
```

---

### Task 3: Extract PythonRunner

**Files:**
- Create: `lib/config/services/automation/python_runner.dart`
- Modify: `lib/config/services/automation_service.dart`

**Step 1: Create python_runner.dart**

Move from `automation_service.dart`:
- `_runPythonScript()` method (lines 154-205)
- `cancelCurrentTask()` method (lines 126-151)
- `_currentProcess` field (line 101)
- `isCancelling` observable (line 93)
- Log-forwarding stream listeners

The class manages process lifecycle:

```dart
class PythonRunner {
  Process? _currentProcess;
  final isCancelling = false.obs;

  /// Callback for log lines from Python stdout
  final void Function(String message) onLog;

  PythonRunner({required this.onLog});

  Future<({int exitCode, String stdout, String stderr})> run(
    List<String> args, {
    required String workingDirectory,
    Duration timeout = const Duration(minutes: 2),
  }) async { ... }

  Future<void> cancel() async { ... }

  bool get isProcessRunning => _currentProcess != null;
}
```

**Step 2: Update automation_service.dart**

- Add `late final PythonRunner _runner;` field, initialize in a new `init()` or inline
- Replace `_runPythonScript(args)` calls with `_runner.run(args, workingDirectory: _scriptsPath)`
- Replace `cancelCurrentTask()` with delegation to `_runner.cancel()`
- Remove moved code

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/config/services/automation/python_runner.dart lib/config/services/automation_service.dart
git commit -m "refactor: extract PythonRunner from AutomationService"
```

---

### Task 4: Move automation_service.dart into automation/ directory

**Files:**
- Move: `lib/config/services/automation_service.dart` -> `lib/config/services/automation/automation_service.dart`
- Modify: all files importing the old path

**Step 1: Move the file**

```bash
mv lib/config/services/automation_service.dart lib/config/services/automation/automation_service.dart
```

**Step 2: Update all imports**

Search and replace across the codebase:
```
Old: package:command_center/config/services/automation_service.dart
New: package:command_center/config/services/automation/automation_service.dart
```

Key files to update:
- `lib/core/resource/dependency_injection.dart`
- `lib/feature/proxy/views/proxy_screen.dart`
- `lib/feature/Status/views/status_screen.dart`

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add -A
git commit -m "refactor: move automation_service.dart into automation/ directory"
```

---

### Task 5: Extract WebshareApiClient

**Files:**
- Create: `lib/config/services/webshare/webshare_api_client.dart`
- Modify: `lib/config/services/webshare_service.dart`

**Step 1: Create webshare directory and API client**

```bash
mkdir -p lib/config/services/webshare
```

Move HTTP methods from `webshare_service.dart` into `webshare_api_client.dart`:
- `_headers` getter (lines 91-94)
- `_headersWithKey()` (lines 96-99)
- `getProxyList()` (lines 152-195) — takes apiKey as parameter instead of reading from state
- `replaceProxyIp()` (lines 203-272) — takes apiKey as parameter
- `_pollReplacementStatus()` (lines 275-322) — takes apiKey as parameter
- `replaceProxy()` (lines 326-349) — takes apiKey as parameter
- `getProxyConfig()` (lines 352-373) — takes apiKey as parameter
- `getActivePlan()` (lines 376-402) — takes apiKey as parameter
- `testConnection()` (lines 146-149) — takes apiKey as parameter

Also move data models to the same file (or a separate models file):
- `WebshareProxySlot` (lines 406-463)
- `WebshareProxyConfig` (lines 466-485)
- `WebsharePlanInfo` (lines 488-524)

The API client is a plain class (not a GetxService). It receives the API key as a method parameter.

```dart
class WebshareApiClient {
  static const String _baseUrlV2 = 'https://proxy.webshare.io/api/v2';
  static const String _baseUrlV3 = 'https://proxy.webshare.io/api/v3';

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Token $apiKey',
    'Content-Type': 'application/json',
  };

  Future<List<WebshareProxySlot>> getProxyList(String apiKey) async { ... }
  Future<({bool success, String? error})> replaceProxyIp(String apiKey, String ipAddress, {String? countryCode}) async { ... }
  Future<WebsharePlanInfo?> getActivePlan(String apiKey) async { ... }
  // etc.
}
```

**Step 2: Update webshare_service.dart**

WebshareService keeps: API key management (save/load/clear), config sync, observable state. Delegates HTTP calls to `WebshareApiClient`.

```dart
class WebshareService extends GetxService {
  final _apiClient = WebshareApiClient();
  // ... observable state stays ...

  Future<List<WebshareProxySlot>> getProxyList() async {
    return _apiClient.getProxyList(apiKey.value!);
  }
}
```

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/config/services/webshare/ lib/config/services/webshare_service.dart
git commit -m "refactor: extract WebshareApiClient from WebshareService"
```

---

### Task 6: Move webshare_service.dart into webshare/ directory

**Files:**
- Move: `lib/config/services/webshare_service.dart` -> `lib/config/services/webshare/webshare_service.dart`
- Modify: all files importing the old path

**Step 1: Move and update imports**

Same pattern as Task 4. Key files:
- `lib/core/resource/dependency_injection.dart`
- `lib/feature/proxy/controller/proxy_controller.dart`
- `lib/feature/app.dart`

**Step 2: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add -A
git commit -m "refactor: move webshare_service.dart into webshare/ directory"
```

---

### Task 7: Extract IpqsApiClient

**Files:**
- Create: `lib/config/services/ipqs/ipqs_api_client.dart`
- Modify: `lib/config/services/ipqs_service.dart`

**Step 1: Create ipqs directory and API client**

```bash
mkdir -p lib/config/services/ipqs
```

Move from `ipqs_service.dart`:
- `_makeRequest()` (lines 242-261) — takes apiKey as parameter
- `IpqsResult` class (lines 9-88)

```dart
class IpqsApiClient {
  static const String _baseUrl = 'https://ipqualityscore.com/api/json/ip';

  Future<IpqsResult> scoreIp(String apiKey, String ipAddress) async { ... }
}
```

**Step 2: Update ipqs_service.dart**

IpqsService keeps: API key management, observable state, batching logic. Delegates HTTP to `IpqsApiClient`.

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/config/services/ipqs/ lib/config/services/ipqs_service.dart
git commit -m "refactor: extract IpqsApiClient from IpqsService"
```

---

### Task 8: Move ipqs_service.dart into ipqs/ directory

Same pattern as Tasks 4 and 6. Move file, update imports, verify, commit.

```bash
git commit -m "refactor: move ipqs_service.dart into ipqs/ directory"
```

---

## Phase 2: Controller Decomposition (Tasks 9-13)

### Task 9: Extract ProxySyncService

**Files:**
- Create: `lib/config/services/proxy/proxy_sync_service.dart`
- Modify: `lib/feature/proxy/controller/proxy_controller.dart`

**Step 1: Create proxy services directory**

```bash
mkdir -p lib/config/services/proxy
```

**Step 2: Create proxy_sync_service.dart**

Move from `proxy_controller.dart`:
- `syncWithWebshare()` (lines 115-185)
- `_createNewSlot()` (lines 187-253)
- `_updateExistingSlot()` (lines 255-336)

The service takes `ProxyRepository` and `WebshareService` as constructor params (not Get.find — injected by the controller):

```dart
class ProxySyncService {
  final ProxyRepository _proxyRepository;
  final WebshareService _webshareService;

  ProxySyncService(this._proxyRepository, this._webshareService);

  Future<void> syncWithWebshare() async { ... }
  Future<void> _createNewSlot(WebshareProxySlot webProxy) async { ... }
  Future<void> _updateExistingSlot(ProxySlotEntity existing, WebshareProxySlot webProxy) async { ... }
}
```

**Step 3: Update proxy_controller.dart**

Create `ProxySyncService` in `onInit()` and delegate:

```dart
late final ProxySyncService _syncService;

@override
void onInit() {
  super.onInit();
  _initRepository();
  _initWebshare();
  _initIpqs();
  _syncService = ProxySyncService(_proxyRepository!, _webshareService!);
  loadData();
}

Future<void> syncWithWebshare() async {
  isSyncing.value = true;
  lastSyncError.value = null;
  try {
    await _syncService.syncWithWebshare();
    await loadData();
  } catch (e) {
    lastSyncError.value = 'Failed to sync: ${e.toString()}';
  } finally {
    isSyncing.value = false;
  }
}
```

**Step 4: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/config/services/proxy/ lib/feature/proxy/controller/proxy_controller.dart
git commit -m "refactor: extract ProxySyncService from ProxyController"
```

---

### Task 10: Extract ProxyReplacementService

**Files:**
- Create: `lib/config/services/proxy/proxy_replacement_service.dart`
- Modify: `lib/feature/proxy/controller/proxy_controller.dart`

**Step 1: Create proxy_replacement_service.dart**

Move from `proxy_controller.dart`:
- `rotateSlotIp()` (lines 339-360)
- `replaceProxyIp()` (lines 366-415)
- `fetchPlanInfo()` (lines 418-433)

```dart
class ProxyReplacementService {
  final WebshareService _webshareService;

  ProxyReplacementService(this._webshareService);

  Future<bool> rotateSlotIp(ProxySlotEntity slot) async { ... }
  Future<({bool success, String? error})> replaceProxyIp(ProxySlotEntity slot, ProxyIpAddressEntity currentIp, {bool keepSameCountry = false}) async { ... }
  Future<WebsharePlanInfo?> fetchPlanInfo() async { ... }
}
```

**Step 2: Update proxy_controller.dart to delegate**

Controller keeps the observable state (`isReplacing`, `replacementsAvailable`, etc.) and wraps the service calls.

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/config/services/proxy/proxy_replacement_service.dart lib/feature/proxy/controller/proxy_controller.dart
git commit -m "refactor: extract ProxyReplacementService from ProxyController"
```

---

### Task 11: Extract ProxyScoringController

**Files:**
- Create: `lib/feature/proxy/controller/proxy_scoring_controller.dart`
- Modify: `lib/feature/proxy/controller/proxy_controller.dart`

**Step 1: Create proxy_scoring_controller.dart**

Move from `proxy_controller.dart`:
- `isScoring` observable
- `scoreIpWithIpqs()` (lines 655-700)
- `scoreAllCurrentIps()` (lines 703-741)
- `updateIpScore()` (lines 637-652)

```dart
class ProxyScoringController extends GetxController {
  final ProxyRepository _proxyRepository;
  final IpqsService _ipqsService;
  final ProxyController _proxyController;  // for getCurrentIpForSlot, loadIpAddresses

  var isScoring = false.obs;

  ProxyScoringController(this._proxyRepository, this._ipqsService, this._proxyController);

  Future<bool> scoreIpWithIpqs(ProxyIpAddressEntity ip) async { ... }
  Future<int> scoreAllCurrentIps() async { ... }
}
```

**Step 2: Update proxy_controller.dart**

Remove scoring methods. Keep `isScoring` as a forwarded getter if needed by UI, or let UI access `ProxyScoringController` directly.

**Step 3: Register in DI**

Add to `dependency_injection.dart`:
```dart
Get.lazyPut<ProxyScoringController>(() => ProxyScoringController(
  Get.find<DatabaseService>().proxyRepository,
  Get.find<IpqsService>(),
  Get.find<ProxyController>(),
), fenix: true);
```

**Step 4: Update proxy_screen.dart**

Replace `controller.scoreIpWithIpqs(ip)` with `Get.find<ProxyScoringController>().scoreIpWithIpqs(ip)` (or inject via constructor).

**Step 5: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/feature/proxy/controller/ lib/core/resource/dependency_injection.dart lib/feature/proxy/views/proxy_screen.dart
git commit -m "refactor: extract ProxyScoringController from ProxyController"
```

---

### Task 12: Register all new services in DI

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart`

**Step 1: Update imports and registrations**

Add `ProxySyncService` and `ProxyReplacementService` to `initializeAsyncServices()` after WebshareService is ready:

```dart
// After WebshareService registration:
final proxySyncService = ProxySyncService(
  databaseService.proxyRepository,
  webshareService,
);
Get.put<ProxySyncService>(proxySyncService, permanent: true);

final proxyReplacementService = ProxyReplacementService(webshareService);
Get.put<ProxyReplacementService>(proxyReplacementService, permanent: true);
```

Update `ProxyController` to receive these via `Get.find()` in `onInit()`.

**Step 2: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/core/resource/dependency_injection.dart lib/feature/proxy/controller/proxy_controller.dart
git commit -m "refactor: register new proxy services in DI"
```

---

## Phase 3: UI Decomposition — Proxy Screen (Tasks 13-19)

### Task 13: Create proxy views directory structure

**Files:**
- Create directories: `sections/`, `components/`, `dialogs/` under `lib/feature/proxy/views/`

```bash
mkdir -p lib/feature/proxy/views/sections
mkdir -p lib/feature/proxy/views/components
mkdir -p lib/feature/proxy/views/dialogs
```

Commit:
```bash
git commit --allow-empty -m "chore: create proxy views directory structure"
```

---

### Task 14: Extract proxy dialogs

**Files:**
- Create: `lib/feature/proxy/views/dialogs/replace_proxy_dialog.dart`
- Create: `lib/feature/proxy/views/dialogs/add_slot_dialog.dart`
- Create: `lib/feature/proxy/views/dialogs/change_ip_dialog.dart`
- Modify: `lib/feature/proxy/views/proxy_screen.dart`

**Step 1: Extract each dialog method into a StatelessWidget**

For `_showReplaceProxyDialog` (lines 1526-1659), create:

```dart
class ReplaceProxyDialog extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity currentIp;
  final ProxyController controller;

  const ReplaceProxyDialog({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.controller,
  });

  static Future<void> show(BuildContext context, ProxySlotEntity slot, ProxyIpAddressEntity currentIp, ProxyController controller) {
    return showDialog(
      context: context,
      builder: (_) => ReplaceProxyDialog(slot: slot, currentIp: currentIp, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    // StatefulBuilder logic from _showReplaceProxyDialog moves here
  }
}
```

Repeat for `_showAddSlotDialog` (lines 1305-1378) and `_showChangeIpDialog` (lines 1422-1485).

**Step 2: Update proxy_screen.dart**

Replace dialog method calls with:
```dart
ReplaceProxyDialog.show(context, slot, ip, controller);
```

Remove the 3 private dialog methods.

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/feature/proxy/views/dialogs/ lib/feature/proxy/views/proxy_screen.dart
git commit -m "refactor: extract proxy dialogs into separate files"
```

---

### Task 15: Extract proxy components (small widgets)

**Files:**
- Create: `lib/feature/proxy/views/components/ip_score_indicator.dart`
- Create: `lib/feature/proxy/views/components/replace_proxy_button.dart`
- Create: `lib/feature/proxy/views/components/proxy_slot_card.dart`
- Modify: `lib/feature/proxy/views/proxy_screen.dart`

**Step 1: Extract ip_score_indicator.dart**

Move `_buildScoreBadge` (lines 602-619) + `_getScoreColor` (lines 1292-1299) into:

```dart
class IpScoreIndicator extends StatelessWidget {
  final double score;
  const IpScoreIndicator({super.key, required this.score});
  // ...
}
```

**Step 2: Extract replace_proxy_button.dart**

Move `_buildReplaceProxyButton` into its own widget file.

**Step 3: Extract proxy_slot_card.dart**

Move `_buildSlotCard` (lines 383-487) + `_buildSlotNameRow` (lines 490-570) + `_buildSlotInfoChip` (lines 621-637) + name editing state/methods (lines 572-600) into:

```dart
class ProxySlotCard extends StatefulWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity? currentIp;
  final bool isSelected;
  final VoidCallback onSelect;
  final ProxyController controller;
  // ...
}
```

**Step 4: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/feature/proxy/views/components/ lib/feature/proxy/views/proxy_screen.dart
git commit -m "refactor: extract proxy card and score components"
```

---

### Task 16: Extract ip_score_analysis and ip_history_list components

**Files:**
- Create: `lib/feature/proxy/views/components/ip_score_analysis.dart`
- Create: `lib/feature/proxy/views/components/ip_history_list.dart`
- Modify: `lib/feature/proxy/views/proxy_screen.dart`

**Step 1: Extract ip_score_analysis.dart**

Move `_buildScoreAnalysis` (lines 864-1082) + `_buildScoreRow` (lines 1084-1112) + `_buildFlagChip` (lines 1114-1167) into a component.

**Step 2: Extract ip_history_list.dart**

Move `_buildIpHistory` (lines 1197-1290) into a component.

**Step 3: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/feature/proxy/views/components/ lib/feature/proxy/views/proxy_screen.dart
git commit -m "refactor: extract IP score analysis and history components"
```

---

### Task 17: Extract proxy sections

**Files:**
- Create: `lib/feature/proxy/views/sections/proxy_list_section.dart`
- Create: `lib/feature/proxy/views/sections/proxy_detail_section.dart`
- Create: `lib/feature/proxy/views/components/slot_header.dart`
- Modify: `lib/feature/proxy/views/proxy_screen.dart`

**Step 1: Extract slot_header.dart**

Move `_buildSlotHeader` (lines 705-825) into a component.

**Step 2: Extract proxy_list_section.dart**

Move `_buildSlotListPanel` (lines 200-232) + `_buildSummaryStats` (lines 234-273) + `_buildStatChip` (lines 275-309) + `_buildFilters` (lines 311-343) + `_buildSlotList` (lines 345-381) into a section widget.

**Step 3: Extract proxy_detail_section.dart**

Move `_buildDetailsPanel` (lines 639-703) + `_buildCurrentIpCard` (lines 827-846) + `_buildSimpleInfoRow` (lines 848-862). This section composes: SlotHeader, current IP card, IpScoreAnalysis, IpHistoryList.

**Step 4: Slim down proxy_screen.dart**

After all extractions, `proxy_screen.dart` should be ~100-150 lines: a ScaffoldPage composing `ProxyListSection` and `ProxyDetailSection` side by side, plus the integration-required fallback view.

**Step 5: Verify and commit**

```bash
flutter analyze --no-fatal-infos
git add lib/feature/proxy/views/
git commit -m "refactor: extract proxy list and detail sections"
```

---

## Phase 4: UI Decomposition — App Shell (Tasks 18-22)

### Task 18: Create app feature directory structure

**Files:**
- Create directories under `lib/feature/app/`

```bash
mkdir -p lib/feature/app/views/sections
mkdir -p lib/feature/app/views/components
mkdir -p lib/feature/app/views/dialogs
mkdir -p lib/feature/app/controller
```

---

### Task 19: Extract app dialogs

**Files:**
- Create: `lib/feature/app/views/dialogs/webshare_config_dialog.dart`
- Create: `lib/feature/app/views/dialogs/ipqs_config_dialog.dart`
- Create: `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart`
- Modify: `lib/feature/app.dart`

Move:
- `_showWebshareConfigDialog` (lines 903-1184) → `WebshareConfigDialog`
- `_showIpqsConfigDialog` (lines 1186-1460) → `IpqsConfigDialog`
- `_showIpqsOnboardingDialog` (lines 1463-1645) → `IpqsOnboardingDialog`

Each becomes a StatelessWidget with a static `show()` method, same pattern as Task 14.

**Verify and commit:**
```bash
git commit -m "refactor: extract app configuration dialogs"
```

---

### Task 20: Extract settings and onboarding sections

**Files:**
- Create: `lib/feature/app/views/sections/settings_section.dart`
- Create: `lib/feature/app/views/sections/onboarding_section.dart`
- Create: `lib/feature/app/views/components/setup_checklist_item.dart`
- Modify: `lib/feature/app.dart`

Move:
- `_buildSettingsPage` (lines 447-546) + `_buildAboutSection` (lines 548-745) + `_buildAboutStatItem` (lines 747-779) + integration tiles (lines 781-901) → `SettingsSection`
- `_buildOnboardingRequired` (lines 217-273) + `_buildSetupChecklist` (lines 275-302) → `OnboardingSection`
- `_buildChecklistItem` (lines 304-367) → `SetupChecklistItem`

**Verify and commit:**
```bash
git commit -m "refactor: extract settings and onboarding sections from app shell"
```

---

### Task 21: Extract AppController

**Files:**
- Create: `lib/feature/app/controller/app_controller.dart`
- Modify: `lib/feature/app.dart`

Move state and logic from `_AppState` into a GetxController:
- `_currentIndex` → `currentIndex.obs`
- `_initialized` → `initialized.obs`
- `_paneDisplayMode` → `paneDisplayMode.obs`
- `_initializeApp()` → `initializeApp()`
- `navigateToSettings()`, `_navigateToIndex()`
- `onWindowClose()` cleanup logic

The App widget becomes a GetView<AppController> or stays StatefulWidget but delegates state to the controller.

**Verify and commit:**
```bash
git commit -m "refactor: extract AppController from app.dart state"
```

---

### Task 22: Move app.dart into feature/app/ and slim down

**Files:**
- Move: `lib/feature/app.dart` -> `lib/feature/app/views/app_screen.dart`
- Modify: `lib/main.dart` (update import)

After all extractions, `app_screen.dart` should be ~120-150 lines: NavigationView shell composing sections.

**Verify and commit:**
```bash
git commit -m "refactor: move app shell to feature/app/views/app_screen.dart"
```

---

## Phase 5: UI Decomposition — Status Screen (Tasks 23-25)

### Task 23: Create status views directory structure

```bash
mkdir -p lib/feature/Status/views/sections
mkdir -p lib/feature/Status/views/components
mkdir -p lib/feature/Status/views/dialogs
```

---

### Task 24: Extract create character dialog

**Files:**
- Create: `lib/feature/Status/views/dialogs/create_character_dialog.dart`
- Modify: `lib/feature/Status/views/status_screen.dart`

Move `_showCreateCharacterDialog` (lines 425-834) into `CreateCharacterDialog` widget. This is the single biggest win — 400+ lines out of the screen file.

**Verify and commit:**
```bash
git commit -m "refactor: extract CreateCharacterDialog from status screen"
```

---

### Task 25: Extract status components and sections

**Files:**
- Create: `lib/feature/Status/views/components/account_card.dart`
- Create: `lib/feature/Status/views/components/character_row.dart`
- Create: `lib/feature/Status/views/components/process_status_badge.dart`
- Create: `lib/feature/Status/views/sections/account_list_section.dart`
- Modify: `lib/feature/Status/views/status_screen.dart`

Move:
- `_buildAccountsTable` + table cell helpers → `AccountListSection`
- `_buildStatusCell` → `ProcessStatusBadge`
- `_buildActionsCell` → part of `AccountCard`
- `_buildSummaryCards` + `_buildInfoCard` → part of section or component

After extraction, `status_screen.dart` should be ~100-150 lines.

**Verify and commit:**
```bash
git commit -m "refactor: extract status screen components and sections"
```

---

## Phase 6: Final Cleanup (Task 26)

### Task 26: Final verification and line count audit

**Step 1: Run full analysis**

```bash
flutter analyze --no-fatal-infos
```

**Step 2: Audit line counts**

Check that no file exceeds its layer ceiling:
```bash
find lib/ -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | sort -rn | head -20
```

**Step 3: Fix any files still over the limit**

If any file exceeds its ceiling, split further.

**Step 4: Final commit**

```bash
git commit -m "refactor: complete layered atomic architecture migration"
```

---

## Execution Order Summary

| Phase | Tasks | What Changes | Risk |
|-------|-------|-------------|------|
| 1: Services | 1-8 | Split thick services into API client + orchestrator | Low — no UI changes |
| 2: Controllers | 9-12 | Extract business logic from ProxyController | Medium — DI wiring |
| 3: Proxy UI | 13-17 | Decompose 1,774-line proxy_screen | Medium — many widget moves |
| 4: App UI | 18-22 | Decompose 1,690-line app.dart | Medium — navigation wiring |
| 5: Status UI | 23-25 | Decompose 835-line status_screen | Low — fewer components |
| 6: Cleanup | 26 | Audit and verify | Low |

Each task ends with `flutter analyze` passing. Each task gets its own commit. If any task breaks analysis, fix before proceeding.
