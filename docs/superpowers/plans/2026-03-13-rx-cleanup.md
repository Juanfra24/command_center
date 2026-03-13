# Rx Cleanup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate leaked Rx workers, dead observables, type mismatches, and missing disposal across the GetX reactive layer.

**Architecture:** Targeted fixes grouped by severity — critical leaks first, then dead code removal, then type safety. Each task is independent and produces a working app.

**Tech Stack:** Flutter, GetX (`get` ^4.6.5), Fluent UI

---

## File Map

| File | Issues | Task |
|------|--------|------|
| `lib/feature/app.dart:96-107,114-118` | 3 `ever()` workers never stored/disposed in StatefulWidget | 1 |
| `lib/feature/Status/controller/status_controller.dart:21` | `accountList` typed `List` but is `RxList` — breaks reactive contract | 2 |
| `lib/config/services/notification_service.dart:6` | Plain class with `.obs` field, no lifecycle management | 3 |
| `lib/feature/app/views/sections/onboarding_section.dart:67-70` | `.value` reads outside Obx — stale until parent setState | 4 |
| `lib/config/services/python_setup_service.dart:23-27` | 4 orphaned `.obs` fields never observed in UI | 5 |
| `lib/config/services/python_dependency_checker.dart:8` | `isChromiumInstalled` orphaned `.obs` | 5 |
| `lib/config/services/webshare/webshare_service.dart:25-26` | `isSyncing`, `lastSyncTime` dead Rx | 6 |
| `lib/config/services/onboarding_service.dart:18` | `isStatusSyncComplete` set but never read | 6 |
| `lib/feature/main_menu/controller/main_menu_controller.dart:7` | `isLoading` never set or observed | 6 |
| `lib/config/services/app_config_service.dart:27` | `isLoading` Rx never observed in UI | 6 |
| `lib/config/services/ipqs/ipqs_service.dart:21` | `apiKey` Rx used only as plain value | 6 |
| `lib/config/theme/theme_manager.dart:9` | `static` Rx field on GetxController — lifecycle mismatch | 7 |

---

## Phase 1: Critical Fixes (leaks + type safety)

### Task 1: Store and dispose ever() workers in _AppState

**Files:**
- Modify: `lib/feature/app.dart:36-118`

**Problem:** Three `ever()` workers are created at lines 98-106 inside a `StatefulWidget._initializeApp()`. The returned `Worker` objects are discarded — never stored and never disposed. Workers registered outside a `GetxController` are not automatically disposed by GetX.

- [ ] **Step 1: Add a `_workers` field and store each ever() result**

In `_AppState`, add a list field after the existing nullable controller fields (around line 51):

```dart
final List<Worker> _onboardingWorkers = [];
```

Replace lines 96-107:
```dart
// Before:
try {
  final obs = Get.find<OnboardingService>();
  ever(obs.isWebshareConfigured, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  });
  ever(obs.isIpqsConfigured, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  });
  ever(obs.isInitialSyncComplete, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  });
} catch (_) {}

// After:
try {
  final obs = Get.find<OnboardingService>();
  _onboardingWorkers.add(ever(obs.isWebshareConfigured, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  }));
  _onboardingWorkers.add(ever(obs.isIpqsConfigured, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  }));
  _onboardingWorkers.add(ever(obs.isInitialSyncComplete, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  }));
} catch (_) {}
```

- [ ] **Step 2: Dispose workers in `_AppState.dispose()`**

Update the existing `dispose()` at lines 114-118:

```dart
// Before:
@override
void dispose() {
  windowManager.removeListener(this);
  _flyoutController.dispose();
  super.dispose();
}

// After:
@override
void dispose() {
  for (final w in _onboardingWorkers) {
    w.dispose();
  }
  windowManager.removeListener(this);
  _flyoutController.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/app.dart
git commit -m "fix: store and dispose ever() workers in _AppState to prevent leaks"
```

---

### Task 2: Fix StatusController.accountList type annotation

**Files:**
- Modify: `lib/feature/Status/controller/status_controller.dart:21`

**Problem:** `accountList` is declared as `List<JagexAccount>` but assigned `<JagexAccount>[].obs` (an `RxList`). The declared type hides the reactive wrapper. Callers who hold a `List<JagexAccount>` reference lose change notifications. This also affects `processClients` at line 22-23 which is correctly typed as `RxMap`.

- [ ] **Step 1: Fix the type annotation**

```dart
// Before (line 21):
List<JagexAccount> accountList = <JagexAccount>[].obs;

// After:
final accountList = <JagexAccount>[].obs;
```

Using `final` with `.obs` lets Dart infer `RxList<JagexAccount>`, preserving the reactive contract. The `var` would also work but `final` is preferred since the reference itself should never be reassigned.

- [ ] **Step 2: Check for compile errors in dependent files**

`accountList` is accessed as a `List` in several places (`.length`, `.fold`, `.expand`, `.isEmpty`, iteration). `RxList` extends `ListMixin` so all `List` methods still work. No call site changes needed.

```bash
dart analyze
```

- [ ] **Step 3: Run tests**

```bash
flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/Status/controller/status_controller.dart
git commit -m "fix: declare accountList as RxList to preserve reactive contract"
```

---

### Task 3: Convert NotificationService to GetxService

**Files:**
- Modify: `lib/config/services/notification_service.dart:6`
- Modify: `lib/core/resource/dependency_injection.dart` (registration)

**Problem:** `NotificationService` is a plain Dart class with `final unreadCount = 0.obs`. Since it's not a `GetxService` or `GetxController`, GetX won't auto-manage the Rx lifecycle. The `RxInt` stream is never closed.

- [ ] **Step 1: Read dependency_injection.dart to see how NotificationService is registered**

Read `lib/core/resource/dependency_injection.dart` to find the `Get.put(NotificationService(...))` call and determine if `init()` is called separately or chained.

- [ ] **Step 2: Extend GetxService**

```dart
// Before (line 6):
class NotificationService {

// After:
class NotificationService extends GetxService {
```

This gives GetX lifecycle management over `unreadCount`. The `init()` method is already called manually after construction, which is compatible with `GetxService`.

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/config/services/notification_service.dart
git commit -m "fix: extend NotificationService from GetxService for Rx lifecycle management"
```

---

### Task 4: Wrap OnboardingSection checklist in Obx

**Files:**
- Modify: `lib/feature/app/views/sections/onboarding_section.dart:67-89`

**Problem:** `_buildSetupChecklist()` reads `onboardingService?.isWebshareConfigured.value` and `isIpqsConfigured.value` outside any `Obx()`. The values are stale until the parent `_AppState` happens to call `setState()` via the `ever()` workers (Task 1). This coupling is fragile — the section should be self-sufficient.

- [ ] **Step 1: Wrap the checklist column in Obx**

```dart
// Before (lines 67-89):
Widget _buildSetupChecklist(BuildContext context) {
  final isWebshareComplete =
      onboardingService?.isWebshareConfigured.value ?? false;
  final isIpqsComplete = onboardingService?.isIpqsConfigured.value ?? false;

  return Column(
    children: [
      SetupChecklistItem(
        title: 'Connect Webshare & Sync Proxies',
        subtitle: 'Connect your proxy provider and import slots',
        isComplete: isWebshareComplete,
        onTap: () => WebshareConfigDialog.show(context),
      ),
      const SizedBox(height: 12),
      SetupChecklistItem(
        title: 'Configure IPQualityScore',
        subtitle: 'Enable IP scoring and fraud detection',
        isComplete: isIpqsComplete,
        isEnabled: isWebshareComplete,
        onTap: () => IpqsOnboardingDialog.show(context),
      ),
    ],
  );
}

// After:
Widget _buildSetupChecklist(BuildContext context) {
  if (onboardingService == null) {
    return const SizedBox.shrink();
  }

  return Obx(() {
    final isWebshareComplete = onboardingService!.isWebshareConfigured.value;
    final isIpqsComplete = onboardingService!.isIpqsConfigured.value;

    return Column(
      children: [
        SetupChecklistItem(
          title: 'Connect Webshare & Sync Proxies',
          subtitle: 'Connect your proxy provider and import slots',
          isComplete: isWebshareComplete,
          onTap: () => WebshareConfigDialog.show(context),
        ),
        const SizedBox(height: 12),
        SetupChecklistItem(
          title: 'Configure IPQualityScore',
          subtitle: 'Enable IP scoring and fraud detection',
          isComplete: isIpqsComplete,
          isEnabled: isWebshareComplete,
          onTap: () => IpqsOnboardingDialog.show(context),
        ),
      ],
    );
  });
}
```

Add `import 'package:get/get.dart';` at the top if not already present.

- [ ] **Step 2: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 3: Commit**

```bash
git add lib/feature/app/views/sections/onboarding_section.dart
git commit -m "fix: wrap OnboardingSection checklist in Obx for reactive updates"
```

---

## Phase 2: Dead Rx Removal

### Task 5: Remove orphaned Rx fields from Python services

**Files:**
- Modify: `lib/config/services/python_setup_service.dart:23-27`
- Modify: `lib/config/services/python_dependency_checker.dart:8`

**Problem:** `PythonSetupService` has 4 `.obs` fields (`isChromiumInstalled`, `setupProgress`, `currentStep`, `setupProgressPercent`) that are written to internally but never observed in any `Obx()`, `ever()`, or UI consumer. `PythonDependencyChecker` has `isChromiumInstalled` with the same problem. These waste memory by maintaining Rx streams nobody subscribes to.

- [ ] **Step 1: Read both files to identify all usages of each field**

Read both files fully. For each `.obs` field, verify it is only written to (`.value = ...`) and never read reactively.

- [ ] **Step 2: Convert `PythonSetupService` orphaned fields to plain fields**

```dart
// Before (lines 23-27):
final isChromiumInstalled = false.obs;
final setupError = Rxn<String>();
final setupProgress = ''.obs;
final currentStep = SetupStep.idle.obs;
final setupProgressPercent = 0.0.obs;

// After:
bool isChromiumInstalled = false;
String? setupError;
String setupProgress = '';
SetupStep currentStep = SetupStep.idle;
double setupProgressPercent = 0.0;
```

Then update all internal writes from `.value =` to direct assignment:
- `isChromiumInstalled.value = true` → `isChromiumInstalled = true`
- `setupProgress.value = '...'` → `setupProgress = '...'`
- `currentStep.value = SetupStep.xxx` → `currentStep = SetupStep.xxx`
- `setupProgressPercent.value = 0.5` → `setupProgressPercent = 0.5`
- `setupError.value = '...'` → `setupError = '...'`

**Note:** `isSetupComplete` and `isChecking` (lines 21-22) are also not observed in any `Obx()` or `ever()` — `isSetupComplete.value` is read plainly in `automation_service.dart:63`, and `isChecking.value` is only a guard in `python_setup_service.dart:54`. Convert them to plain fields too for consistency. However, keeping them as `.obs` is harmless if a progress UI might be added later.

- [ ] **Step 3: Convert `PythonDependencyChecker.isChromiumInstalled` to plain bool**

```dart
// Before (line 8):
final isChromiumInstalled = false.obs;

// After:
bool isChromiumInstalled = false;
```

Update `verifyChromiumWorks()` line 90: `isChromiumInstalled.value = true` → `isChromiumInstalled = true`

Also in `PythonSetupService`, update `installChromiumDriver()` at line 180: `isChromiumInstalled.value = true` → `isChromiumInstalled = true`

- [ ] **Step 4: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/python_setup_service.dart \
        lib/config/services/python_dependency_checker.dart
git commit -m "refactor: convert orphaned Rx fields to plain fields in Python services"
```

---

### Task 6: Remove dead Rx fields across services and controllers

**Files:**
- Modify: `lib/config/services/webshare/webshare_service.dart:25-26`
- Modify: `lib/config/services/onboarding_service.dart:18`
- Modify: `lib/feature/main_menu/controller/main_menu_controller.dart:7`
- Modify: `lib/config/services/app_config_service.dart:27`
- Modify: `lib/config/services/ipqs/ipqs_service.dart:21`

**Problem:** Each of these has Rx fields that are either never observed in UI, never written to, or used only as plain values internally.

- [ ] **Step 1: Read each file and verify dead status**

For each field below, grep across `lib/feature/` to confirm no `Obx()` or `ever()` reads it:

1. `WebshareService.isSyncing` (line 25) — never written, `ProxyController` has its own
2. `WebshareService.lastSyncTime` (line 26) — set in `getProxyList()`, never read in UI
3. `OnboardingService.isStatusSyncComplete` (line 18) — not in `isOnboardingComplete`, not in UI
4. `MainMenuController.isLoading` (line 7) — never set to `true`, never read in Obx
5. `AppConfigService.isLoading` (line 27) — toggled in `loadConfig()`, not read in any Obx
6. `IpqsService.apiKey` (line 21) — used only internally as plain value

- [ ] **Step 2: Convert each dead field**

For fields never written to or never observed — convert to plain types:

```dart
// WebshareService — remove dead fields
// Before:
var isSyncing = false.obs;
var lastSyncTime = Rxn<DateTime>();
// After:
// DELETE isSyncing entirely (never written).
// Convert lastSyncTime to plain field (written at line 157, never read in UI):
DateTime? lastSyncTime;
// Update line 157: lastSyncTime.value = DateTime.now() → lastSyncTime = DateTime.now()

// MainMenuController — remove dead isLoading
// Before:
var isLoading = false.obs;
// After:
// DELETE the field entirely — it is never set or read

// AppConfigService.isLoading — convert to plain bool
// Before (line 27):
final isLoading = true.obs;
// After:
bool isLoading = true;
// Update loadConfig() lines 53 and 76: .value = → direct assignment

// IpqsService.apiKey — convert to plain nullable String
// Before (line 21):
final apiKey = Rxn<String>();
// After:
String? apiKey;
// Update ALL 6 internal .value read/write sites to direct access:
// lines 41, 44, 60, 79, 125, 133 in ipqs_service.dart
```

- [ ] **Step 3: Remove `isStatusSyncComplete` from OnboardingService**

Delete the field declaration at line 18:
```dart
// DELETE:
final isStatusSyncComplete = false.obs;
```

Delete the entire status sync block in `checkOnboardingStatus()` at lines 87-98:
```dart
// DELETE this entire block:
// Check status sync
try {
  final statusController = Get.find<StatusController>();
  isStatusSyncComplete.value = !statusController.isLoading.value;

  _workers.add(ever(statusController.isLoading, (loading) {
    if (!loading) {
      isStatusSyncComplete.value = true;
    }
  }));
} catch (_) {
  isStatusSyncComplete.value = false;
}
```

Delete `isStatusSyncComplete.value = false;` from `resetOnboarding()` (line 179).

- [ ] **Step 4: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/webshare/webshare_service.dart \
        lib/config/services/onboarding_service.dart \
        lib/feature/main_menu/controller/main_menu_controller.dart \
        lib/config/services/app_config_service.dart \
        lib/config/services/ipqs/ipqs_service.dart
git commit -m "refactor: remove dead Rx fields across services and controllers"
```

---

## Phase 3: Structural Improvements

### Task 7: Make ThemeManage static Rx field instance-level

**Files:**
- Modify: `lib/config/theme/theme_manager.dart`

**Problem:** `ThemeManage` extends `GetxController` but `_themeMode` is `static final Rx<ThemeMode>`. Static fields are not managed by GetxController lifecycle — auto-dispose does not apply. All methods are also `static`, meaning the GetxController base class adds nothing.

The cleanest fix: keep `ThemeManage` as-is functionally (static API), but remove the `extends GetxController` since the class never uses controller lifecycle. This makes the design honest — it's a static utility, not a controller.

- [ ] **Step 1: Remove GetxController extension**

```dart
// Before:
class ThemeManage extends GetxController {
  static const _themeKey = "isDarkMode";
  static final Rx<ThemeMode> _themeMode = getThemeMode().obs;
  // ... all static methods ...
}

// After:
class ThemeManage {
  ThemeManage._(); // prevent instantiation
  static const _themeKey = "isDarkMode";
  static final Rx<ThemeMode> _themeMode = getThemeMode().obs;
  // ... all static methods unchanged ...
}
```

- [ ] **Step 2: Verify no DI registration exists (no-op)**

`ThemeManage` is NOT registered in `lib/core/resource/dependency_injection.dart` — there is no `Get.put(ThemeManage())` or `Get.lazyPut`. No changes needed in DI. Just confirm with a quick grep.

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/config/theme/theme_manager.dart \
        lib/core/resource/dependency_injection.dart
git commit -m "refactor: remove GetxController from ThemeManage — static utility needs no lifecycle"
```

---

## Verification

After each phase:
1. `flutter test` — all tests pass
2. `dart analyze` — no issues
3. `dart format --set-exit-if-changed .` — properly formatted

Manual testing:
- **Phase 1:** Open/close app multiple times, verify no worker leak warnings in debug console. Complete onboarding — verify checklist updates live.
- **Phase 2:** Verify no runtime errors from missing `.value` — all converted fields still work as plain values.
- **Phase 3:** Toggle theme — verify still works with static ThemeManage (no GetxController instance needed).
