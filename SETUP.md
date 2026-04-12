# Command Center Setup Guide

## End-User Setup

### System Requirements

**Windows:**
- Windows 10/11
- Python 3.8+ with pip (for browser automation)
- Internet connection (for dependency downloads)

**Linux:**
- Ubuntu 22.04+ / Debian 12+ (or equivalent)
- Python 3.8+ with pip and venv: `sudo apt install python3 python3-pip python3-venv`
- Internet connection (for dependency downloads)

### First Launch

The app runs a 4-step setup wizard on first launch:

1. **Extract Scripts** - Bundled Python automation scripts are extracted to the app data directory
2. **Python Setup** - Installs browser automation dependencies (patchright + requests) and Chromium. On Linux, automatically creates a virtual environment to comply with PEP 668.
3. **Java 17 (Eclipse Temurin JRE)** - Downloaded and extracted automatically
4. **Microbot JAR** - Prompts for a GitHub Personal Access Token, then downloads the latest JAR from the private repository

All steps are mandatory. If a step fails, a retry button appears with a platform-specific fix hint (e.g., "Run: sudo apt install python3-pip" on Linux).

### Configure Integrations

After the setup wizard completes:

1. **Webshare** - Settings > Integrations > Webshare > enter API key > "Connect & Sync"
2. **IPQualityScore** - Settings > Integrations > IPQS > enter API key
3. **IMAP Email** - Settings > Integrations > Email > enter IMAP host/username/password

All three integrations are required before account creation is enabled. The app shows an onboarding checklist until they are all configured.

### IMAP Email Credentials

Account creation uses IMAP to poll for the Jagex verification email. Default provider is Gmail (`imap.gmail.com`).

| Field | Description |
|-------|-------------|
| Host | IMAP server hostname (default: `imap.gmail.com`) |
| Username | Full Gmail address |
| Password | Gmail App Password (Google Account → Security → App Passwords) |

> Gmail requires an [App Password](https://myaccount.google.com/apppasswords) — not your regular Gmail password. Enable IMAP in Gmail settings first (Settings → See all settings → Forwarding and POP/IMAP → Enable IMAP).

### GitHub PAT

The GitHub Personal Access Token is prompted during the setup wizard (Step 4). It needs:
- **Type:** Fine-grained personal access token
- **Repository access:** Select the Microbot fork only
- **Permissions:** Contents: Read-only
- Create at: https://github.com/settings/tokens?type=beta

### Bot Profiles

When you launch a bot, Command Center writes a profile to the app data directory under `microbot_profiles/<account_id>/`:

- `credentials.properties` - Account email + password (read by AutoLoginPlugin)
- `commandcenter.properties` - Script name, world, script params (read by ScriptAutoStartPlugin)

Credentials are passed to bot instances via environment variables (`CC_PROFILE_DIR`, `CC_STATUS_PORT_FILE`), never as command-line arguments.

### App Data Locations

| Platform | Path |
|----------|------|
| Windows | `%APPDATA%/CommandCenter/` |
| Linux | `~/.local/share/command_center/` |

Contents: `command_center.db`, `logs/`, `java/`, `microbot/`, `microbot_profiles/`, `scripts/`, `python_venv/` (Linux only)

### Troubleshooting

**Python not found (Windows):**
1. Install from [python.org](https://www.python.org/downloads/)
2. Check "Add Python to PATH" during installation
3. Restart the app

**Python not found (Linux):**
```bash
sudo apt install python3 python3-pip python3-venv
```

**PEP 668 / externally-managed-environment (Linux):**
The app automatically creates a venv at `~/.local/share/command_center/python_venv/`. If this fails, ensure `python3-venv` is installed.

**Java download fails:**
1. Check internet connection
2. The app downloads Eclipse Temurin JRE 17 from Adoptium — ensure the domain isn't blocked
3. Alternatively, install Java 17 manually and the app will detect it

**Microbot JAR download fails:**
1. Ensure your GitHub PAT is valid (the setup wizard will re-prompt on auth failure)
2. The PAT needs `Contents: Read-only` permission on the Microbot fork
3. Check that the PAT hasn't expired

**ContentDialog appears as grey box (Linux):**
This was a known issue with Fluent UI's acrylic backdrop on Linux. Fixed in v0.9.3+ with explicit dialog background colors.

---

## Developer Setup

### Prerequisites

**Windows:**
- Flutter SDK 3.3.4+ ([install guide](https://docs.flutter.dev/get-started/install/windows/desktop))
- Visual Studio 2022 with "Desktop development with C++" workload
- Python 3.8+ with pip
- Git

**Linux:**
- Flutter SDK 3.3.4+
- Build dependencies: `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev lld`
- Python 3.8+ with pip and venv
- Git

Verify with:
```bash
flutter doctor
```

### Clone and Bootstrap

```bash
git clone <repo-url>
cd command_center
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Running Locally

```bash
# Windows
flutter run -d windows
flutter build windows --release     # Output: build/windows/x64/runner/Release/

# Linux
flutter run -d linux
flutter build linux --release       # Output: build/linux/x64/release/bundle/
```

### Running Tests

```bash
flutter test                                    # Full suite (37 test files, 326 tests)
flutter test test/path/to/test_file.dart        # Specific file
```

### Static Analysis & Formatting

```bash
flutter analyze                              # Dart analyzer (rules in analysis_options.yaml)
dart format --set-exit-if-changed .          # Check formatting (CI enforces this)
dart format .                                # Auto-fix formatting
```

### Drift Code Generation

After modifying any Drift table in `lib/data/database/tables/`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This updates `lib/data/database/app_database.g.dart`. Always commit the regenerated file alongside table changes.

### Pre-commit Hook

```bash
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Auto-formats staged Dart files before every commit.

### Commit Convention

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`

Examples:
- `feat(proxy): add IP rotation scheduling`
- `fix(bot-engine): handle null JAR path on first launch`
- `test(watchdog): add ban detection unit tests`

### Python Environment

The app creates its own venv on Linux automatically. For development:

```bash
cd scripts
python3 -m venv .venv
source .venv/bin/activate    # Linux
.venv\Scripts\activate       # Windows
pip install -r requirements.txt
```

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production — only receives PRs from `dev` after testing |
| `dev` | Integration branch — all feature/fix branches target this |

**Workflow:**
1. Create a branch from `dev`: `git checkout -b feat/my-feature dev`
2. Open a PR targeting `dev` (never directly to `main`)
3. `main` is updated via PR from `dev` when a release is ready

CI runs on all pushes: lint → test (Linux) → build (Windows + Linux). Tests must pass before merge.

### Adding Dependencies

**Python:** Add to `scripts/requirements.txt` — auto-installed on next app launch via setup wizard.

**Flutter:** Add to `pubspec.yaml` → `flutter pub get`.

---

## VS Code Multi-Repo Workspace

Both repos live side by side under `C:\Projects\`:

```
C:\Projects\
├── bot-farm.code-workspace   ← open this to load both repos at once
├── command_center\
└── Microbot_Frieren\
```

### Opening the Workspace

Open `C:\Projects\bot-farm.code-workspace` in VS Code (**File → Open Workspace from File**). Both repos appear as separate roots in the Explorer panel. Claude Code, the terminal, and search all scope to whichever folder you're working in.

### Required Extensions

The workspace file (`bot-farm.code-workspace`) recommends these extensions — VS Code will prompt to install them on first open:

| Extension | Purpose |
|-----------|---------|
| Dart / Flutter | Flutter analysis, run/debug, hot reload |
| Extension Pack for Java | Java language server, refactoring, go-to-definition |
| Gradle for Java | Gradle task runner panel for Frieren |
| Test Runner for Java | Run/debug individual Java tests inline |

### JDK Path

The workspace file points the Java runtime to `C:\Users\Juanfra\.jdks\temurin-17`. If your JDK is elsewhere, update the `java.configuration.runtimes[0].path` key in `bot-farm.code-workspace`.

To find where your JDK is:
```powershell
where.exe java           # or: java -XshowSettings:all -version 2>&1 | findstr java.home
```

### Working in Frieren from VS Code

VS Code with the Java extension pack is a valid alternative to IntelliJ for editing Frieren. It has slightly less refactoring power but works well for script development:

- **Go to definition / Find references** work across the full codebase once Gradle imports finish
- **Gradle panel** (elephant icon in sidebar) lets you run `shadowJar`, `compileJava`, and `test` without a terminal
- **Test Runner** shows individual test results inline next to the code
- Build output and errors appear in **Problems** tab

The first Gradle import after opening takes a few minutes. Watch the status bar at the bottom for "Importing Gradle project…" to finish before navigating.

### Switching Between Repos

When both folders are open, the **integrated terminal** defaults to whichever folder has focus. Check the terminal tab label or `pwd` if you're unsure which repo you're in. Claude Code will also scope its file operations to the folder you opened it from — run it from `command_center\` for Flutter work, from `Microbot_Frieren\` for Java work.

---

## Microbot Fork (Microbot_Frieren)

Command Center is one half of this system. The other half is **Microbot_Frieren** — a private fork of [chsami/Microbot](https://github.com/chsami/Microbot), a RuneLite-based OSRS client. CC launches bots by executing the shaded JAR that this fork builds and publishes. If you want to modify bot behaviour, add scripts, change the Status API, or maintain the fork against upstream, you work in both repos.

---

### Two-Repo Workspace

The two repos are independent but tightly coupled at the JAR boundary:

```
command_center/         (Flutter — you are here)
  └── launches ──────────────────────────────────────────────────────────┐
                                                                         ↓
Microbot_Frieren/       (Java/Gradle — bot engine)               shaded JAR
  ├── commandcenter/    Our custom code (CC integration layer)
  └── ...upstream...    Upstream Microbot code (untouched where possible)
```

**How they interact at runtime:**
1. CC writes a bot profile (two `.properties` files) to app data
2. CC spawns: `java -jar microbot-shaded.jar --cc-profile-dir=<path> --status-port-file=<path>`
3. Frieren reads the profile → logs in → starts the configured script
4. Frieren writes an ephemeral port to `status.port`
5. CC's WatchdogService discovers the port and polls `GET http://127.0.0.1:<port>/status`

The two repos do **not** share code. The contract between them is:
- CLI flags (`--cc-profile-dir`, `--status-port-file`)
- Two `.properties` files
- The JSON shape of `/status`

---

### Prerequisites

- **JDK 17** — install the full JDK (not just JRE): https://adoptium.net/
- **IntelliJ IDEA** (Community is fine)
- **Git** with SSH or HTTPS access to `https://github.com/Juanfra24/Microbot_Frieren`

> The JDK you install here is for *building*. The JRE that CC downloads for *running* bots is a separate portable install under app data.

---

### Clone and Initial Setup

```bash
git clone https://github.com/Juanfra24/Microbot_Frieren.git
cd Microbot_Frieren

# Add upstream for future sync (one-time)
git remote add upstream https://github.com/chsami/Microbot.git
git fetch upstream
```

**Open in IntelliJ:**
1. **File → Open** → select the `Microbot_Frieren` root folder
2. IntelliJ detects the Gradle composite build and prompts to import — accept
3. In **File → Project Structure → SDK**, set Project SDK to JDK 17
4. In **Gradle settings** (wrench icon in Gradle panel), set Gradle JVM to the same JDK 17
5. Let IntelliJ sync (first sync downloads ~500MB of dependencies — be patient)

To run the client directly from IntelliJ, create a **Gradle Run Configuration** targeting `:runelite-client:run`.

---

### Repo Structure

```
Microbot_Frieren/
├── runelite-client/                    # Main module — the client + all plugins
│   └── src/main/java/net/runelite/client/plugins/microbot/
│       ├── commandcenter/              ← OUR CODE (never modified by upstream)
│       │   ├── AutoLoginPlugin.java    # Reads credentials.properties, injects login
│       │   ├── ScriptAutoStartPlugin.java # Reads commandcenter.properties, starts script
│       │   ├── CredentialRedactor.java # Strips passwords from logs
│       │   ├── status/
│       │   │   ├── StatusApiServer.java    # Binds 127.0.0.1:0, writes port file
│       │   │   ├── StatusApiHandler.java   # GET /status, GET /health
│       │   │   └── BotStatusModel.java     # Thread-safe JSON response builder
│       │   └── scripts/
│       │       ├── core/
│       │       │   ├── CCScript.java       # Generic base class (state machine + behaviors)
│       │       │   ├── CCBehavior.java     # Behavior interface (priority-based)
│       │       │   └── behaviors/          # 6 reusable behaviors (eating, banking, etc.)
│       │       ├── woodcutting/            # CCWoodcuttingScript + Config + Plugin + Overlay
│       │       ├── mining/
│       │       ├── fishing/
│       │       ├── cooking/
│       │       └── combat/
│       ├── api/                        ← Queryable cache API (upstream, prefer this)
│       ├── util/                       ← Legacy Rs2* utilities (upstream)
│       ├── Microbot.java               # Singleton: caches, utilities, lifecycle
│       ├── Script.java                 # Base script class (upstream)
│       └── MicrobotPlugin.java         # Main RuneLite plugin
├── runelite-api/                       # Shared API artifacts (upstream)
├── runelite-gradle-plugin/             # Build tooling (upstream)
├── cache/                              # Cache tooling (upstream)
├── runelite-jshell/                    # JShell support (upstream)
├── gradle.properties                   # microbot.version, microbot.commit.sha
├── build.gradle.kts                    # Root build — composite build config
└── docs/
    ├── development.md                  # Upstream dev guide
    ├── upstream-sync.md                # Fork maintenance procedure
    ├── security-audit.md               # Telemetry removal audit
    ├── ARCHITECTURE.md                 # Component & data flow overview
    └── decisions/                      # 4 ADRs (architecture decision records)
```

**The golden rule:** everything under `commandcenter/` is ours. Everything else is upstream. Keep custom code strictly in `commandcenter/` to minimize merge conflicts.

---

### Build Commands

```bash
# Quick compile (catches errors fast, no tests)
./gradlew :runelite-client:compileJava

# Full build, tests disabled (default — tests are opt-in)
./gradlew build

# Run tests
./gradlew :runelite-client:test

# Build shaded JAR (distributable)
./gradlew :runelite-client:shadowJar

# Clean everything
./gradlew cleanAll
```

Output JAR: `runelite-client/build/libs/runelite-client-*-shaded.jar`

> Tests are disabled globally in `runelite-client/build.gradle.kts` to keep CI fast. To enable locally, flip the `enabled` flag on `Test` tasks.

---

### Testing Your Build with Command Center

1. Build the shaded JAR: `./gradlew :runelite-client:shadowJar`
2. Rename the output to `microbot-shaded.jar` and copy it to the CC app data:
   - **Windows:** `%APPDATA%\com.example.command_center\microbot\microbot-shaded.jar`
   - **Linux:** `~/.local/share/command_center/microbot/microbot-shaded.jar`
3. Launch Command Center — it uses the local JAR immediately (no download)

**Faster alternative:** In CC's DevTools (debug build only), run:
```sql
UPDATE app_config SET value = '/absolute/path/to/runelite-client-...-shaded.jar'
WHERE key = 'microbot_jar_path';
```
This points CC directly at the Gradle output without copying.

---

### How Command Center Launches the JAR

```
java -Xmx512m \
  -jar microbot-shaded.jar \
  --cc-profile-dir=<app_data>/microbot_profiles/bot-<characterId> \
  --status-port-file=<app_data>/microbot_profiles/bot-<characterId>/status.port \
  --proxy=socks5://user:pass@ip:port \    ← omitted if no proxy assigned
  --safe-mode \
  --script-params=<params>               ← omitted if empty
```

JVM args default to `-Xmx512m` and are configurable per-launch from the CC launch dialog. Additional flags can be passed via the "Advanced flags" field.

---

### Profile Files (CC → Frieren)

CC writes these before every launch, deletes them on stop:

**`<profile-dir>/credentials.properties`** — consumed by `AutoLoginPlugin`:
```properties
email=account@example.com
password=hunter2
```

**`<profile-dir>/commandcenter.properties`** — consumed by `ScriptAutoStartPlugin`:
```properties
world=302
script=CC Woodcutter
scriptParams=
```

`script` must match the `name` field in the script plugin's `@PluginDescriptor` annotation exactly.

---

### Status API Contract (Frieren → CC)

On startup, `StatusApiServer` binds to `127.0.0.1:0` (ephemeral port) and writes the port number to `--status-port-file`. CC polls for this file every 500ms for up to 10 seconds.

Once the port is known, CC's WatchdogService polls every 5–30s (adaptive):

```
GET http://127.0.0.1:<port>/status
GET http://127.0.0.1:<port>/health   ← lightweight liveness check
```

**`/status` response (schema v1):**
```json
{
  "scriptName": "CC Woodcutter",
  "scriptActive": true,
  "xpGained": 12345
}
```

`scriptActive: false` means the script is idle or stopped — CC may trigger a restart after the configured backoff. The `xpGained` field is wired but not yet surfaced in the CC UI (reserved for a future dashboard widget).

**Do not change the JSON field names or remove fields** without a coordinated update in both repos — CC parses this JSON in `WatchdogService`.

---

### Writing a New CC Script

All CC scripts live in `commandcenter/scripts/` and follow the 5-file convention:

| File | Purpose |
|------|---------|
| `CC<Name>Config.java` | RuneLite `@ConfigGroup` config interface |
| `CC<Name>Script.java` | Extends `CCScript<StateEnum>` |
| `CC<Name>Plugin.java` | Extends `MicrobotPlugin`, `@PluginDescriptor(name = "CC <Name>")` |
| `CC<Name>Overlay.java` | Optional overlay |
| `<Name>Enum.java` | State or resource enum (if needed) |

**Step 1 — Create the script:**
```java
public class CCFishingScript extends CCScript<FishingState> {

    @Inject
    private CCFishingConfig config;

    @Override
    protected void configure() {
        registerBehavior(new EatingBehavior(config.eatAtPercent()));
        registerBehavior(new BankingBehavior());
        registerBehavior(new StuckDetectionBehavior());
        registerBehavior(new DeathRecoveryBehavior());
        setAntiBanTemplate(s -> {
            s.simulateMistakes = true;
            s.universalAntiban = true;
        });
    }

    @Override
    protected FishingState getInitialState() {
        return FishingState.FIND_SPOT;
    }

    @Override
    protected FishingState onTick(FishingState state) {
        return switch (state) {
            case FIND_SPOT -> handleFindSpot();
            case FISHING   -> handleFishing();
            case IDLE      -> FishingState.FIND_SPOT;
        };
    }
}
```

**Step 2 — Register in contract tests:**

Add an entry to both arrays in the test files:
- `CCScriptContractTest.SCRIPTS` → gets 7 free lifecycle/behavior tests
- `CCScriptConfigureContractTest.SCRIPTS` → gets 4 free configure tests

That's 11 free tests with zero effort.

**Step 3 — Register the plugin** with RuneLite by adding the `@Plugin` annotation to your plugin class (follow any existing CC plugin as a template).

---

### Built-in Behaviors

Behaviors are registered in `configure()` and run before `onTick()` on every tick (priority order — lower = higher priority):

| Behavior | Priority | Triggers When |
|----------|----------|---------------|
| `DeathRecoveryBehavior` | 5 | Player is dead |
| `EatingBehavior` | 10 | HP% below threshold |
| `StuckDetectionBehavior` | 15 | No movement for N ticks |
| `LootingBehavior` | 40 | Configured items on ground within radius |
| `BuryBonesBehavior` | 45 | Bones in inventory |
| `BankingBehavior` | 50 | Inventory full / deposit needed |

All behaviors implement `CCBehavior`: `priority()`, `name()`, `shouldActivate()`, `execute()`, `reset()`.

---

### Queryable API (prefer over legacy `Rs2*` calls)

```java
// Find nearest NPC by name
var banker = Microbot.getRs2NpcCache().query()
    .withName("Banker")
    .nearestOnClientThread();

// Find ground item within radius
var coins = Microbot.getRs2TileItemCache().query()
    .withName("Coins")
    .within(10)
    .firstOnClientThread();
```

Rules:
- Always resolve queries on the client thread using `*OnClientThread()` terminal methods
- Never instantiate caches directly — only access via `Microbot.getRs2XxxCache()`
- Cache within a tick if reusing the result more than once
- Full reference: `runelite-client/src/main/java/.../microbot/api/QUERYABLE_API.md`

---

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production — receives PRs from `dev`, triggers CI release build |
| `dev` | Integration branch — all feature/fix branches target this |
| `upstream-tracking` | Mirror of `chsami/Microbot` `main` — never commit here directly |

CI runs on push to `main`: builds the shaded JAR, increments version tag (`v1.0.N`), creates a GitHub Release.

---

### Fork Maintenance — Syncing Upstream

Upstream (`chsami/Microbot`) is actively developed. Sync regularly (monthly or when upstream has fixes you want):

```bash
# 1. Fetch latest upstream
git fetch upstream

# 2. Update the mirror branch (fast-forward only — no custom commits here)
git checkout upstream-tracking
git merge upstream/main

# 3. Merge into dev
git checkout dev
git merge upstream-tracking

# 4. Resolve conflicts (see below), then verify
./gradlew :runelite-client:build -x test

# 5. Open PR: dev → main to trigger release
```

**Where conflicts happen:**

Since all our code is under `commandcenter/`, upstream never touches it directly. Conflicts are limited to:

| File | Why it conflicts |
|------|-----------------|
| `gradle.properties` | `microbot.version` bumped in both |
| `build.gradle.kts` | Occasional Gradle config changes |
| Specific upstream scripts | If upstream modifies a script we also edited |

**Conflict resolution strategy:**
- `gradle.properties` — keep our `microbot.version`, take upstream's other values
- Build files — read both sides carefully; usually take upstream's structure, re-apply our additions
- `commandcenter/` — should never conflict (if it does, upstream touched our namespace — investigate)

**What not to touch:**
- Do not remove RuneLite core telemetry (it will conflict every sync) — it's gated via `--disable-telemetry` flag
- Do not modify upstream plugin files unless absolutely necessary — prefer `commandcenter/` for all custom logic
- Keep the security removals (MicrobotApi, MicrobotVersionChecker, RandomFactClient) — re-apply them after each sync if upstream re-adds

**Full audit of what was removed:** `docs/security-audit.md`

---

## Architecture Notes

### DI Initialization Order

The app uses 3-phase dependency injection (see `lib/core/resource/dependency_injection.dart`):

1. **Sync phase** (`dependencies()`) - Controllers and lazy services registered in GetX
2. **Async phase** (`initializeAsyncServices()`) - Sequential init:
   1. `DatabaseService` (no deps)
   2. `AppConfigService` (depends: DB)
   3. `WebshareService` (depends: AppConfig)
   4. `ImapConfigService` (depends: DB)
   5. `IpqsService` (depends: DB)
   6. `PythonSetupService` (background)
   7. `AutomationService` (depends: Python)
   8. `OnboardingService` (depends: Webshare, IPQS, **Imap**)
   9. `NotificationService` (depends: DB)
   10. `MicrobotSetupService` → `SetupOrchestrator` (depends: Python, AppConfig)
3. **Post-setup phase** (`initializePostSetup()`) - `BotEngine` + `WatchdogService` (after setup wizard completes)

Between phases 2 and 3, the app triggers a `setState` so the splash screen can observe the `SetupOrchestrator`'s reactive step states in real-time.

### Data Flow: Launching a Bot

1. User clicks "Launch" in the Status screen
2. `LaunchDialog` collects: script, world, script params, JVM args, advanced flags
3. `StatusController` calls `WatchdogService.track(trackedClient)`
4. `WatchdogService` → `BotEngine.launch()`:
   - `MicrobotProfileWriter` writes credentials + config to profile directory
   - `MicrobotEngine` spawns Java process with env vars
   - Status port file is created by the Microbot instance
5. `WatchdogService` polls `localhost:<port>/status` for bot state
6. UI updates via `TrackedClient` status changes

### Security Model

- Credentials stored in SQLite (local only), passed to bots via env vars
- Log output sanitized by `PythonRunner.redact()` and `CredentialRedactor.java`
- IPQS API key in URL path segment (required by IPQS API spec)
- Proxy passwords obscured in UI
- Python stderr redacted before embedding in error results
- Account creation passwords masked in success notifications
- All external API calls audited in `docs/security-audit.md` (Microbot fork)

### Platform Abstraction

- `NativeCommandsService` — abstract interface → `NativeCommandsWindows` (WMI C++) / `NativeCommandsLinux` (Dart ps/kill)
- `JavaInstaller` — downloads `.zip` (Windows) or `.tar.gz` (Linux), extracts with PowerShell or tar
- `PythonResolver` — resolves `python` (Windows) or `python3` (Linux), creates venv on Linux for PEP 668 compliance
- `openInFileManager()` — `explorer.exe` (Windows) / `xdg-open` (Linux)
