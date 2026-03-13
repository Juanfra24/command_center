# Flutter Performance Optimization Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate critical performance bottlenecks — unnecessary widget rebuilds, O(N*M) computations in build methods, memory leaks, and a LocalStorage bug — based on Flutter official best practices and a full codebase audit.

**Architecture:** Fixes are grouped into 4 phases by severity. Each phase produces a working, testable app. Changes follow the existing GetX + Fluent UI + Drift stack.

**Tech Stack:** Flutter, Fluent UI, GetX, Drift ORM

**Sources:** Flutter official performance docs (flutter.dev/perf), Flutter API docs (StatefulWidget best practices), Flutter state management guide, codebase audit of all files in lib/.

---

## File Map

| File | Issues | Phase |
|------|--------|-------|
| `lib/feature/app.dart` | Root Obx wraps entire app; nested Obx in main content; Get.find in build; Image rebuilt on theme change | 1 |
| `lib/core/resource/local_storage/local_storage.dart` | Hardcoded "token" key ignores caller's key (uses `GetStorage`, not SharedPreferences) | 1 |
| `lib/feature/proxy/controller/proxy_controller.dart` | O(N*M) getCurrentIpForSlot; getFilteredSlots creates 3 intermediate lists; clearAllProxyData sequential deletes | 1, 2, 4 |
| `lib/feature/proxy/controller/proxy_scoring_controller.dart` | Computed getters recompute O(N*M) on every Obx access | 1 |
| `lib/data/repositories/account_repository_impl.dart` | N+1 query in getAllAccounts() | 2 |
| `lib/feature/proxy/views/dialogs/add_slot_dialog.dart` | TextEditingControllers in build() of StatelessWidget | 2 |
| `lib/feature/proxy/views/sections/proxy_list_section.dart` | Obx rebuilds entire list on slot selection | 2 |
| `lib/feature/proxy/views/sections/proxy_detail_section.dart` | Single Obx wraps 4 independent components | 2 |
| `lib/feature/music/controller/music_controller.dart` | Stream subscriptions not stored or cancelled | 3 |
| `lib/config/services/onboarding_service.dart` | Duplicate ever() listeners on repeated calls | 3 |
| `lib/feature/app/views/dialogs/webshare_config_dialog.dart` | Rx observables + TextEditingController never disposed | 3 |
| `lib/feature/app/views/dialogs/ipqs_config_dialog.dart` | Same as above | 3 |
| `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart` | Same as above | 3 |
| `lib/feature/Status/views/sections/account_list_section.dart` | Eager Table build instead of ListView.builder | 3 |
| `lib/feature/main_menu/views/sections/system_overview_section.dart` | Reads observables without Obx — stale data | 3 |
| `lib/feature/main_menu/views/sections/characters_status_section.dart` | Same as above | 3 |
| `lib/domain/repositories/proxy_repository.dart` | Missing `softDeleteAllSlots()` interface method | 4 |
| `lib/data/repositories/proxy_repository_impl.dart` | Missing batch soft-delete implementation | 4 |

---

## Phase 1: Critical Fixes (widget rebuild storm + data bug)

### Task 1: Fix LocalStorage hardcoded key bug

**Files:**
- Modify: `lib/core/resource/local_storage/local_storage.dart:4-10`
- Test: manual — verify theme persists after restart

Both `set()` and `get()` use the hardcoded key `"token"` instead of the caller's `key` parameter. The app uses `GetStorage` (not SharedPreferences). Every write overwrites the same key; every read returns the same value regardless of key.

- [ ] **Step 1: Read the file and verify current state**

Current code (uses `GetStorage`):
```dart
import 'package:get_storage/get_storage.dart';

class LocalStorage {
  static Future<void> set({required String key, required dynamic value}) {
    return GetStorage().write("token", value); // BUG: ignores key parameter
  }
  static dynamic get({required String key}) {
    return GetStorage().read("token"); // BUG: ignores key parameter
  }
}
```

- [ ] **Step 2: Fix both methods to use the key parameter**

```dart
import 'package:get_storage/get_storage.dart';

class LocalStorage {
  static Future<void> set({required String key, required dynamic value}) {
    return GetStorage().write(key, value);
  }
  static dynamic get({required String key}) {
    return GetStorage().read(key);
  }
}
```

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/resource/local_storage/local_storage.dart
git commit -m "fix: use caller's key parameter in LocalStorage instead of hardcoded 'token'"
```

---

### Task 2: Break up root-level Obx in app.dart

**Files:**
- Modify: `lib/feature/app.dart:80-136` (root build), `lib/feature/app.dart:151-206` (nested Obx)

**Problem:** `Obx()` at line 83 wraps the entire `FluentApp` — title bar, navigation, all screen bodies. Observes `ThemeManage.currentThemeMode`. A second nested `Obx()` at line 154 wraps the entire `NavigationView` observing `onboardingService.isOnboardingComplete`. Toggling the theme rebuilds the entire app tree.

**Flutter best practice (flutter.dev/perf/best-practices):** "Place state listeners as deep in the tree as possible."

- [ ] **Step 1: Store MusicController reference after init, replace try-catch with null check**

In `_AppState`, add a nullable field and resolve once:

```dart
MusicController? _musicController;

Future<void> _initializeApp() async {
  AppBindings().dependencies();
  await AppBindings.initializeAsyncServices();

  // Resolve controller once after services are ready
  try {
    _musicController = Get.find<MusicController>();
  } catch (_) {}

  if (mounted) {
    setState(() => _initialized = true);
  }
}
```

Replace `_buildMusicButton()`:
```dart
Widget _buildMusicButton() {
  final mc = _musicController;
  if (mc == null) return const SizedBox.shrink();
  return Obx(() => IconButton(
        icon: Icon(
          mc.isPlaying.value
              ? FluentIcons.music_in_collection_fill
              : FluentIcons.music_note,
        ),
        onPressed: () {
          if (mc.isPlaying.value) {
            mc.pauseAudio();
          } else {
            mc.playAudio();
          }
        },
      ));
}
```

- [ ] **Step 2: Remove nested Obx in _buildMainContent**

The `onboardingService.isOnboardingComplete` Obx wraps the entire NavigationView. Since onboarding completes at most once per session and `_initialized` setState already triggers a rebuild, remove the inner Obx:

```dart
Widget _buildMainContent(bool isDark) {
  // Direct read — no Obx wrapper around NavigationView
  OnboardingService? onboardingService;
  bool needsOnboarding = false;
  try {
    onboardingService = Get.find<OnboardingService>();
    needsOnboarding = !onboardingService.isOnboardingComplete;
  } catch (_) {}

  return NavigationView(
    // ... same pane items using needsOnboarding ...
  );
}
```

**Note:** The onboarding completion transition still works because `OnboardingSection` has its own internal Obx bindings that update when the user completes setup steps. When all steps are done and the user navigates away/back, the `_buildMainContent` re-reads the value. If instant transition is desired, add a one-time `ever()` in `_initializeApp` that calls `setState`:

```dart
// Optional: instant transition when onboarding completes
try {
  final obs = Get.find<OnboardingService>();
  ever(obs.isWebshareConfigured, (_) {
    if (obs.isOnboardingComplete && mounted) setState(() {});
  });
} catch (_) {}
```

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/app.dart
git commit -m "perf: scope Obx wrappers in app.dart to minimize rebuild scope"
```

---

### Task 3: Cache getCurrentIpForSlot lookups with a Map

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_controller.dart:198-211`

**Problem:** `getCurrentIpForSlot(ProxySlotEntity slot)` does two linear O(M) scans of `ipAddresses` — first by `slot.currentIpAddressId` + `isActive`, then fallback by `slot.id` + `isActive`. It's called per slot in `getFilteredSlots()`, per slot in list builder, in detail section, and multiple times in scoring controller. Total: O(K*M) per rebuild.

**Important:** The method takes `ProxySlotEntity slot` (not `int slotId`). It has a two-step lookup: fast path via `slot.currentIpAddressId`, then fallback by `slotId`. The cache must replicate both.

- [ ] **Step 1: Add two cached lookup maps**

```dart
// Add to ProxyController fields
final _ipById = <int, ProxyIpAddressEntity>{};
final _activeIpBySlotId = <int, ProxyIpAddressEntity>{};

void _rebuildIpLookup() {
  _ipById.clear();
  _activeIpBySlotId.clear();
  for (final ip in ipAddresses) {
    _ipById[ip.id!] = ip;
    if (ip.isActive) {
      // Last active IP per slot wins (matches firstWhereOrNull behavior)
      _activeIpBySlotId.putIfAbsent(ip.slotId, () => ip);
    }
  }
}
```

- [ ] **Step 2: Call `_rebuildIpLookup()` at the end of `loadIpAddresses()`**

Add as the last line before closing the try block in `loadIpAddresses()`:
```dart
_rebuildIpLookup();
```

- [ ] **Step 3: Replace `getCurrentIpForSlot` body with O(1) lookup**

Preserve the same signature and two-step logic:
```dart
ProxyIpAddressEntity? getCurrentIpForSlot(ProxySlotEntity slot) {
  // Fast path: look up by currentIpAddressId
  if (slot.currentIpAddressId != null) {
    final ip = _ipById[slot.currentIpAddressId!];
    if (ip != null && ip.isActive) return ip;
  }
  // Fallback: first active IP for this slot
  return _activeIpBySlotId[slot.id];
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test
```
Expected: All existing proxy tests pass with O(1) lookups producing identical results.

- [ ] **Step 5: Commit**

```bash
git add lib/feature/proxy/controller/proxy_controller.dart
git commit -m "perf: cache getCurrentIpForSlot with Map lookups instead of O(M) linear scans"
```

---

### Task 4: Cache scoring controller computed getters

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_scoring_controller.dart:77-97`
- Modify: `lib/feature/proxy/views/sections/proxy_list_section.dart:83-91`
- Modify: `lib/feature/main_menu/views/sections/system_overview_section.dart:71-77`

**Problem:** `hasScoredIps`, `averageIpScore`, and `lowScoreCount` are plain Dart getters that iterate all proxySlots and call `getCurrentIpForSlot()` each time. They're called inside Obx blocks on every rebuild.

**Important:** The actual property names are `ip.ipScore` (not `ipqsScore`), `ip.hasBeenScored` (not `ipqsScore != null`), and the low-score threshold is `< 50` (not `>= 50`).

- [ ] **Step 1: Replace getters with cached observable values in proxy_scoring_controller.dart**

Remove lines 77-97 (the three getters). Add instead:

```dart
// --- Cached score statistics (lines 77+) ---
final hasScoredIps = false.obs;
final averageIpScore = 0.0.obs;
final lowScoreCount = 0.obs;
```

Add to `onInit()`, after the existing `ever(_ipqsService.isConfigured, ...)`:

```dart
// Recalculate stats whenever IP addresses change
ever(_proxyController.ipAddresses, (_) => _recalculateStats());
```

Add the recalculation method:

```dart
void _recalculateStats() {
  final slots = _proxyController.proxySlots;
  int scored = 0;
  double totalScore = 0;
  int lowCount = 0;

  for (final slot in slots) {
    final ip = _proxyController.getCurrentIpForSlot(slot);
    if (ip != null && ip.hasBeenScored) {
      scored++;
      totalScore += ip.ipScore;
      if (ip.ipScore < 50) lowCount++;
    }
  }

  hasScoredIps.value = scored > 0;
  averageIpScore.value = scored > 0 ? totalScore / scored : 0;
  lowScoreCount.value = lowCount;
}
```

**Note:** `getLowScoreSlotDetails()` (lines 100+) still iterates slots — leave it as-is since it's only called on tooltip hover, not per rebuild.

- [ ] **Step 2: Update all call sites to use `.value`**

In `proxy_list_section.dart` (lines 83-91), update the `_buildSummaryStats` Obx:
```dart
// Before:
value: scoringController.averageIpScore.toStringAsFixed(1),
color: getScoreColor(scoringController.averageIpScore,
    hasBeenScored: scoringController.hasScoredIps),
// ...
if (scoringController.lowScoreCount > 0)
  value: scoringController.lowScoreCount.toString(),

// After:
value: scoringController.averageIpScore.value.toStringAsFixed(1),
color: getScoreColor(scoringController.averageIpScore.value,
    hasBeenScored: scoringController.hasScoredIps.value),
// ...
if (scoringController.lowScoreCount.value > 0)
  value: scoringController.lowScoreCount.value.toString(),
```

In `system_overview_section.dart` (lines 71-77), update `_getIssuesCount`:
```dart
// Before:
return scoringController.lowScoreCount.toString();
// After:
return scoringController.lowScoreCount.value.toString();
```

- [ ] **Step 3: Run tests**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/proxy/controller/proxy_scoring_controller.dart \
        lib/feature/proxy/views/sections/proxy_list_section.dart \
        lib/feature/main_menu/views/sections/system_overview_section.dart
git commit -m "perf: cache scoring stats as observables instead of recomputing on every Obx access"
```

---

## Phase 2: Major Fixes (data layer + widget rebuild granularity)

### Task 5: Fix N+1 query in getAllAccounts

**Files:**
- Modify: `lib/data/repositories/account_repository_impl.dart:21-31`

**Problem:** For every account, a separate `_getCharactersForAccount(account.id)` query runs. With N accounts = N+1 DB queries.

- [ ] **Step 1: Replace with batch fetch — 2 queries total**

Replace the `getAllAccounts()` method (lines 21-31):

```dart
@override
Future<List<AccountEntity>> getAllAccounts() async {
  final accounts = await _db.select(_db.accountsTable).get();
  final allCharacters = await _db.select(_db.charactersTable).get();

  // Group characters by accountId for O(1) lookup
  final charsByAccountId = <int, List<CharacterEntity>>{};
  for (final charRow in allCharacters) {
    final entity = _mapCharacterRow(charRow);
    charsByAccountId.putIfAbsent(charRow.accountId, () => []).add(entity);
  }

  return accounts
      .map((a) => _mapAccountRow(a, charsByAccountId[a.id] ?? []))
      .toList();
}
```

**Note:** Uses existing `_mapCharacterRow()` and `_mapAccountRow()` methods (not `_mapCharacter`/`_mapAccount`). The `charRow.accountId` is the Drift-generated field from `CharactersTableData`.

- [ ] **Step 2: Run tests**

```bash
flutter test
```
Expected: All account-related tests pass unchanged.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/account_repository_impl.dart
git commit -m "perf: replace N+1 account query with batch character fetch (2 queries total)"
```

---

### Task 6: Convert AddSlotDialog to StatefulWidget for proper controller lifecycle

**Files:**
- Modify: `lib/feature/proxy/views/dialogs/add_slot_dialog.dart`

**Problem:** Four `TextEditingController` instances created inside `build()` of a `StatelessWidget`. Every rebuild creates new controllers (losing input) and they're never disposed.

- [ ] **Step 1: Read current file to verify field names**

Run: Read `lib/feature/proxy/views/dialogs/add_slot_dialog.dart`

- [ ] **Step 2: Convert to StatefulWidget**

Change class declaration and move controllers:

```dart
class AddSlotDialog extends StatefulWidget {
  final Function(String label, String host, String username, String password) onAdd;

  const AddSlotDialog({super.key, required this.onAdd});

  @override
  State<AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<AddSlotDialog> {
  final _labelController = TextEditingController();
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... move existing build body here, change onAdd to widget.onAdd ...
  }
}
```

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/proxy/views/dialogs/add_slot_dialog.dart
git commit -m "fix: convert AddSlotDialog to StatefulWidget for proper controller lifecycle"
```

---

### Task 7: Split proxy list Obx to avoid rebuilding all cards on selection change

**Files:**
- Modify: `lib/feature/proxy/views/sections/proxy_list_section.dart:170-215`
- Modify: `lib/feature/proxy/views/components/proxy_slot_card.dart`

**Problem:** Selecting a slot changes `selectedSlot`, which triggers the entire list Obx to rebuild — reconstructing every `ProxySlotCard`. Only the selected/deselected cards need to update their highlight.

**Approach:** Remove `selectedSlot` observation from the list-level Obx. Instead, have each `ProxySlotCard` internally observe `controller.selectedSlot` via a small Obx around just its border decoration. The list Obx only rebuilds when `proxySlots`/`ipAddresses`/`searchQuery`/`showOnlyActive` change.

- [ ] **Step 1: Modify ProxySlotCard to accept controller and observe selection internally**

In `proxy_slot_card.dart`, add a `ProxyController controller` parameter. Wrap the card's outer Container in a small Obx that only reads `controller.selectedSlot`:

```dart
class ProxySlotCard extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity? currentIp;
  final ProxyController controller; // NEW: replaces isSelected param
  final VoidCallback onSelect;
  final Function(ProxySlotEntity, String) onUpdateSlotName;

  const ProxySlotCard({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.controller,
    required this.onSelect,
    required this.onUpdateSlotName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Obx(() {
      final isSelected = controller.selectedSlot.value?.id == slot.id;
      return GestureDetector(
        onTap: onSelect,
        child: Container(
          // ... existing card content using isSelected for border highlight ...
        ),
      );
    });
  }
}
```

- [ ] **Step 2: Remove `selectedSlot` read from list-level Obx**

In `proxy_list_section.dart:170-215`, remove line 175 (`final _ = controller.selectedSlot.value;`) and change the `ProxySlotCard` constructor call:

```dart
// Before:
final isSelected = controller.selectedSlot.value?.id == slot.id;
return ProxySlotCard(
  slot: slot,
  currentIp: currentIp,
  isSelected: isSelected,
  onSelect: () => controller.selectSlot(slot),
  onUpdateSlotName: (s, name) => controller.updateSlotName(s, name),
);

// After:
return ProxySlotCard(
  slot: slot,
  currentIp: currentIp,
  controller: controller,
  onSelect: () => controller.selectSlot(slot),
  onUpdateSlotName: (s, name) => controller.updateSlotName(s, name),
);
```

- [ ] **Step 3: Run tests**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/proxy/views/sections/proxy_list_section.dart \
        lib/feature/proxy/views/components/proxy_slot_card.dart
git commit -m "perf: move selection observation into ProxySlotCard to avoid full list rebuild on select"
```

**Note on proxy_detail_section.dart:** The single Obx wrapping SlotHeader, CurrentIpCard, IpScoreAnalysis, and IpHistoryList all depend on `controller.selectedSlot` and `controller.getCurrentIpForSlot()` which change together (selecting a new slot). Splitting into per-component Obx blocks would NOT reduce rebuilds since all four observe the same data source. Leave the detail section as-is — the real win is the list optimization above.

---

### Task 8: Optimize getFilteredSlots to avoid intermediate list copies

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_controller.dart:223-251`

**Problem:** Creates up to 3 intermediate `.toList()` copies per call. The `sortByScore` step also calls `getCurrentIpForSlot()` twice per comparison (now O(1) after Task 3).

- [ ] **Step 1: Chain filters with lazy Iterable, materialize once**

Replace `getFilteredSlots` (lines 223-251):

```dart
List<ProxySlotEntity> getFilteredSlots({bool sortByScore = false}) {
  Iterable<ProxySlotEntity> result = proxySlots;

  if (showOnlyActive.value) {
    result = result.where((slot) => slot.isActive);
  }

  if (searchQuery.value.isNotEmpty) {
    final query = searchQuery.value.toLowerCase();
    result = result.where((slot) {
      final ip = getCurrentIpForSlot(slot);
      return slot.slotName.toLowerCase().contains(query) ||
          slot.slotNumber.toString().contains(query) ||
          (ip?.ipAddress.contains(query) ?? false) ||
          (ip?.cityName.toLowerCase().contains(query) ?? false) ||
          (ip?.countryCode.toLowerCase().contains(query) ?? false);
    });
  }

  final list = result.toList(); // Single materialization

  if (sortByScore) {
    list.sort((a, b) {
      final ipA = getCurrentIpForSlot(a);
      final ipB = getCurrentIpForSlot(b);
      return (ipB?.ipScore ?? 0).compareTo(ipA?.ipScore ?? 0);
    });
  }

  return list;
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add lib/feature/proxy/controller/proxy_controller.dart
git commit -m "perf: use lazy Iterable chaining in getFilteredSlots instead of 3 intermediate lists"
```

---

## Phase 3: Medium Fixes (memory leaks + reactive correctness)

### Task 9: Store and cancel MusicController stream subscriptions

**Files:**
- Modify: `lib/feature/music/controller/music_controller.dart:20-29`

**Problem:** Three `.listen()` calls return `StreamSubscription` objects that are not stored. Cannot be cancelled in `onClose()`. While `audioPlayer.dispose()` likely cleans up the underlying streams, callbacks can fire during the dispose window.

- [ ] **Step 1: Read current file to identify the three listen calls**

Run: Read `lib/feature/music/controller/music_controller.dart`

- [ ] **Step 2: Store subscriptions and cancel in onClose**

Add fields and update `onInit`/`onClose`:

```dart
import 'dart:async';
// ... existing imports ...

class MusicController extends GetxController {
  // ... existing fields ...
  late final StreamSubscription _stateSubscription;
  late final StreamSubscription _positionSubscription;
  late final StreamSubscription _durationSubscription;

  @override
  void onInit() {
    super.onInit();
    _stateSubscription = audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });
    _positionSubscription = audioPlayer.onPositionChanged.listen((pos) {
      currentPosition.value = pos;
    });
    _durationSubscription = audioPlayer.onDurationChanged.listen((dur) {
      totalDuration.value = dur;
    });
    // ... rest of existing onInit ...
  }

  @override
  void onClose() {
    _stateSubscription.cancel();
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    audioPlayer.dispose();
    super.onClose();
  }
}
```

- [ ] **Step 3: Run tests and commit**

```bash
flutter test
dart analyze
git add lib/feature/music/controller/music_controller.dart
git commit -m "fix: store and cancel MusicController stream subscriptions to prevent leaks"
```

---

### Task 10: Prevent duplicate ever() listeners in OnboardingService

**Files:**
- Modify: `lib/config/services/onboarding_service.dart:46,63,82`

**Problem:** `checkOnboardingStatus()` can be called multiple times. Each call registers new `ever()` listeners without cancelling previous ones.

- [ ] **Step 1: Read current file to confirm ever() locations**

Run: Read `lib/config/services/onboarding_service.dart`

- [ ] **Step 2: Guard with a workers list, cancel before re-registering**

```dart
final List<Worker> _workers = [];

Future<void> checkOnboardingStatus() async {
  // Cancel previous listeners to prevent duplicates
  for (final w in _workers) {
    w.dispose();
  }
  _workers.clear();

  // ... existing logic that checks services and registers ever() ...
  // Replace each `ever(...)` call with `_workers.add(ever(...))`:
  _workers.add(ever(webshareService.apiKey, (_) => _saveWebshareConfigured()));
  _workers.add(ever(ipqsService.apiKey, (_) => _saveIpqsConfigured()));
  // ... etc for any other ever() calls in this method ...
}
```

- [ ] **Step 3: Run tests and commit**

```bash
flutter test
git add lib/config/services/onboarding_service.dart
git commit -m "fix: cancel previous ever() listeners in OnboardingService before re-registering"
```

---

### Task 11: Convert dialog static show() methods to StatefulWidgets for proper disposal

**Files:**
- Modify: `lib/feature/app/views/dialogs/webshare_config_dialog.dart`
- Modify: `lib/feature/app/views/dialogs/ipqs_config_dialog.dart`
- Modify: `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart`

**Problem:** Rx observables and TextEditingControllers are created in static `show()` methods and never disposed. Each dialog open/close leaks memory.

All three dialogs follow the same pattern: `ClassName._()` private constructor, static `show()` method that creates local state and calls `showDialog()`. The fix is the same for each.

- [ ] **Step 1: Convert WebshareConfigDialog as template**

Before (current pattern):
```dart
class WebshareConfigDialog {
  WebshareConfigDialog._();
  static void show(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final statusMessage = Rxn<String>();
    final isError = false.obs;
    // ... showDialog with builder using these locals ...
  }
}
```

After:
```dart
class WebshareConfigDialog extends StatefulWidget {
  const WebshareConfigDialog._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const WebshareConfigDialog._(),
    );
  }

  @override
  State<WebshareConfigDialog> createState() => _WebshareConfigDialogState();
}

class _WebshareConfigDialogState extends State<WebshareConfigDialog> {
  final _apiKeyController = TextEditingController();
  final _isProcessing = false.obs;
  final _statusMessage = Rxn<String>();
  final _isError = false.obs;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _isProcessing.close();
    _statusMessage.close();
    _isError.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Move the ContentDialog that was previously in the showDialog builder
    // Replace local variable references with _field references
    // Replace static helper methods with instance methods
    bool isConfigured = false;
    try {
      isConfigured = Get.find<WebshareService>().isConfigured.value;
    } catch (_) {}

    return ContentDialog(
      title: Text(isConfigured ? 'Webshare Configuration' : 'Configure Webshare'),
      content: Obx(() => Column(
        // ... existing dialog content, using _isProcessing, _statusMessage, etc. ...
      )),
      // ... existing actions ...
    );
  }

  // Move _handleConnect, _handleUnlink etc. from static to instance methods
  Future<void> _handleConnect(BuildContext context) async { /* ... */ }
  Future<void> _handleUnlink(BuildContext context) async { /* ... */ }
}
```

- [ ] **Step 2: Apply same pattern to IpqsConfigDialog and IpqsOnboardingDialog**

Each dialog has different state fields. Read each file, identify locals in `show()`, move to state class with dispose.

- [ ] **Step 3: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/app/views/dialogs/webshare_config_dialog.dart \
        lib/feature/app/views/dialogs/ipqs_config_dialog.dart \
        lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart
git commit -m "fix: convert dialog static methods to StatefulWidgets for proper disposal"
```

---

### Task 12: Wrap dashboard sections in Obx for reactive updates

**Files:**
- Modify: `lib/feature/main_menu/views/sections/system_overview_section.dart:30-50`
- Modify: `lib/feature/main_menu/views/sections/characters_status_section.dart:20-40`

**Problem:** These widgets call `Get.find<StatusController>().accountList.length` and similar observable reads inside `build()` without `Obx()`. Data is stale until navigation away/back.

- [ ] **Step 1: Read both files to confirm the widget structure**

Run: Read both files.

- [ ] **Step 2: In system_overview_section.dart, wrap the stats Row in Obx**

The `_getAccountCount()`, `_getProxyCount()`, `_getIssuesCount()` helpers read observables via `Get.find`. Wrap the Row that calls `_buildStatCard` (which uses these helpers) in Obx so it reactively updates:

```dart
@override
Widget build(BuildContext context) {
  return Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... static title row ...
        const SizedBox(height: 16),
        Obx(() => Row(
              children: [
                Expanded(
                  child: _buildStatCard(context,
                      icon: FluentIcons.contact, label: 'Accounts', value: _getAccountCount()),
                ),
                // ... other stat cards ...
              ],
            )),
      ],
    ),
  );
}
```

- [ ] **Step 3: In characters_status_section.dart, wrap the data-dependent part in Obx**

Same approach: wrap the section that reads `Get.find<StatusController>().accountList` in Obx.

- [ ] **Step 4: Run tests and commit**

```bash
flutter test
dart analyze
git add lib/feature/main_menu/views/sections/system_overview_section.dart \
        lib/feature/main_menu/views/sections/characters_status_section.dart
git commit -m "fix: wrap dashboard sections in Obx for reactive data updates"
```

---

### Task 13: Replace eager Table in AccountListSection with ListView.builder

**Files:**
- Modify: `lib/feature/Status/views/sections/account_list_section.dart:35-94`

**Problem:** Uses `Table` with `...controller.accountList.expand(...)`, eagerly building all rows. With `IntrinsicColumnWidth`, Flutter must measure every cell.

- [ ] **Step 1: Flatten account/character data into a list of rows, use ListView.builder**

The current table expands accounts into rows — accounts with no characters get 1 row, accounts with N characters get N rows. Pre-compute this flat list, then use ListView.builder:

```dart
Widget _buildAccountsTable(BuildContext context) {
  final theme = FluentTheme.of(context);

  // Flatten accounts into displayable rows
  final rows = <_AccountRow>[];
  for (final account in controller.accountList) {
    if (account.characters.isEmpty) {
      rows.add(_AccountRow(account: account, character: null));
    } else {
      for (final character in account.characters) {
        rows.add(_AccountRow(account: account, character: character));
      }
    }
  }

  // Column widths
  const columns = ['Account Name', 'Email', 'Password', 'Character', 'Proxy', 'Status', 'Actions'];

  return Column(
    children: [
      // Fixed header
      Container(
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: 0.1),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: Row(
          children: columns.map((c) => Expanded(child: _buildTableHeader(c))).toList(),
        ),
      ),
      // Virtualized rows
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTableCell(row.account.accountName)),
                  Expanded(child: _buildTableCellWithCopy(context, row.account.email)),
                  Expanded(child: _buildTableCellWithCopy(context, row.account.password)),
                  Expanded(child: _buildTableCell(row.character?.name ?? '\u2014')),
                  Expanded(child: _buildTableCell(row.account.proxyAddress)),
                  Expanded(child: ProcessStatusBadge(
                    isRunning: row.character != null &&
                        controller.processClients.containsKey(row.character!.name),
                  )),
                  Expanded(child: row.character != null
                      ? _buildActionsCell(context, row.account, row.character!,
                          controller.processClients.containsKey(row.character!.name))
                      : _buildEmptyAccountActions(context, row.account)),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

// Helper class at bottom of file
class _AccountRow {
  final JagexAccount account;
  final Character? character;
  const _AccountRow({required this.account, this.character});
}
```

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
dart analyze
git add lib/feature/Status/views/sections/account_list_section.dart
git commit -m "perf: replace eager Table with ListView.builder in AccountListSection"
```

---

## Phase 4: Low-priority Polish

### Task 14: Batch clearAllProxyData into single SQL statement

**Files:**
- Modify: `lib/domain/repositories/proxy_repository.dart` (add interface method)
- Modify: `lib/data/repositories/proxy_repository_impl.dart` (add implementation)
- Modify: `lib/feature/proxy/controller/proxy_controller.dart:159-181`

**Problem:** Sequential `await softDeleteSlot()` per slot. 30 slots = 30 DB round-trips.

- [ ] **Step 1: Add `softDeleteAllSlots()` to the abstract ProxyRepository interface**

In `lib/domain/repositories/proxy_repository.dart`, add after `softDeleteSlot`:

```dart
/// Soft-delete all active slots in a single batch operation
Future<void> softDeleteAllSlots();
```

- [ ] **Step 2: Implement in ProxyRepositoryImpl**

In `lib/data/repositories/proxy_repository_impl.dart`, add:

```dart
@override
Future<void> softDeleteAllSlots() async {
  await (_db.update(_db.proxySlotsTable)
        ..where((t) => t.isDeleted.equals(false)))
      .write(const ProxySlotsTableCompanion(isDeleted: Value(true)));
}
```

- [ ] **Step 3: Use in clearAllProxyData**

In `proxy_controller.dart`, replace the `for (final slot in allSlots)` loop with:

```dart
await _proxyRepository!.softDeleteAllSlots();
```

- [ ] **Step 4: Run tests and commit**

```bash
flutter test
dart analyze
git add lib/domain/repositories/proxy_repository.dart \
        lib/data/repositories/proxy_repository_impl.dart \
        lib/feature/proxy/controller/proxy_controller.dart
git commit -m "perf: batch soft-delete all proxy slots in single SQL statement"
```

---

### Task 15: Resolve Get.find() calls in build methods

**Files (all StatelessWidgets — accept controller via constructor):**
- Modify: `lib/feature/proxy/views/components/slot_header.dart:168`
- Modify: `lib/feature/notification/views/components/notification_bell.dart:15`
- Modify: `lib/feature/main_menu/views/sections/system_overview_section.dart:55-82`
- Modify: `lib/feature/main_menu/views/sections/characters_status_section.dart:53`
- Modify: `lib/feature/app/views/sections/settings_section.dart:85-187`
- Modify: `lib/feature/app/views/sections/auto_rotation_settings.dart:14`

**Problem:** `Get.find<>()` performs hash-map lookup on every rebuild. Should be resolved once.

- [ ] **Step 1: For each file, read to identify which Get.find calls are in build/helper methods**

- [ ] **Step 2: Add constructor parameters for each needed controller/service**

Example for `notification_bell.dart`:
```dart
// Before:
class NotificationBell extends StatelessWidget {
  final FlyoutController flyoutController;
  const NotificationBell({super.key, required this.flyoutController});

  @override
  Widget build(BuildContext context) {
    final notificationService = Get.find<NotificationService>(); // REMOVE
    // ...
  }
}

// After:
class NotificationBell extends StatelessWidget {
  final FlyoutController flyoutController;
  final NotificationService notificationService;
  const NotificationBell({
    super.key,
    required this.flyoutController,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    // Use this.notificationService directly
  }
}
```

- [ ] **Step 3: Update all call sites to pass the controller**

Each widget's parent must pass the service/controller. Since parents typically already have access (via their own constructor or Get.find in initState), this just moves the lookup earlier.

- [ ] **Step 4: Run tests and commit**

```bash
flutter test
dart analyze
git add lib/feature/proxy/views/components/slot_header.dart \
        lib/feature/notification/views/components/notification_bell.dart \
        lib/feature/main_menu/views/sections/system_overview_section.dart \
        lib/feature/main_menu/views/sections/characters_status_section.dart \
        lib/feature/app/views/sections/settings_section.dart \
        lib/feature/app/views/sections/auto_rotation_settings.dart
git commit -m "perf: resolve GetX controller references once instead of per-build lookup"
```

---

## Verification

After each phase:
1. `flutter test` — all tests pass
2. `dart analyze` — no issues
3. `dart format --set-exit-if-changed .` — properly formatted
4. Manual testing:
   - **Phase 1:** Toggle theme rapidly — verify no jank; check theme persists after restart
   - **Phase 2:** Load 50+ proxy slots — verify smooth scrolling; select slots — verify only highlight changes
   - **Phase 3:** Open/close dialogs 10 times — verify no memory growth; check dashboard updates live
   - **Phase 4:** Clear all proxy data — verify instant completion

## Key Metrics to Watch

| Metric | Before | Target |
|--------|--------|--------|
| Root Obx rebuild scope | Entire app | Theme wrapper only |
| getCurrentIpForSlot | O(M) linear scan per call | O(1) map lookup |
| Scoring stats computation | O(K*M) per Obx rebuild | Cached, event-driven |
| getAllAccounts queries | N+1 | 2 (accounts + characters) |
| Dialog memory per open/close | Leaks Rx + controllers | Zero leaks |
| getFilteredSlots list copies | 3 intermediate | 1 final |
| Proxy slot selection rebuild | All cards rebuilt | Only 2 cards (old + new selection) |

## Key References

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices) — "control build cost", "apply effects only when needed"
- [Flutter StatefulWidget docs](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html) — "push state to leaves", "cache subtrees"
- [Flutter State Management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) — "place consumers as deep as possible"
- [Flutter Isolates](https://docs.flutter.dev/perf/isolates) — "use for computation >16ms"
