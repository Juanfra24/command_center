# Microbot Integration — Command Center Design Spec

## Goal

Integrate Microbot (open-source RuneLite fork) as the bot engine for Command Center, replacing the current DreamBot-specific launch path. Provide a clean abstraction layer so future bot engines (TRiBot, RuneMate, etc.) can be added without refactoring.

## Context

### Why Microbot
- Open source (BSD-2) — full control, no licensing costs
- RuneLite-based — survives Jagex's Legacy Java Client shutdown (Jan 2026)
- Native SOCKS5 proxy support per-instance (`--proxy` flag)
- ~550MB RAM per optimized instance — 20 bots fits in 16-32GB
- Active development (weekly releases, 502 forks, Java 17, Gradle)

### What This Spec Covers (Spec 1 of 3)
- Command Center Dart/Flutter integration only
- Bot engine abstraction layer
- Profile generation, process launching, monitoring
- Setup/splash screen for dependency installation

### What This Spec Does NOT Cover
- Microbot fork modifications (CLI args, telemetry removal, status API) — Spec #2
- Bot script development (Java scripts for the fork) — Spec #3

## Architecture

### Bot Engine Abstraction

A lightweight abstract class defines the contract any bot engine must satisfy. The signature uses flat parameters that match what callers actually have (StatusController has presentation models + IDs, WatchdogHandlers has TrackedClient with stored strings). Callers should not need to hydrate full entity objects.

```dart
abstract class BotEngine {
  /// Launch a bot instance. Returns the OS process ID.
  Future<int> launch({
    required int characterId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,  // Pre-formatted: socks5://user:pass@ip:port
    required LaunchConfig config,
  });

  /// Stop a running bot instance by PID.
  Future<void> stop(int pid);

  /// Human-readable engine name (for logs/notifications).
  String get engineName;
}
```

Note: `isRunning()` is omitted — the WatchdogService already checks liveness via `NativeCommandsService.listJavaProcesses()` and PID set membership. No parallel path needed.

`MicrobotEngine` is the sole implementation for now. Registered in `AppBindings` via GetX DI. The rest of the app interacts only with `BotEngine` — never `MicrobotEngine` directly. When a second engine is added, a settings UI and DI switcher are introduced then, not now.

### Proxy URL Construction

`BotEngine.launch()` expects a pre-formatted `socks5://user:pass@host:port` URL. The caller is responsible for building it. Two call sites exist:

**StatusController (fresh launch):**
1. Loads `ProxySlotEntity` via character's `proxySlotId`
2. Loads active `ProxyIpAddressEntity` for that slot
3. Constructs: `socks5://${slot.username}:${slot.password}@${ip.address}:${slot.socksPort}`
   - **Host:** Uses the active IP address directly (Webshare SOCKS5 connects to the proxy IP, not `p.webshare.io` — the shared hostname is for HTTP proxies only)
   - **Port:** `slot.socksPort` — the per-slot SOCKS5 port from Webshare API (distinct from HTTP `slot.port`)
4. Passes to `BotEngine.launch(proxyUrl: url)`

**WatchdogHandlers (restart):**
- Uses `TrackedClient.proxyUrl` (stored at first launch as the full SOCKS5 URL string)
- No reconstruction needed — the URL is preserved across restarts

**SOCKS5 port:** Webshare exposes SOCKS5 on a per-slot port (different from HTTP port). The `ProxySlotsTable` must store `socks_port` (integer). This is fetched from Webshare API during proxy sync and stored alongside existing `username`/`password`/`port` fields.

**Helper:** A static `ProxyUrlBuilder.buildSocks5Url()` method in `core/helper/proxy_url_builder.dart` encapsulates the URL construction. Both `StatusController` and any future callers use this single code path.

**Null proxy:** If a character has no assigned proxy slot, `proxyUrl` is `null` and `--proxy` flag is omitted from the launch command.

### App Data Path Resolution

All Microbot file paths (`microbot_profiles/`, `microbot/`, `java/`) are rooted under the Flutter `getApplicationSupportDirectory()` path (typically `C:\Users\<user>\AppData\Roaming\com.example.command_center\`). This is resolved once at startup and stored as a base path.

A shared `AppDataPath` helper in `core/helper/app_data_path.dart` provides `Future<String> get basePath` using `path_provider`'s `getApplicationSupportDirectory()`. All services that need file paths (`MicrobotEngine`, `MicrobotSetupService`) receive this resolved path via DI, never hardcoding paths.

### Profile Generation

Microbot requires pre-configured RuneLite profile directories. Command Center generates these transiently at launch time — the database is the single source of truth, profiles are disposable artifacts.

**Profile directory structure:**
```
<app_data>/microbot_profiles/
  bot-<characterId>/
    settings.properties    # RuneLite plugin configs, world, display
    credentials.properties # Account login (written, never logged)
```

**Data flow:**
1. `MicrobotEngine.launch()` receives account + character + proxy + config
2. Writes profile files to `bot-<characterId>/` directory
3. Launches: `java -jar microbot.jar --profile=bot-<characterId> --proxy=socks5://user:pass@ip:port`
4. On `stop()` — kills process, cleans up profile directory

**Security:**
- Credentials exist on disk only while the bot is running
- Proxy URL passed via Microbot's native `--proxy` CLI flag, not in profile files
- Profile directory wiped on `stop()`
- On app close: profiles are NOT wiped (bots may still be running for recapture)
- On startup: stale profiles cleaned AFTER `recaptureRunningClients()` completes (see Startup Recovery below)

### Process Launching

`MicrobotEngine` uses Dart's `Process.start()` (same pattern as `PythonRunner`):
- Spawns: `java <jvmArgs> -jar <microbot_jar_path> --profile=<id> --proxy=socks5://... --safe-mode`
  - JVM flags (e.g., `-Xmx512m`) go BEFORE `-jar` (they're JVM arguments)
  - App flags (e.g., `--profile`, `--proxy`, `--safe-mode`) go AFTER the JAR path (they're application arguments)
- Captures stdout/stderr for log forwarding
- Returns PID for watchdog tracking
- Tracks all spawned processes for cleanup on app close

### Integration with Existing Services

**WatchdogService — minor changes.** Already tracks `TrackedClient` by PID, classifies deaths, handles exponential backoff restarts. Works with any Java process. Changes: restart path calls `BotEngine.launch()` instead of `NativeCommandsService.runGameClient()`. Stop path calls `BotEngine.stop()` (not `NativeCommandsService.killProcess()` directly) so profile cleanup happens.

**StatusController — moderate changes.** `launchCharacter()` and `launchAll()` switch from `NativeCommandsService.runGameClient()` to `BotEngine.launch()`. The controller resolves account email/password and proxy URL from the database before calling `BotEngine.launch()` with flat parameters.

**NativeCommandsService — stays for process listing/killing only.** `runGameClient()` is no longer called. Process discovery and killing still go through the C++ platform channel (WMI).

**WatchdogService — updated constructor.** Must accept `BotEngine` as a dependency (passed to `WatchdogHandlers`). DI registration order updated: `BotEngine` registered before `WatchdogService`.

**WatchdogHandlers — moderate changes.** `handleRestart()` calls `BotEngine.launch()` with flat params from `TrackedClient` (characterId, characterName, email, password, proxyUrl, LaunchConfig). `discoverPid()` matches `--profile=bot-${client.characterId}` in the command line for Microbot processes. `recaptureRunningClients()` adds the same Microbot pattern. Existing DreamBot patterns removed (clean break).

**`handleBan()` proxy rotation update:** After proxy auto-rotation replaces a banned IP, `handleBan()` must reconstruct `TrackedClient.proxyUrl` using `ProxyUrlBuilder` with the new IP address. The old `proxyAddress` field is removed — all proxy state flows through the full `proxyUrl` string. Flow: `ProxyAutoRotationService` replaces IP → `handleBan()` loads new `ProxyIpAddressEntity` → reconstructs `proxyUrl` via `ProxyUrlBuilder` → updates `TrackedClient.proxyUrl` → restarts via `BotEngine.launch()`.

**Recapture credential recovery:** On cold restart, `recaptureRunningClients()` only discovers PIDs + characterIds from process command lines. It must hydrate `email`, `password`, and `proxyUrl` from the database before constructing `TrackedClient`:
1. Extract `characterId` from `--profile=bot-<id>` in process command line
2. Query `CharactersTable` → `AccountsTable` to get `email` and `password`
3. Query `ProxySlotsTable` + `ProxyIpAddressesTable` via `account.proxySlotId` to reconstruct `proxyUrl` using `ProxyUrlBuilder`
4. Construct `TrackedClient` with all fields populated for restart capability
5. If DB lookup fails (orphaned process), log warning and track PID-only (no restart capability)

**Launch Dialog — moderate changes.** Adjust field labels for Microbot context. Remove DreamBot-specific options (`covert`, `render`) from both the dialog UI and the `LaunchConfig` model. Add Microbot-specific fields: `jvmArgs` (optional, for memory tuning like `-Xmx512m`). Keep: script name, world, script params, advanced flags.

**LaunchConfig model — updated.** Remove `covert` and `render` fields (DreamBot-specific). Add `jvmArgs` field (nullable String). This is a clean break — DreamBot is not maintained.

**TrackedClient — updated.** Must store `email`, `password`, and `proxyUrl` (full SOCKS5 URL string) for restart capability. These are populated at launch time (from caller) and at recapture time (hydrated from DB).

**AppConfigService — new config keys:**
- `microbot_jar_path` — path to Microbot shaded JAR (under `<app_data>/microbot/`)
- `microbot_jar_version` — installed JAR version tag (for update checking)
- `microbot_java_path` — path to Java 17+ binary (under `<app_data>/java/` or auto-detected)
- Note: `microbot_profiles/` directory is derived from `AppDataPath.basePath` — no config key needed

### Process Lifecycle

**Launch:**
1. User clicks Launch in Status screen (or bulk launch)
2. `StatusController` calls `BotEngine.launch()` with account/proxy/config
3. `MicrobotEngine` writes profile, spawns `java -jar` via `Process.start()`
4. Returns PID → creates `TrackedClient` → adds to WatchdogService

**Monitoring (unchanged):**
- WatchdogService polls every 10s
- Checks PID liveness via `NativeCommandsService.listJavaProcesses()`
- Death classification, quick death counting, ban detection — all existing logic

**Restart (small change):**
- `WatchdogHandlers.handleRestart()` calls `BotEngine.launch()` with stored `LaunchConfig`
- Profile regenerated fresh on each restart (no stale state)

**Stop:**
- `BotEngine.stop(pid)` → `NativeCommandsService.killProcess(pid)`
- Clean up profile directory

**App close behavior:**
- Bots are LEFT RUNNING (consistent with existing watchdog behavior — bots survive app close for recapture)
- Profile directories are NOT wiped (bots may still need them)

**Startup recovery (ordering matters):**
1. `WatchdogHandlers.recaptureRunningClients()` runs FIRST — scans Java processes for `--profile=bot-<id>` pattern, hydrates credentials from DB, creates `TrackedClient` entries
2. `MicrobotEngine.cleanStaleProfiles(livePids)` runs AFTER recapture — receives the set of recaptured PIDs, deletes profile directories whose bots are no longer running
3. This ordering prevents a race: profiles must not be deleted before recapture identifies which processes are still alive

### Database Changes

**ProxySlotsTable — add `socks_port` column.** Webshare SOCKS5 proxy port is different from the HTTP proxy port. The `socks_port` integer column stores the per-slot SOCKS5 port fetched from the Webshare API during `ProxySyncService.syncSlots()`. This requires a Drift schema migration (v5 → v6).

### Setup & Splash Screen

Setup is decomposed into focused classes that respect the 250-line service ceiling:
- **`JavaInstaller`** — downloads/verifies Eclipse Temurin JRE, manages `microbot_java_path` config
- **`MicrobotJarDownloader`** — downloads/updates Microbot JAR from GitHub Releases, manages `microbot_jar_version` config
- **`MicrobotSetupService`** — orchestrator that coordinates `PythonSetupService` + `JavaInstaller` + `MicrobotJarDownloader`, reports aggregate progress to splash screen

**Dependencies:**
1. **Java 17+** — check `java --version`. If missing or < 17, download portable Eclipse Temurin JRE (~52MB) to `<app_data>/java/`
   - Download via Adoptium API: `https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jre/hotspot/normal/eclipse`
   - Extract `.zip` to `<app_data>/java/jdk-17.x.x+x-jre/`
   - Verify SHA256 checksum from Adoptium API response headers
   - Set `microbot_java_path` config key to `<extracted_dir>/bin/java.exe`
   - Handle Windows Defender/SmartScreen: unsigned binary may need user approval on first run
2. **Microbot JAR** — check if shaded JAR exists in `<app_data>/microbot/`. If missing, download latest release from GitHub Releases API (`https://api.github.com/repos/chsami/Microbot/releases/latest`)
   - Asset filename pattern: `*-shaded.jar`
   - Store downloaded version tag in `microbot_jar_version` config key
   - Handle GitHub API rate limiting (60 req/hr unauthenticated): skip update check on failure, use cached JAR

**Splash screen:**
- Shows on every app launch
- If deps installed: fast verification (~1-2s), fades to main app
- If download needed: branded progress bar with download status (file size, speed)
- Steps displayed: Python → Java → Microbot → Load services → Main UI
- Cannot be skipped — app needs these deps

**Update checking:**
- On app start, compare local Microbot JAR version vs GitHub latest release tag
- If update available: show notice in splash, auto-download (non-blocking, dismissible)
- Java updates checked monthly or on user request

## File Changes

### New Files
```
config/services/bot_engine/bot_engine.dart              # Abstract interface (~30 lines)
config/services/bot_engine/microbot_engine.dart          # Microbot implementation (~200 lines)
config/services/bot_engine/microbot_profile_writer.dart  # Profile generation (~150 lines)
config/services/bot_engine/microbot_setup_service.dart   # Setup orchestrator (~100 lines)
config/services/bot_engine/java_installer.dart           # Java 17 download/verify (~150 lines)
config/services/bot_engine/microbot_jar_downloader.dart   # Microbot JAR download/update (~150 lines)
core/helper/proxy_url_builder.dart                       # SOCKS5 URL construction (~30 lines)
core/helper/app_data_path.dart                           # Application data path resolver (~20 lines)
feature/app/views/splash_screen.dart                     # Branded splash with progress (~150 lines)
```

### Modified Files
```
feature/Status/controller/status_controller.dart        # BotEngine.launch() with flat params + ProxyUrlBuilder
config/services/watchdog/watchdog_service.dart           # Accept BotEngine dependency, route stop() through BotEngine
config/services/watchdog/watchdog_handlers.dart          # BotEngine.launch() for restarts + Microbot recapture + DB hydration
config/services/watchdog/launch_config.dart              # Remove covert/render, add jvmArgs
config/services/watchdog/tracked_client.dart             # Store email/password/proxyUrl for restarts
config/services/app_config_service.dart                  # New config keys
config/services/proxy/proxy_sync_service.dart            # Fetch + store socks_port from Webshare API
config/services/webshare/webshare_models.dart            # Add socksPort field to WebshareProxySlot.fromJson()
domain/entities/proxy_slot.dart                          # Add socksPort field to ProxySlotEntity
data/repositories/proxy_repository_impl.dart             # Map socks_port column to entity field
core/resource/dependency_injection.dart                  # Register BotEngine before WatchdogService
data/database/tables/proxy_slots_table.dart              # Add socks_port column
data/database/database.dart                              # Migration v5 → v6 (socks_port)
feature/app.dart                                         # Splash screen replaces _buildLoadingScreen()
feature/Status/views/dialogs/launch_dialog.dart          # Remove DreamBot fields, add JVM args
```

### Deprecated
```
NativeCommandsService.runGameClient()  # No longer called, kept until cleanup
```

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Bot engine abstraction | Lightweight abstract class (3 members) | Thin enough to not over-engineer, clean enough for future engines |
| Engine selection UI | Hardcoded in DI for now | Only one engine — add UI when second engine arrives |
| Profile generation | On-the-fly at launch time | Database is source of truth, no sync drift, profiles are disposable |
| Monitoring level | PID-only (existing watchdog) | Ship fast, rich status API comes with Microbot fork (Spec #2) |
| Process launching | Dart `Process.start()` | Proven PythonRunner pattern, stdout capture, env var support |
| Dependency setup | Splash screen with progress | Professional feel, clear progress, only slow on first launch |
| DreamBot support | Removed (not maintained) | Microbot is the sole engine, clean break |

## JVM Memory Management

When running 20 instances, JVM memory tuning is critical. The launch command structure:
```
java <jvmArgs> -jar microbot.jar <appArgs>
```

**JVM flags** (before `-jar`):
- Default: `-Xmx512m` (sufficient for most scripts with safe mode)
- Configurable via `LaunchConfig.jvmArgs` field (user can override in launch dialog)
- Example overrides: `-Xmx384m` for lighter scripts, `-Xmx768m` for heavy scripts

**Application flags** (after JAR path):
- `--profile=bot-<characterId>` — always present
- `--proxy=socks5://...` — present when proxy assigned
- `--safe-mode` — disables GPU plugin (reduces GPU/VRAM load)

## Splash Screen Implementation

The splash screen **replaces** the current `_buildLoadingScreen()` in `app.dart`:
- `_initializeApp()` is extended to include `MicrobotSetupService.ensureDependencies()` before setting `_initialized = true`
- If deps are present: verification takes ~1-2s, splash fades to main app
- If downloads needed: progress bar with real-time status, download cannot be skipped

## Testing

- `MicrobotEngine.launch()` / `stop()` — mock `Process.start()`, verify command args (JVM flags before `-jar`, app flags after), verify profile generation and cleanup
- `MicrobotProfileWriter` — assert correct `.properties` file content from entity data
- `JavaInstaller` — mock HTTP client and file system for download/verify flow
- `MicrobotJarDownloader` — mock GitHub API responses, verify version comparison and asset download
- `MicrobotSetupService` — mock sub-installers, verify orchestration order and progress reporting
- `ProxyUrlBuilder` — unit test SOCKS5 URL construction from slot/IP entities, null proxy handling
- `WatchdogHandlers` restart path — mock `BotEngine`, verify `launch()` called with correct flat params
- `WatchdogHandlers` recapture path — mock DB queries, verify credential hydration from `CharactersTable` → `AccountsTable` → `ProxySlotsTable`
- `LaunchConfig` — verify serialization without deprecated DreamBot fields
- `TrackedClient` — verify `proxyUrl` field stored and recovered
- Splash screen — widget test for progress states
- Database migration v5→v6 — verify `socks_port` column added to `ProxySlotsTable`

## Dependencies

- Java 17+ (auto-installed by `JavaInstaller`)
- Microbot shaded JAR (auto-downloaded by `MicrobotJarDownloader` from GitHub Releases)
- Webshare SOCKS5 proxies (existing infrastructure, `socks_port` fetched via API)
- `path_provider` Flutter package (for `getApplicationSupportDirectory()`)
- Existing services: WatchdogService, NativeCommandsService, AppConfigService, NotificationService, ProxySyncService
