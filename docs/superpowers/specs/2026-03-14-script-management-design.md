# Script Management & Launch — Design Spec

**Goal:** Enable users to select DreamBot scripts at launch time with configurable parameters, and automatically recover from bot crashes and bans via a lightweight process watchdog.

**Scope:** Launch dialog + process watchdog + auto-relaunch. No persistent profiles, scheduling, or break systems (future work).

**Stack:** Flutter, GetX, Fluent UI, Win32 API (C++), DreamBot QuickStart CLI

---

## 1. Process Monitoring Optimization

### Problem

`StatusController` polls `NativeCommandsService.listJavaProcesses()` every 10 seconds. The C++ implementation spawns `wmic` via `system()`, writes output to a temp file, reads it back, and base64-encodes it. This is heavy: a CMD shell process, disk I/O, and encoding overhead per tick.

### Solution

Replace `wmic` with the Win32 API directly in `main.cpp`:

- Use `CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS)` + `Process32First`/`Process32Next` to enumerate processes in-memory
- Filter for `java.exe`/`javaw.exe` at the C++ level
- Read command lines via `NtQueryInformationProcess` for matching processes
- Return results as an `EncodableList` of `{pid: int, commandLine: String}` maps — no base64, no temp files, no shell

**Dart side:** `listJavaProcesses()` receives structured data directly. The current `ProcessClient.parseProcessData(bytes)` base64 decoding is replaced with direct map deserialization.

**Polling strategy:**

- The `WatchdogService` owns the single poll timer — `StatusController` no longer polls independently
- Adaptive interval: 10s when bots are tracked, 30s when no clients are tracked
- `StatusController` reads from watchdog observables instead of maintaining its own timer

---

## 2. Launch Flow

### Trigger

User clicks the "Play" button on a character row in the Status screen's account list.

### Launch Dialog

A modal dialog (`launch_dialog.dart`) with these fields:

| Field | Widget | Default | Maps to DreamBot flag |
|-------|--------|---------|----------------------|
| Script name | TextBox (free-type) | empty (required) | `-script` |
| World | ComboBox: Auto / F2P / Members / World # | Auto | `-world` |
| Covert mode | ToggleSwitch | On | `-covert` |
| Render mode | ComboBox: All / Game / Script / None | None | `-render` |
| Script params | TextBox | empty | `-params` (must be last arg) |
| Advanced flags | Expander → TextBox | empty | Appended raw |

A "Remember last used" checkbox stores the most recent `LaunchConfig` in memory (session-scoped) so the next launch pre-fills the same values. Not persisted to DB.

### Auto-set flags (not in dialog)

| Flag | Value | Source |
|------|-------|--------|
| `-account` | Character name | From account data |
| `-proxy` | Proxy address | From account's linked proxy slot |
| `-destroy-on-ban` | always | Required for watchdog ban detection |
| `-destroy` | always | Required for watchdog error detection |
| `-minimized` | always | Bots don't need visible windows |

### Bulk launch ("Start All")

The bot farm summary bar includes a "Start All" button that opens the Launch Dialog once. The selected config is applied to all launchable characters (those with status `stopped` or no tracked state, excluding `running`, `restarting`, `banned`, and `awaitingAccount`).

### Data flow

```
Launch Dialog → LaunchConfig
  → StatusController.launchCharacter(account, config)
    → WatchdogService.track(TrackedClient)
      → NativeCommandsService.runGameClient(characterName, proxyAddress, config)
        → Platform channel → C++ RunGameClient() → java -jar Launcher.jar [flags]
```

---

## 3. Platform Channel Changes

### `RunGameClient()` (C++ side)

Currently accepts 3 strings (`characterName`, `proxyAddress`, `scriptName`). Expanded to accept a full `EncodableMap` of parameters:

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

Builds the command string by iterating the map. `-params` is always appended last per DreamBot requirements.

**Input validation:** The existing `isValidInput()` regex (`^[a-zA-Z0-9_\-\.\\: ]+$`) is too restrictive — it rejects `@` (proxy addresses), `=` (DreamBot flags), `/` (paths), and `"` (quoted args). Replace it with a blocklist approach: reject shell metacharacters (`&`, `|`, `;`, `>`, `<`, `` ` ``, `$`, `(`, `)`, `{`, `}`) while allowing everything else. Apply validation per field value, not to the assembled command string. The `advancedFlags` field bypasses validation since it's free-form by design — advanced users accept the risk.

### `ListJavaProcesses()` (C++ side)

Replaced with Win32 API implementation:

```cpp
void ListJavaProcesses(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> &result)
{
    // CreateToolhelp32Snapshot → Process32First/Next
    // Filter java.exe / javaw.exe
    // Read command line via NtQueryInformationProcess
    // Return EncodableList of EncodableMap {pid, commandLine}
}
```

### `NativeCommandsService` (Dart side)

```dart
Future<List<ProcessClient>> listJavaProcesses()
// Returns structured data directly — no base64 decode

Future<void> runGameClient({
  required String characterName,
  required String? proxyAddress,
  required LaunchConfig config,
})
// Passes full config map to platform channel
```

---

## 4. Watchdog Service

### Purpose

Track running bot clients, detect process death, auto-relaunch with backoff, and react to bans. Single service, single poll timer, minimal memory footprint.

### State Model (in-memory only)

```dart
enum ClientStatus { running, restarting, stopped, banned, awaitingAccount }

class TrackedClient {
  final String characterName;
  final int accountId;
  final int proxySlotId;        // From AccountEntity.proxySlotId (see note below)
  final LaunchConfig launchConfig;
  int? pid;                     // null until first poll match discovers the process
  ClientStatus status;
  DateTime? launchedAt;
  int retryCount;
  DateTime? lastDeathAt;
}
```

**Note on `proxySlotId`:** The UI uses `JagexAccount` (which only has `proxyAddress` string). The launch flow must resolve `proxySlotId` from the underlying `AccountEntity` stored in the controller. `StatusController` already holds `AccountEntity` objects from the DB — `launchCharacter()` extracts `proxySlotId` from there before constructing the `TrackedClient`.

**PID assignment:** A newly launched client starts with `pid = null`. On the next poll cycle, the watchdog matches unassigned clients by scanning process command lines for `-account "characterName"`. Once matched, the PID is stored for subsequent fast-path checks by PID.

One `TrackedClient` per bot. No streams, no timers per client — just a `Map<String, TrackedClient>` keyed by character name. `TrackedClient` is a mutable in-memory model, not a domain entity (see File Structure for placement).

### Core Loop

Single `Timer.periodic` at adaptive interval (10s active / 30s idle):

1. **Poll:** Call `NativeCommandsService.listJavaProcesses()` → set of live `{pid, commandLine}` entries
2. **Discover:** For tracked clients with `pid == null` (just launched), scan process command lines for `-account "characterName"` match. On match, assign the PID and set `launchedAt` to now.
3. **Match:** For each `TrackedClient` with a non-null PID, check if PID exists in the live set
4. **Classify death** (PID gone):
   - **Quick death** (alive < 30s since `launchedAt`): likely ban, bad credentials, or missing script → mark `banned`
   - **Normal death** (alive ≥ 30s): script ended or crash → mark `restarting`
5. **Handle restarts** (status `restarting`):
   - If `retryCount < maxRetries` (default 3): wait cooldown `30s × 2^retryCount` (capped at 5 min), then relaunch with same `LaunchConfig`
   - If `retryCount >= maxRetries`: mark `stopped`, fire notification "Max retries reached for [character]"
6. **Handle bans** (status `banned`):
   - Update the character's `banned` flag in DB via `StatusController.markCharacterBanned(accountId, characterName)` which calls `accountRepository.updateCharacterBanned(characterName, true)` — a new repository method (single UPDATE query by character name)
   - Trigger proxy IP rotation on the slot via `ProxyAutoRotationService.rotateSlot(slotId)` — a new method that calls `ProxyReplacementService.replaceIp(slot)` directly, bypassing the score-threshold flow
   - Set status to `awaitingAccount` — watchdog ignores this client until user creates a new account
7. **Stability reset:** When a client has been alive > 5 minutes continuously, reset `retryCount` to 0

### Relaunch Cooldown Schedule

| Retry | Cooldown | Cumulative wait |
|-------|----------|-----------------|
| 1st | 30s | 30s |
| 2nd | 60s | 1.5 min |
| 3rd | 120s | 3.5 min |
| Max (default) | — | Stopped |

### Integration Points

| System | Integration |
|--------|-------------|
| `StatusController` | Removes its own poll timer. Reads `watchdog.trackedClients` observable for UI |
| `NotificationService` | Watchdog fires notifications using new `NotificationType` values: `banDetected`, `maxRetriesReached`, `clientRelaunched` (added to the existing enum in `domain/entities/notification.dart`) |
| `ProxyAutoRotationService` | New `rotateSlot(int slotId)` method called on ban — delegates to `ProxyReplacementService.replaceIp(slot)` directly |
| `AccountRepository` | New `updateCharacterBanned(String characterName, bool banned)` method for setting ban flag |
| `NativeCommandsService` | Watchdog calls `runGameClient()` for relaunches, `killProcess()` for stops |

### Observable State

```dart
final trackedClients = <String, TrackedClient>{}.obs;  // characterName → client

// Computed counts for UI
int get runningCount => ...;
int get restartingCount => ...;
int get stoppedCount => ...;
int get bannedCount => ...;
```

`StatusController` uses `watchdog.trackedClients` in its `Obx` blocks to render status badges and the summary bar.

---

## 5. UI Changes

### Account List Section (modified)

- **Play button:** Opens `LaunchDialog` instead of immediately launching. On dialog submit, calls `statusController.launchCharacter(account, config)` — this replaces the existing `runGameClient(JagexAccount)` method. All callers updated.
- **Stop button:** Calls `watchdog.stop(characterName)` which kills the process and removes tracking (no auto-relaunch)
- **Status badge:** New `BotStatusBadge` component replaces the existing `ProcessStatusBadge`. Shows:
  - `Running` (green) — bot is alive
  - `Restarting 1/3` (amber) — died, waiting to relaunch, shows retry count
  - `Stopped` (gray) — manually stopped or max retries reached
  - `Banned` (red) — quick death detected
  - `Awaiting Account` (blue) — banned, waiting for new account creation

### Bot Farm Summary Bar (new component)

A compact `Row` inserted above the account list table header:

```
[Running: 12] [Restarting: 1] [Stopped: 0] [Banned: 1]    [▶ Start All] [■ Stop All]
```

- **Start All:** Opens Launch Dialog once → applies config to all launchable characters
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
│   │   │   └── launch_dialog.dart                  # NEW ~150 lines
│   │   ├── components/
│   │   │   ├── bot_status_badge.dart                # NEW ~50 lines
│   │   │   └── bot_farm_summary_bar.dart            # NEW ~100 lines
│   │   └── sections/
│   │       └── account_list_section.dart            # MODIFIED: play→dialog, status badge
│   └── controller/
│       └── status_controller.dart                   # MODIFIED: delegate to watchdog
│
├── config/services/
│   └── watchdog/
│       ├── watchdog_service.dart                    # NEW ~200 lines
│       ├── launch_config.dart                       # NEW ~30 lines (presentation model, not domain entity)
│       └── tracked_client.dart                      # NEW ~40 lines (mutable in-memory model, not domain entity)
│
├── config/services/
│   ├── native_commands_service.dart                 # MODIFIED: structured response, expanded runGameClient
│   └── proxy/
│       └── proxy_auto_rotation_service.dart         # MODIFIED: add rotateSlot(int slotId)
│
├── domain/
│   ├── entities/
│   │   └── notification.dart                        # MODIFIED: add banDetected, maxRetriesReached, clientRelaunched
│   └── repositories/
│       └── account_repository.dart                  # MODIFIED: add updateCharacterBanned()
│
├── data/repositories/
│   └── account_repository_impl.dart                 # MODIFIED: implement updateCharacterBanned()
│
└── core/resource/
    └── dependency_injection.dart                    # MODIFIED: register WatchdogService

windows/runner/
└── main.cpp                                         # MODIFIED: Win32 API process enum, expanded RunGameClient
```

All files within size ceilings. No new DB tables.

**Note on model placement:** `LaunchConfig` and `TrackedClient` live in the watchdog service directory, not `domain/entities/`. `LaunchConfig` is a presentation concern (dialog form values, session-scoped). `TrackedClient` is a mutable in-memory model that doesn't follow the `Equatable` convention used by domain entities.

---

## 7. DI Registration

`WatchdogService` depends on `NativeCommandsService` (permanent), `NotificationService` (async), and `ProxyAutoRotationService` (lazy). Since `ProxyAutoRotationService` is registered with `Get.lazyPut` in `dependencies()`, the watchdog must also be registered as a lazy service, not in `initializeAsyncServices()`.

```dart
// In AppBindings.dependencies(), after ProxyAutoRotationService lazyPut:
Get.lazyPut(() => WatchdogService(
  nativeCommandsService: Get.find<NativeCommandsService>(),
  notificationService: Get.find<NotificationService>(),
  autoRotationService: Get.find<ProxyAutoRotationService>(),
), fenix: true);
```

The watchdog initializes on first access (when `StatusController` is created), which is after all async services are ready.

---

## 8. Future Extensions (not in this spec)

- **Script profiles:** Persist `LaunchConfig` to DB, assign to characters/slots, reuse across sessions
- **Bulk launch with different scripts:** Each character gets its own profile
- **Scheduling:** Time windows when bots should run, daily cycles
- **Break system:** Randomized play/pause to mimic human behavior
- **DreamBot Discord webhooks:** Local HTTP listener for richer event data (script-stop, death, level-up)
- **Start All on app launch:** Auto-resume farm with saved profiles

---

## 9. DreamBot QuickStart Reference

Full parameter list used by this feature (subset of DreamBot's ~50+ flags):

| Flag | Purpose | Set by |
|------|---------|--------|
| `-script=<name>` | Bot script to run | Launch dialog |
| `-account=<name>` | Character name | Auto (account data) |
| `-proxy=<address>` | Proxy address | Auto (proxy slot) |
| `-world=<value>` | f2p / members / world ID | Launch dialog |
| `-covert` | Stealth mode | Launch dialog |
| `-render=<mode>` | ALL / GAME / SCRIPT / NONE | Launch dialog |
| `-params=<args>` | Script-specific params (must be last) | Launch dialog |
| `-destroy` | Exit on load failure | Auto (always) |
| `-destroy-on-ban` | Exit on ban/lock | Auto (always) |
| `-minimized` | Start minimized | Auto (always) |

Source: [DreamBot QuickStart/CLI Guide](https://dreambot.org/guides/user-guide/quickstart/)
