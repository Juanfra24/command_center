# Script Management & Launch — Design Spec

**Goal:** Enable users to select DreamBot scripts at launch time with configurable parameters, and automatically recover from bot crashes and bans via a lightweight process watchdog.

**Scope:** Launch dialog + process watchdog + auto-relaunch + process recapture on app restart. No persistent profiles, scheduling, or break systems (future work).

**Stack:** Flutter, GetX, Fluent UI, Win32 API (C++), DreamBot QuickStart CLI

---

## 1. Process Monitoring Optimization

### Problem

`StatusController` polls `NativeCommandsService.listJavaProcesses()` every 10 seconds. The C++ implementation spawns `wmic` via `system()`, writes output to a temp file, reads it back, and base64-encodes it. This is heavy: a CMD shell process, disk I/O, and encoding overhead per tick.

### Solution

Replace `wmic` with the **WMI COM API** directly in `main.cpp`. This queries process data in-process without spawning subprocesses or temp files:

- Use `IWbemLocator`/`IWbemServices` to connect to the local WMI namespace (`root\cimv2`)
- Execute `SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'java.exe' OR Name = 'javaw.exe'`
- Return results as an `EncodableList` of `{pid: int, commandLine: String}` maps

**Why WMI COM over `NtQueryInformationProcess`:** Reading command lines via `NtQueryInformationProcess` requires manually defining undocumented structs (`PEB`, `RTL_USER_PROCESS_PARAMETERS`, `PROCESS_BASIC_INFORMATION`), handling 32/64-bit WoW64 PEB layout differences, and calling `ReadProcessMemory` on each target process. The WMI COM API is well-documented, handles all process architectures, and returns command lines directly — more code but significantly more robust.

**COM threading:** `CoInitializeEx` is already called in `wWinMain` (line 195 of current `main.cpp`), so COM is available on the main thread. Flutter's platform channel handler (`HandleMethodCall`) runs on the main thread, so WMI COM calls work directly. The WMI query runs synchronously, blocking the UI for ~50-200ms per poll — acceptable at 10-30s intervals. If moved to a background thread in the future, that thread must call `CoInitializeEx` independently.

**Dart side:** `listJavaProcesses()` receives structured data directly. The current `ProcessClient.parseProcessData(bytes)` base64 decoding is replaced with direct map deserialization. The existing Dart-side filter for `client.jar` in command lines is replaced: the C++ WMI query already filters by `java.exe`/`javaw.exe`, and the watchdog further filters by checking for `-account` in the command line to identify DreamBot clients specifically.

**Process launching:** Replace `ExecuteCommandAsync` (which uses `system()` through a CMD shell) with `CreateProcess` for launching game clients. This avoids spawning an unnecessary CMD window and eliminates the command injection risk from shell metacharacters. `CreateProcess` also returns the child process PID directly via `PROCESS_INFORMATION`, which the watchdog can use for immediate tracking instead of waiting for the next poll cycle.

**Polling strategy:**

- The `WatchdogService` owns the single poll timer — `StatusController` no longer polls independently
- Adaptive interval: 10s when the `trackedClients` map is non-empty (regardless of client status), 30s when empty
- `StatusController` reads from watchdog observables instead of maintaining its own timer

---

## 2. Launch Flow

### Trigger

User clicks the "Play" button on a character row in the Status screen's account list.

### Script Registry

Scripts are selected from a **predefined list** — not free-typed — to prevent typos causing launch failures and wasted proxy rotations.

The registry is a simple in-memory list managed through the Launch Dialog:

- **Default scripts:** `["Tutorial Journey"]` (shipped with the app)
- **Add script:** A text field + "Add" button in the dialog lets users register new script names
- **Remove script:** Right-click or X button on a script entry to remove it
- **Persistence:** The script list is stored in `AppConfigService` (SQLite key-value: `script_registry` → JSON array of script names). Survives app restarts.
- **No validation against DreamBot:** We don't check if the script exists in DreamBot's directory. The registry is a user-curated list of scripts they've verified work.

### Launch Dialog

A modal dialog (`launch_dialog.dart`) with these fields:

| Field | Widget | Default | Maps to DreamBot flag |
|-------|--------|---------|----------------------|
| Script name | ComboBox (from registry) + "Add new" | last used or first entry | `-script` |
| World | ComboBox: Auto / F2P / Members / World # | Auto | `-world` |
| Covert mode | ToggleSwitch | On | `-covert` |
| Render mode | ComboBox: All / Game / Script / None | None | `-render` |
| Script params | TextBox | empty | `-params` (must be last arg) |
| Advanced flags | Expander → TextBox | empty | Appended raw |

**World # input:** When "World #" is selected from the ComboBox, a numeric TextBox appears next to it for entering the specific world number (e.g., 385).

The dialog stores the most recent `LaunchConfig` in memory (session-scoped) so the next launch pre-fills the same values.

### Auto-set flags (not in dialog)

| Flag | Value | Source |
|------|-------|--------|
| `-account` | Character name | From character data |
| `-proxy` | Proxy address | From account's linked proxy slot |
| `-destroy-on-ban` | always | Required for watchdog ban detection |
| `-destroy` | always | Required for watchdog error detection |
| `-minimized` | always | Bots don't need visible windows |

### Bulk launch ("Start All")

The bot farm summary bar includes a "Start All" button that opens the Launch Dialog once. The selected config is applied to all launchable characters — those with watchdog status `stopped` or no tracked state, excluding `running`, `restarting`, `failed`, `banned`, and `awaitingAccount`. Additionally, characters with `banned == true` in the database are excluded (covers bans from previous sessions where in-memory watchdog state was lost). Each character launches with its own account's proxy — all characters are launched, including multiple characters from the same account.

### Data flow

```
Launch Dialog → LaunchConfig
  → StatusController.launchCharacter(account, character, config)
    → WatchdogService.track(TrackedClient)
      → NativeCommandsService.runGameClient(characterName, proxyAddress, config)
        → Platform channel → C++ CreateProcess() → java -jar Launcher.jar [flags]
        ← returns PID from PROCESS_INFORMATION
      → TrackedClient.pid = returnedPid
```

**Note on view model changes:** Two fields must be added to the UI models:
- Add `proxySlotId` (int?) to `JagexAccount` — populated during the `AccountEntity` → `JagexAccount` mapping in `StatusController`. Update the `Equatable` `props` list to include it.
- Add `id` (int?) to the `Character` view model — populated from `CharacterEntity.id` during the same mapping. Required so `TrackedClient.characterId` can be set for reliable DB updates. Update `Character.props` as well.

---

## 3. Platform Channel Changes

### `RunGameClient()` (C++ side)

Currently accepts 3 strings (`characterName`, `proxyAddress`, `scriptName`) and uses `ExecuteCommandAsync` (`system()` via CMD shell). Replace with `CreateProcess`:

```cpp
// Receives from Dart:
{
  "characterName": "MyChar",
  "proxyAddress": "user:pass@host:port",
  "scriptName": "Tutorial Journey",
  "world": "f2p",           // optional: "f2p", "members", "385", etc.
  "covert": true,           // optional
  "render": "NONE",         // optional: "ALL", "GAME", "SCRIPT", "NONE"
  "scriptParams": "tree oak", // optional
  "advancedFlags": "-fps 15", // optional
  "destroyOnBan": true,     // always true
  "destroy": true,          // always true
  "minimized": true         // always true
}
```

Builds the command line string from the map. Uses `CreateProcess` instead of `system()`:
- No CMD shell involved — eliminates command injection risk
- Returns the child PID (`pi.dwProcessId`) to Dart via `result->Success(EncodableValue(pid))`
- `-params` is always appended last per DreamBot requirements

**DreamBot flag format:** DreamBot accepts both `-script "name"` (space-separated) and `-script=name` (equals). Use space-separated with quoted values for consistency with existing code: `-script "Tutorial Journey" -account "CharName"`.

**Input validation:** Replace the current `isValidInput()` allowlist regex with a blocklist: reject shell metacharacters (`&`, `|`, `;`, `>`, `<`, `` ` ``, `$`) in structured fields. The `advancedFlags` field is appended as-is — since we use `CreateProcess` (not `system()`), there is no shell to exploit.

### `ListJavaProcesses()` (C++ side)

Replaced with WMI COM API implementation:

```cpp
void ListJavaProcesses(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> &result)
{
    // IWbemLocator → ConnectServer("root\\cimv2")
    // ExecQuery: "SELECT ProcessId, CommandLine FROM Win32_Process
    //             WHERE Name = 'java.exe' OR Name = 'javaw.exe'"
    // Iterate IEnumWbemClassObject → extract pid + commandLine
    // Return EncodableList of EncodableMap {pid: int, commandLine: String}
}
```

### `NativeCommandsService` (Dart side)

```dart
Future<List<ProcessClient>> listJavaProcesses()
// Returns structured data directly — no base64 decode

Future<int> runGameClient({
  required String characterName,
  required String? proxyAddress,
  required LaunchConfig config,
})
// Returns PID from CreateProcess. Passes full config map to platform channel.
```

**Note:** `runGameClient` now returns `Future<int>` (the PID) instead of `Future<void>`.

---

## 4. Watchdog Service

### Purpose

Track running bot clients, detect process death, auto-relaunch with backoff, and react to bans. Single service, single poll timer, minimal memory footprint.

### State Model (in-memory only)

```dart
enum ClientStatus { running, restarting, stopped, failed, banned, awaitingAccount }

class TrackedClient {
  final String characterName;
  final int characterId;          // DB primary key for reliable updates
  final int accountId;
  final int? proxySlotId;         // Nullable — accounts without proxy can still launch
  String? proxyAddress;           // Resolved at launch, updated after proxy rotation
  final LaunchConfig launchConfig;
  int? pid;                       // Set from CreateProcess return, or from poll discovery
  ClientStatus status;
  DateTime? launchedAt;
  int retryCount;
  int consecutiveQuickDeaths;     // Tracks quick deaths for ban escalation
  DateTime? lastDeathAt;
}
```

**`proxySlotId` nullable:** Accounts without a linked proxy can still be launched (proxy flag is omitted). On ban, the watchdog skips proxy rotation if `proxySlotId` is null.

**`proxyAddress`:** Resolved at launch time from the account's proxy slot and stored on the `TrackedClient`. Used by the watchdog for relaunches without needing a `ProxyController` dependency. After a ban-triggered proxy rotation, the watchdog re-resolves the address via `proxyRepository.getActiveIpForSlot(slotId)` to get the new IP.

**`characterId` for DB updates:** Used instead of `characterName` for the `updateCharacterBanned()` call, avoiding ambiguity if character names are not unique across accounts.

One `TrackedClient` per bot. No streams, no timers per client — just a `Map<String, TrackedClient>` keyed by character name. `TrackedClient` is a mutable in-memory model, not a domain entity (see File Structure for placement).

### Death Classification: `failed` vs `banned`

Quick death (< 30s) does **not** immediately mean ban. The watchdog uses escalation:

| Consecutive quick deaths | Classification | Action |
|--------------------------|---------------|--------|
| 1st | `failed` | Retry with backoff. No proxy rotation. Notification: "Client failed for [character]" |
| 2nd | `failed` | Retry with backoff. No proxy rotation. |
| 3rd+ | `banned` | Mark banned in DB, rotate proxy, set `awaitingAccount`. Notification: "Ban detected for [character]" |

Normal death (≥ 30s) always → `restarting`. Resets `consecutiveQuickDeaths` to 0.

A **discovery timeout** also applies: if a tracked client with `pid == null` is not discovered within 3 poll cycles (~30s) after launch, it is marked `failed` (launch never succeeded — Java not found, DreamBot missing, etc.). This avoids confusing a launch failure with a ban.

### Core Loop

Single `Timer.periodic` at adaptive interval (10s active / 30s idle):

1. **Poll:** Call `NativeCommandsService.listJavaProcesses()` → set of live `{pid, commandLine}` entries
2. **Discover:** For tracked clients with `pid == null`, check if we have a PID from `CreateProcess` return (set at launch time). If not, scan process command lines for `-account "characterName"` match. If no match after 3 poll cycles, mark as `failed`.
3. **Match:** For each `TrackedClient` with a non-null PID, check if PID exists in the live set
4. **Classify death** (PID gone):
   - **Quick death** (alive < 30s since `launchedAt`): increment `consecutiveQuickDeaths`. If < 3 → mark `failed`. If ≥ 3 → mark `banned`.
   - **Normal death** (alive ≥ 30s): mark `restarting`, reset `consecutiveQuickDeaths` to 0
5. **Handle restarts** (status `restarting` or `failed`):
   - If `retryCount < maxRetries` (default 5): wait cooldown `30s × 2^retryCount` (capped at 5 min), then relaunch with same `LaunchConfig`. Cooldown is checked by comparing `DateTime.now()` against `lastDeathAt + cooldown` — no per-client timers or `Future.delayed`.
   - If `retryCount >= maxRetries`: mark `stopped`, fire notification "Max retries reached for [character]"
6. **Handle bans** (status `banned`):
   - Update the character's `banned` flag in DB via `accountRepository.updateCharacterBanned(characterId, true)` — a new repository method (single UPDATE by primary key)
   - If `proxySlotId != null`: trigger proxy IP rotation via `ProxyAutoRotationService.rotateSlot(slotId)` (see Integration Points for call chain)
   - Set status to `awaitingAccount` — watchdog ignores this client until user creates a new account
7. **Stability reset:** When a client has been alive > 5 minutes continuously, reset `retryCount` and `consecutiveQuickDeaths` to 0

### Stopping a Client

`watchdog.stop(characterName)`:
1. Kill the process via `NativeCommandsService.killProcess(pid)` if PID is non-null
2. Remove the entry from `trackedClients` map entirely

Since relaunch cooldowns are checked by elapsed time on each tick (not `Future.delayed`), removing the entry from the map is sufficient to cancel any pending relaunch. No race condition.

### Startup Recapture

On app launch, after all services are initialized, the watchdog runs a **recapture scan**:

1. Poll `listJavaProcesses()` to find all running Java processes
2. For each process with `-account "name"` in its command line:
   - Match `name` against known characters in the DB
   - If matched: create a `TrackedClient` with status `running`, `pid` from the process, and a **default `LaunchConfig`** (since the original config is unknown). Extract script name from `-script "name"` in the command line if possible.
3. Log recaptured clients: "Recaptured N running bot clients"

Recaptured clients get full watchdog protection (death detection, auto-relaunch). The `LaunchConfig` may be incomplete (no world/render/params info from the command line), but it's sufficient for relaunching with the detected script name.

**Assumption:** DreamBot propagates the `-account`, `-script`, and other CLI flags into the spawned `java.exe` command line (as is typical for Java process launchers). If DreamBot strips or rewrites these flags, the recapture scan will not find matches — this will be verified during implementation and the matching strategy adjusted if needed.

### Relaunch Cooldown Schedule

| Retry | Cooldown | Cumulative wait |
|-------|----------|-----------------|
| 1st | 30s | 30s |
| 2nd | 60s | 1.5 min |
| 3rd | 120s | 3.5 min |
| 4th | 240s | 7.5 min |
| 5th | 300s (cap) | 12.5 min |
| Max (default) | — | Stopped |

Cooldowns are measured from `lastDeathAt`, not from previous launch.

### Integration Points

| System | Integration |
|--------|-------------|
| `StatusController` | Removes its own poll timer. Reads `watchdog.trackedClients` observable for UI. Replaces `runGameClient()` with `launchCharacter()`. |
| `NotificationService` | Watchdog fires notifications using new `NotificationType` values: `banDetected`, `maxRetriesReached`, `clientRelaunched`, `clientFailed` (added to the existing enum in `domain/entities/notification.dart`) |
| `ProxyAutoRotationService` | New `rotateSlot(int slotId)` method: looks up `ProxySlotEntity` via `_proxyRepository.getSlotById(slotId)`, gets active IP via `_proxyRepository.getActiveIpForSlot(slotId)`, then calls `_replacementService.replaceProxyIp(currentIp)`. Uses repository (not controller) — same pattern as `_processResults()` at line 113 of `proxy_auto_rotation_service.dart`. |
| `AccountRepository` | New `updateCharacterBanned(int characterId, bool banned)` method — single UPDATE on `charactersTable` by primary key. Doc comment clarifies it targets characters, not accounts. |
| `ProxyRepository` | Watchdog uses `getActiveIpForSlot(slotId)` to re-resolve proxy address after rotation |
| `NativeCommandsService` | Watchdog calls `runGameClient()` for relaunches (returns PID), `killProcess()` for stops |

### Observable State

```dart
final trackedClients = <String, TrackedClient>{}.obs;  // characterName → client
```

**GetX reactivity note:** Mutating fields inside a `TrackedClient` (e.g., changing `status`) does not trigger `RxMap` change detection. After mutating a client's fields, call `trackedClients.refresh()` to notify `Obx` listeners. This is a single call after all mutations in a tick are done — not per-field.

Computed counts for UI (recalculated on each `refresh()`):

```dart
int get runningCount => trackedClients.values.where((c) => c.status == ClientStatus.running).length;
int get restartingCount => trackedClients.values.where((c) => c.status == ClientStatus.restarting || c.status == ClientStatus.failed).length;
int get stoppedCount => trackedClients.values.where((c) => c.status == ClientStatus.stopped).length;
int get bannedCount => trackedClients.values.where((c) => c.status == ClientStatus.banned || c.status == ClientStatus.awaitingAccount).length;
```

`StatusController` uses `watchdog.trackedClients` in its `Obx` blocks to render status badges and the summary bar.

### App Close Behavior

When the app closes, **bots are left running** — they are independent Java processes. The watchdog does **not** kill tracked clients on `onClose()`. In-memory tracking state is lost.

On next app launch, the startup recapture scan (see above) rediscovers running bots and resumes tracking.

`StatusController.onClose()` is updated to remove its current process-killing behavior.

### Logging

All watchdog state transitions are logged at appropriate levels:
- `logger.i` — launch, recapture, relaunch, stop
- `logger.w` — quick death, failed classification
- `logger.e` — ban detection, max retries reached, discovery timeout

---

## 5. UI Changes

### Account List Section (modified)

- **Play button:** Opens `LaunchDialog` instead of immediately launching. On dialog submit, calls `statusController.launchCharacter(account, character, config)` — this replaces the existing `runGameClient(JagexAccount)` method. All callers updated.
- **Stop button:** Calls `watchdog.stop(characterName)` which kills the process and removes tracking (no auto-relaunch)
- **Status badge:** New `BotStatusBadge` component replaces the existing `ProcessStatusBadge`. Shows:
  - `Running` (green) — bot is alive
  - `Restarting 1/5` (amber) — died, waiting to relaunch, shows retry/maxRetries
  - `Failed 1/5` (orange) — quick death, retrying (not yet classified as ban)
  - `Stopped` (gray) — manually stopped or max retries reached
  - `Banned` (red) — 3+ consecutive quick deaths
  - `Awaiting Account` (blue) — banned, waiting for new account creation

### Bot Farm Summary Bar (new component)

A compact `Row` inserted above the account list table header:

```
[Running: 12] [Restarting: 1] [Stopped: 0] [Banned: 1]    [▶ Start All] [■ Stop All]
```

- **Start All:** Opens Launch Dialog once → applies config to all launchable characters (all characters across all accounts, each using their own proxy)
- **Stop All:** Stops all tracked clients (kills processes, clears tracking)
- Stats are reactive via `Obx` reading watchdog computed counts

### Launch Dialog (new)

A `ContentDialog` with form fields as described in Section 2. Returns `LaunchConfig?` (null if cancelled).

---

## 6. File Structure

```
lib/
├── feature/Status/
│   ├── views/
│   │   ├── dialogs/
│   │   │   └── launch_dialog.dart                  # NEW ~180 lines (includes script registry UI)
│   │   ├── components/
│   │   │   ├── bot_status_badge.dart                # NEW ~60 lines
│   │   │   └── bot_farm_summary_bar.dart            # NEW ~100 lines
│   │   └── sections/
│   │       └── account_list_section.dart            # MODIFIED: play→dialog, status badge
│   ├── controller/
│   │   └── status_controller.dart                   # MODIFIED: delegate to watchdog, add proxySlotId mapping
│   └── data/
│       └── jagex_account_model.dart                 # MODIFIED: add proxySlotId field
│
├── config/services/
│   └── watchdog/
│       ├── watchdog_service.dart                    # NEW ~250 lines (includes recapture + escalation logic)
│       ├── launch_config.dart                       # NEW ~30 lines (presentation model, not domain entity)
│       └── tracked_client.dart                      # NEW ~50 lines (mutable in-memory model, not domain entity)
│
├── config/services/
│   ├── native_commands_service.dart                 # MODIFIED: structured response, runGameClient returns PID
│   ├── app_config_service.dart                      # MODIFIED: add script_registry config key
│   └── proxy/
│       └── proxy_auto_rotation_service.dart         # MODIFIED: add rotateSlot(int slotId)
│
├── domain/
│   ├── entities/
│   │   └── notification.dart                        # MODIFIED: add banDetected, maxRetriesReached, clientRelaunched, clientFailed
│   └── repositories/
│       └── account_repository.dart                  # MODIFIED: add updateCharacterBanned(int characterId, bool banned)
│
├── data/repositories/
│   └── account_repository_impl.dart                 # MODIFIED: implement updateCharacterBanned()
│
└── core/resource/
    └── dependency_injection.dart                    # MODIFIED: register WatchdogService

windows/runner/
└── main.cpp                                         # MODIFIED: WMI COM process enum, CreateProcess for launch, return PID
```

All files within size ceilings. No new DB tables.

**Note on model placement:** `LaunchConfig` and `TrackedClient` live in the watchdog service directory, not `domain/entities/`. `LaunchConfig` is a presentation concern (dialog form values, session-scoped). `TrackedClient` is a mutable in-memory model that doesn't follow the `Equatable` convention used by domain entities.

**WatchdogService line budget:** The ~250 line estimate is tight given recapture logic + death classification + relaunch scheduling. If it exceeds the 250-line service ceiling during implementation, extract the death classification and relaunch scheduling into a private helper method or a small `_WatchdogClassifier` utility in the same directory — not a separate service.

**Dead code cleanup during implementation:**
- `NativeCommandsService`: remove the dead `output.obs` field and drop the unnecessary `GetxController` base class (convert to plain class with DI)
- `StatusController`: remove `_processCheckTimer`, the polling logic, and the `onClose()` process-killing behavior — all replaced by the watchdog

**Launch dialog pattern:** Follow the `ReplaceProxyDialog` pattern (constructor params in, result out via `Navigator.pop`) as established in the proxy feature.

---

## 7. DI Registration

`WatchdogService` needs **eager initialization** so the startup recapture scan runs immediately on app launch — before the user navigates to the Status screen. It depends on `NativeCommandsService`, `NotificationService`, `ProxyAutoRotationService`, `AccountRepository`, `ProxyRepository`, and `AppConfigService`.

Since `ProxyAutoRotationService` is registered with `Get.lazyPut`, the watchdog cannot be placed in `initializeAsyncServices()`. Instead, register it eagerly with `Get.put` at the end of `dependencies()`, after all its dependencies are registered:

```dart
// In AppBindings.dependencies(), at the end (after all lazyPut registrations):
Get.put(WatchdogService(
  nativeCommandsService: Get.find<NativeCommandsService>(),
  notificationService: Get.find<NotificationService>(),
  autoRotationService: Get.find<ProxyAutoRotationService>(),
  accountRepository: Get.find<AccountRepository>(),     // for updateCharacterBanned + character lookups
  proxyRepository: Get.find<ProxyRepository>(),          // for getActiveIpForSlot
  appConfigService: Get.find<AppConfigService>(),        // for script registry
));
```

`Get.put` triggers `onInit()` immediately, which runs the recapture scan. This ensures running bots are discovered even if the user hasn't opened the Status screen yet.

---

## 8. Future Extensions (not in this spec)

- **Script profiles:** Persist `LaunchConfig` to DB, assign to characters/slots, reuse across sessions
- **Bulk launch with different scripts:** Each character gets its own profile
- **Scheduling:** Time windows when bots should run, daily cycles
- **Break system:** Randomized play/pause to mimic human behavior
- **DreamBot Discord webhooks:** Local HTTP listener for richer event data (script-stop, death, level-up)
- **Auto-resume on app launch:** Resume farm with saved profiles instead of just recapturing

---

## 9. DreamBot QuickStart Reference

Full parameter list used by this feature (subset of DreamBot's ~50+ flags):

| Flag | Purpose | Set by |
|------|---------|--------|
| `-script "name"` | Bot script to run | Launch dialog (from registry) |
| `-account "name"` | Character name | Auto (character data) |
| `-proxy "address"` | Proxy address | Auto (proxy slot) |
| `-world <value>` | f2p / members / world ID | Launch dialog |
| `-covert` | Stealth mode | Launch dialog |
| `-render <mode>` | ALL / GAME / SCRIPT / NONE | Launch dialog |
| `-params <args>` | Script-specific params (must be last) | Launch dialog |
| `-destroy` | Exit on load failure | Auto (always) |
| `-destroy-on-ban` | Exit on ban/lock | Auto (always) |
| `-minimized` | Start minimized | Auto (always) |

Source: [DreamBot QuickStart/CLI Guide](https://dreambot.org/guides/user-guide/quickstart/)
