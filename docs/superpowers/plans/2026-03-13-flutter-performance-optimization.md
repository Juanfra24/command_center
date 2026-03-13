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
| `lib/core/resource/local_storage/local_storage.dart` | Hardcoded "token" key ignores caller's key | 1 |
| `lib/feature/proxy/controller/proxy_controller.dart` | O(N*M) getCurrentIpForSlot; getFilteredSlots creates 3 intermediate lists; clearAllProxyData sequential deletes | 1, 2 |
| `lib/feature/proxy/controller/proxy_scoring_controller.dart` | Computed getters recompute O(N*M) on every Obx access | 1 |
| `lib/data/repositories/account_repository_impl.dart` | N+1 query in getAllAccounts() | 2 |
| `lib/feature/proxy/views/dialogs/add_slot_dialog.dart` | TextEditingControllers in build() of StatelessWidget | 2 |
| `lib/feature/proxy/views/sections/proxy_list_section.dart` | Obx rebuilds entire list on slot selection; missing itemExtent | 2 |
| `lib/feature/proxy/views/sections/proxy_detail_section.dart` | Single Obx wraps 4 independent components | 2 |
| `lib/feature/music/controller/music_controller.dart` | Stream subscriptions not stored or cancelled | 3 |
| `lib/config/services/onboarding_service.dart` | Duplicate ever() listeners on repeated calls | 3 |
| `lib/feature/app/views/dialogs/webshare_config_dialog.dart` | Rx observables + TextEditingController never disposed | 3 |
| `lib/feature/app/views/dialogs/ipqs_config_dialog.dart` | Same as above | 3 |
| `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart` | Same as above | 3 |
| `lib/feature/Status/views/sections/account_list_section.dart` | Eager Table build instead of ListView.builder | 3 |
| `lib/feature/main_menu/views/sections/system_overview_section.dart` | Reads observables without Obx — stale data | 3 |
| `lib/feature/main_menu/views/sections/characters_status_section.dart` | Same as above | 3 |
| `lib/feature/Status/controller/status_controller.dart` | accountList full replacement triggers full rebuild | 4 |

---

## Phase 1: Critical Fixes (widget rebuild storm + data bug)

### Task 1: Fix LocalStorage hardcoded key bug

**Files:**
- Modify: `lib/core/resource/local_storage/local_storage.dart:4-10`
- Test: manual — verify theme persists after restart

Both `set()` and `get()` use the hardcoded key `"token"` instead of the caller's `key` parameter. Every write overwrites the same key; every read returns the same value regardless of key.

- [ ] **Step 1: Read the file and understand current state**

Current code (lines 4-10):
```dart
static Future<void> set({required String key, required String value}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString("token", value); // BUG: ignores key parameter
}
static Future<String?> get({required String key}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString("token"); // BUG: ignores key parameter
}
```

- [ ] **Step 2: Fix both methods to use the key parameter**

```dart
static Future<void> set({required String key, required String value}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString(key, value);
}
static Future<String?> get({required String key}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/resource/local_storage/local_storage.dart
git commit -m "fix: use caller's key parameter in LocalStorage instead of hardcoded 'token'"
```

---

### Task 2: Break up root-level Obx in app.dart

**Files:**
- Modify: `lib/feature/app.dart:80-136` (root build), `lib/feature/app.dart:151-206` (nested Obx in _buildMainContent)

**Problem:** A single `Obx()` at line 83 wraps the entire `FluentApp` — title bar, navigation, all screen bodies. It observes `ThemeManage.currentThemeMode`. A second nested `Obx()` at line 154 wraps the entire `NavigationView` observing `onboardingService.isOnboardingComplete`. Toggling the theme or completing onboarding rebuilds the entire app tree.

**Flutter best practice (flutter.dev/perf/best-practices):** "Place state listeners as deep in the tree as possible." Use `Obx()` wrapping only the smallest widget that depends on the observable.

- [ ] **Step 1: Refactor root build to scope theme Obx narrowly**

Instead of wrapping the entire FluentApp in Obx, only observe theme where it's needed:
- Pass `ThemeManage.currentThemeMode` to FluentApp via a small Obx wrapper around just the theme-related properties.
- Move the title bar, navigation, and screen bodies outside the Obx.

The key insight: `FluentApp` needs `themeMode`, `theme`, and `darkTheme` — wrap only the FluentApp widget itself, and use `const` or cached widgets for children that don't depend on theme.

```dart
@override
Widget build(BuildContext context) {
  return Obx(() {
    final isDark = ThemeManage.currentThemeMode == ThemeMode.dark;
    return FluentApp(
      themeMode: ThemeManage.currentThemeMode,
      theme: FluentAppTheme.lightTheme(),
      darkTheme: FluentAppTheme.darkTheme(),
      home: _buildHome(isDark),
    );
  });
}
```

This is currently what we have — the issue is `_buildHome` reconstructs the entire Column/WindowTitleBar/NavigationView tree. The fix is to cache the static parts:

- [ ] **Step 2: Cache static children and extract music/theme toggle to StatefulWidget fields**

```dart
// In _AppState, store references to static widgets
late final Widget _musicButton;

@override
void initState() {
  super.initState();
  windowManager.addListener(this);
  _initializeApp();
}
```

Move `_buildMusicButton()` try-catch out of build — resolve the controller once in `_initializeApp()` after services are ready, store result. Replace exception-based control flow with null check.

- [ ] **Step 3: Remove nested Obx in _buildMainContent**

The `onboardingService.isOnboardingComplete` check wraps the entire NavigationView. Since onboarding status changes at most once per session, replace the inner Obx with a direct check that only rebuilds when `_initialized` state changes (already handled by setState):

```dart
Widget _buildMainContent(bool isDark) {
  OnboardingService? onboardingService;
  bool needsOnboarding = false;
  try {
    onboardingService = Get.find<OnboardingService>();
    needsOnboarding = !onboardingService.isOnboardingComplete;
  } catch (_) {}

  return NavigationView(
    // ... items using needsOnboarding
  );
}
```

Remove the `Obx()` wrapper. The onboarding transition is already handled by the `OnboardingSection` widget which has its own reactive bindings.

- [ ] **Step 4: Run tests and verify**

```bash
flutter test
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/feature/app.dart
git commit -m "perf: scope Obx wrappers in app.dart to minimize rebuild scope"
```

---

### Task 3: Cache getCurrentIpForSlot lookups with a Map

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_controller.dart:201-211`

**Problem:** `getCurrentIpForSlot(int slotId)` does a linear O(M) scan of all `ipAddresses` using `firstWhereOrNull`. It's called: once per slot in `getFilteredSlots()`, once per slot in list item builder, once in detail section, and multiple times in scoring controller stats. Total: O(K*M) per rebuild where K=slots, M=IPs.

**Flutter best practice:** Never do expensive computation in build methods. Pre-compute and cache.

- [ ] **Step 1: Add a cached IP lookup map**

Add a `Map<int, ProxyIpAddressEntity>` field that maps slotId to current IP. Rebuild it whenever `ipAddresses` changes (in `loadIpAddresses()`).

```dart
final _currentIpBySlotId = <int, ProxyIpAddressEntity>{};

void _rebuildIpLookup() {
  _currentIpBySlotId.clear();
  for (final ip in ipAddresses) {
    if (ip.isCurrent) {
      _currentIpBySlotId[ip.proxySlotId] = ip;
    }
  }
}
```

- [ ] **Step 2: Call `_rebuildIpLookup()` at the end of `loadIpAddresses()`**

- [ ] **Step 3: Replace `getCurrentIpForSlot` body with O(1) lookup**

```dart
ProxyIpAddressEntity? getCurrentIpForSlot(int slotId) {
  return _currentIpBySlotId[slotId];
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/feature/proxy/controller/proxy_controller.dart
git commit -m "perf: cache getCurrentIpForSlot with Map lookup instead of O(M) linear scan"
```

---

### Task 4: Cache scoring controller computed getters

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_scoring_controller.dart:77-97`

**Problem:** `hasScoredIps`, `averageIpScore`, and `lowScoreCount` are plain Dart getters that iterate all proxySlots and call `getCurrentIpForSlot()` each time. They're called from Obx in the proxy list section on every rebuild.

- [ ] **Step 1: Convert to cached observable values**

Replace the getters with `.obs` fields that are recalculated via an `ever()` listener on the proxy controller's `ipAddresses`:

```dart
final hasScoredIps = false.obs;
final averageIpScore = 0.0.obs;
final lowScoreCount = 0.obs;

@override
void onInit() {
  super.onInit();
  ever(_proxyController.ipAddresses, (_) => _recalculateStats());
}

void _recalculateStats() {
  final slots = _proxyController.proxySlots;
  int scored = 0;
  double totalScore = 0;
  int lowCount = 0;

  for (final slot in slots) {
    final ip = _proxyController.getCurrentIpForSlot(slot.id!);
    if (ip?.ipqsScore != null) {
      scored++;
      totalScore += ip!.ipqsScore!;
      if (ip.ipqsScore! >= 50) lowCount++;
    }
  }

  hasScoredIps.value = scored > 0;
  averageIpScore.value = scored > 0 ? totalScore / scored : 0;
  lowScoreCount.value = lowCount;
}
```

- [ ] **Step 2: Update references in proxy_list_section.dart**

Change `scoringController.averageIpScore` to `scoringController.averageIpScore.value`, etc.

- [ ] **Step 3: Run tests**

```bash
flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/proxy/controller/proxy_scoring_controller.dart lib/feature/proxy/views/sections/proxy_list_section.dart
git commit -m "perf: cache scoring stats as observables instead of recomputing on every Obx access"
```

---

## Phase 2: Major Fixes (data layer + widget rebuild granularity)

### Task 5: Fix N+1 query in getAllAccounts

**Files:**
- Modify: `lib/data/repositories/account_repository_impl.dart:21-31`

**Problem:** For every account, a separate `_getCharactersForAccount(account.id)` query runs. With N accounts = N+1 DB queries.

- [ ] **Step 1: Replace with a single JOIN query or batch fetch**

Option A (batch): Load all characters in one query, group by accountId in Dart:

```dart
Future<List<AccountEntity>> getAllAccounts() async {
  final accounts = await _db.select(_db.accountsTable).get();
  final allCharacters = await _db.select(_db.charactersTable).get();

  final charsByAccountId = <int, List<CharacterEntity>>{};
  for (final char in allCharacters) {
    charsByAccountId.putIfAbsent(char.accountId, () => []).add(_mapCharacter(char));
  }

  return accounts.map((a) => _mapAccount(a, charsByAccountId[a.id] ?? [])).toList();
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/account_repository_impl.dart
git commit -m "perf: replace N+1 account query with batch character fetch"
```

---

### Task 6: Convert AddSlotDialog to StatefulWidget for proper controller lifecycle

**Files:**
- Modify: `lib/feature/proxy/views/dialogs/add_slot_dialog.dart`

**Problem:** Four `TextEditingController` instances created inside `build()` of a `StatelessWidget`. Every rebuild creates new controllers (losing input) and they're never disposed.

- [ ] **Step 1: Convert to StatefulWidget**

Move controller creation to `initState()`, add `dispose()`:

```dart
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
  // ...
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test
dart analyze
```

- [ ] **Step 3: Commit**

```bash
git add lib/feature/proxy/views/dialogs/add_slot_dialog.dart
git commit -m "fix: convert AddSlotDialog to StatefulWidget for proper controller lifecycle"
```

---

### Task 7: Split proxy list and detail Obx blocks for granular rebuilds

**Files:**
- Modify: `lib/feature/proxy/views/sections/proxy_list_section.dart:171-214`
- Modify: `lib/feature/proxy/views/sections/proxy_detail_section.dart:37-87`

**Problem (list):** Selecting a slot triggers `selectedSlot` change, which rebuilds the entire list via the Obx in `_buildSlotList`. Only the highlight of the old and new selected card needs to change.

**Problem (detail):** A single Obx wraps SlotHeader, CurrentIpCard, IpScoreAnalysis, and IpHistoryList. Scoring one IP rebuilds all four.

- [ ] **Step 1: In proxy_list_section, move selection highlight into ProxySlotCard**

Each `ProxySlotCard` should observe `controller.selectedSlot` individually so only the affected cards rebuild:

```dart
// In ProxySlotCard
Obx(() {
  final isSelected = controller.selectedSlot.value?.id == slot.id;
  return Container(
    decoration: BoxDecoration(
      border: isSelected ? Border.all(color: theme.accentColor) : null,
    ),
    child: _buildCardContent(), // Static content, not rebuilt
  );
})
```

- [ ] **Step 2: In proxy_detail_section, split into separate Obx per sub-component**

```dart
Column(
  children: [
    Obx(() => SlotHeader(slot: controller.selectedSlot.value!)),
    Obx(() => CurrentIpCard(ip: controller.getCurrentIpForSlot(...))),
    Obx(() => IpScoreAnalysis(ip: controller.getCurrentIpForSlot(...))),
    Obx(() => IpHistoryList(history: controller.selectedSlotIpHistory)),
  ],
)
```

- [ ] **Step 3: Run tests**

```bash
flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/feature/proxy/views/sections/proxy_list_section.dart \
        lib/feature/proxy/views/sections/proxy_detail_section.dart
git commit -m "perf: split Obx blocks in proxy list and detail for granular rebuilds"
```

---

### Task 8: Optimize getFilteredSlots to avoid intermediate list copies

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_controller.dart:223-251`

**Problem:** Creates up to 3 intermediate `.toList()` copies and calls `getCurrentIpForSlot()` per slot during search (now O(1) after Task 3, but still creates unnecessary lists).

- [ ] **Step 1: Chain filters with Iterable (lazy) and call .toList() once at the end**

```dart
List<ProxySlotEntity> getFilteredSlots({bool? showOnlyActive, String? searchQuery}) {
  Iterable<ProxySlotEntity> result = proxySlots;

  if (showOnlyActive == true) {
    result = result.where((s) => !s.isDeleted);
  }

  final query = searchQuery?.toLowerCase().trim() ?? '';
  if (query.isNotEmpty) {
    result = result.where((slot) {
      final ip = getCurrentIpForSlot(slot.id!);
      return slot.label.toLowerCase().contains(query) ||
          (ip?.ipAddress.toLowerCase().contains(query) ?? false);
    });
  }

  return result.toList();
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add lib/feature/proxy/controller/proxy_controller.dart
git commit -m "perf: use lazy Iterable chaining in getFilteredSlots instead of intermediate lists"
```

---

## Phase 3: Medium Fixes (memory leaks + reactive correctness)

### Task 9: Store and cancel MusicController stream subscriptions

**Files:**
- Modify: `lib/feature/music/controller/music_controller.dart:20-29`

**Problem:** Three `.listen()` calls return `StreamSubscription` objects that are not stored. Cannot be cancelled in `onClose()`.

- [ ] **Step 1: Store subscriptions and cancel in onClose**

```dart
late final StreamSubscription _stateSubscription;
late final StreamSubscription _positionSubscription;
late final StreamSubscription _durationSubscription;

@override
void onInit() {
  super.onInit();
  _stateSubscription = audioPlayer.onPlayerStateChanged.listen((state) { ... });
  _positionSubscription = audioPlayer.onPositionChanged.listen((pos) { ... });
  _durationSubscription = audioPlayer.onDurationChanged.listen((dur) { ... });
}

@override
void onClose() {
  _stateSubscription.cancel();
  _positionSubscription.cancel();
  _durationSubscription.cancel();
  audioPlayer.dispose();
  super.onClose();
}
```

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/feature/music/controller/music_controller.dart
git commit -m "fix: store and cancel MusicController stream subscriptions to prevent leaks"
```

---

### Task 10: Prevent duplicate ever() listeners in OnboardingService

**Files:**
- Modify: `lib/config/services/onboarding_service.dart:46,63,82`

**Problem:** `checkOnboardingStatus()` can be called multiple times. Each call registers new `ever()` listeners without cancelling previous ones, resulting in duplicate subscriptions.

- [ ] **Step 1: Guard with a flag or cancel previous Workers**

```dart
final List<Worker> _workers = [];

Future<void> checkOnboardingStatus() async {
  // Cancel previous listeners
  for (final w in _workers) {
    w.dispose();
  }
  _workers.clear();

  // ... existing logic ...
  _workers.add(ever(webshareService.apiKey, (_) => _saveWebshareConfigured()));
  // ...
}
```

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/config/services/onboarding_service.dart
git commit -m "fix: cancel previous ever() listeners in OnboardingService before re-registering"
```

---

### Task 11: Convert dialog static show() methods to use StatefulWidget for proper disposal

**Files:**
- Modify: `lib/feature/app/views/dialogs/webshare_config_dialog.dart`
- Modify: `lib/feature/app/views/dialogs/ipqs_config_dialog.dart`
- Modify: `lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart`

**Problem:** Rx observables (`false.obs`, `Rxn<String>()`) and `TextEditingController` are created in static `show()` methods and never disposed. Each dialog open/close leaks memory.

- [ ] **Step 1: Move state into StatefulWidget with proper dispose**

Convert each dialog to a StatefulWidget. Create Rx values and TextEditingControllers in `initState()`, dispose in `dispose()`.

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/feature/app/views/dialogs/webshare_config_dialog.dart \
        lib/feature/app/views/dialogs/ipqs_config_dialog.dart \
        lib/feature/app/views/dialogs/ipqs_onboarding_dialog.dart
git commit -m "fix: convert dialog static methods to StatefulWidgets for proper disposal"
```

---

### Task 12: Wrap dashboard sections in Obx for reactive updates

**Files:**
- Modify: `lib/feature/main_menu/views/sections/system_overview_section.dart:53-88`
- Modify: `lib/feature/main_menu/views/sections/characters_status_section.dart:51-73`

**Problem:** These widgets read observable values (`.length`, `.value`) inside `build()` without `Obx()`, so they show stale data until the user navigates away and back.

- [ ] **Step 1: Wrap the data-dependent parts in Obx**

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/feature/main_menu/views/sections/system_overview_section.dart \
        lib/feature/main_menu/views/sections/characters_status_section.dart
git commit -m "fix: wrap dashboard sections in Obx for reactive data updates"
```

---

### Task 13: Replace eager Table in AccountListSection with ListView.builder

**Files:**
- Modify: `lib/feature/Status/views/sections/account_list_section.dart:38-93`

**Problem:** The accounts table uses `Table` with `...controller.accountList.expand(...)`, building all rows eagerly. With many accounts, all TableRows are materialized upfront.

- [ ] **Step 1: Replace with ListView.builder**

Use a fixed header row + `ListView.builder` for account rows (same pattern as the dev tools ResultDataTable optimization).

- [ ] **Step 2: Run tests and commit**

```bash
flutter test
git add lib/feature/Status/views/sections/account_list_section.dart
git commit -m "perf: replace eager Table with ListView.builder in AccountListSection"
```

---

## Phase 4: Low-priority Polish

### Task 14: Batch clearAllProxyData into single SQL statement

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_controller.dart:159-181`

**Problem:** Sequential `await softDeleteSlot()` per slot. 30 slots = 30 round-trips.

- [ ] **Step 1: Add a batch soft-delete method to ProxyRepository**

```dart
Future<void> softDeleteAllSlots() async {
  await (_db.update(_db.proxySlotsTable)..where((t) => t.isDeleted.equals(false)))
    .write(const ProxySlotsTableCompanion(isDeleted: Value(true)));
}
```

- [ ] **Step 2: Use it in clearAllProxyData**

- [ ] **Step 3: Run tests and commit**

```bash
flutter test
git add lib/data/repositories/proxy_repository_impl.dart \
        lib/feature/proxy/controller/proxy_controller.dart
git commit -m "perf: batch soft-delete all proxy slots in single SQL statement"
```

---

### Task 15: Resolve Get.find() calls in build methods

**Files:**
- Multiple files (see audit): `slot_header.dart:168`, `notification_bell.dart:15`, `system_overview_section.dart:55-82`, `characters_status_section.dart:53`, `settings_section.dart:85-187`, `auto_rotation_settings.dart:14`

**Problem:** `Get.find<>()` performs hash-map lookup on every rebuild. Should be resolved once.

- [ ] **Step 1: For StatelessWidgets, accept controller via constructor**

- [ ] **Step 2: For StatefulWidgets, resolve in initState and store as field**

- [ ] **Step 3: Run tests and commit**

```bash
flutter test
git add <affected files>
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
| getCurrentIpForSlot | O(M) per call | O(1) map lookup |
| Scoring stats computation | O(K*M) per Obx | Cached, event-driven |
| getAllAccounts queries | N+1 | 2 (accounts + characters) |
| Dialog memory per open/close | Leaks Rx + controllers | Zero leaks |
| getFilteredSlots list copies | 3 intermediate | 1 final |

## Key References

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices) — "control build cost", "apply effects only when needed", "use Opacity for animations only"
- [Flutter StatefulWidget docs](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html) — "push state to leaves", "cache subtrees", "prefer widgets over helper methods"
- [Flutter State Management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) — "place consumers as deep as possible"
- [Flutter Isolates](https://docs.flutter.dev/perf/isolates) — "use for computation >16ms"
