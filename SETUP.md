# Command Center Setup Guide

## End-User Setup

### System Requirements

- **Windows 10/11**
- **Python 3.8+** with pip (for browser automation)
- Internet connection (for dependency downloads)

### First Launch

The app handles most setup automatically via a branded splash screen:

1. **Python + Patchright** - Installs browser automation dependencies and stealth Chromium
2. **Java 17 (Eclipse Temurin JRE)** - Downloaded to `%APPDATA%/CommandCenter/java/`
3. **Microbot JAR** - Latest release from the private GitHub fork

If any step fails, the app still launches — features requiring that dependency will be unavailable.

### Configure Integrations

After the splash screen completes:

1. **Webshare** - Settings > Integrations > Webshare > enter API key > "Connect & Sync"
2. **IPQualityScore** - Settings > Integrations > IPQS > enter API key
3. **GitHub PAT** - Settings > Bot Engine > enter Personal Access Token (needs `repo` scope for the private Microbot fork)

### Bot Profiles

When you launch a bot, Command Center writes a profile to `%APPDATA%/CommandCenter/microbot_profiles/<account_id>/`:

- `credentials.properties` - Account email + password (read by AutoLoginPlugin)
- `commandcenter.properties` - Script name, world, settings (read by ScriptAutoStartPlugin)

Credentials are passed to bot instances via environment variables (`CC_PROFILE_DIR`, `CC_STATUS_PORT_FILE`), never as command-line arguments.

### Troubleshooting

**Python not found:**
1. Install from [python.org](https://www.python.org/downloads/)
2. Check "Add Python to PATH" during installation
3. Restart the app

**Java download fails:**
1. Check internet connection
2. The app downloads Eclipse Temurin JRE 17 from Adoptium — ensure the domain isn't blocked
3. Alternatively, install Java 17 manually and the app will detect it

**Microbot JAR download fails:**
1. Ensure your GitHub PAT is configured (Settings > Bot Engine)
2. The PAT needs `repo` scope to access the private fork
3. Check that the PAT hasn't expired

**Dependency installation hangs:**
1. Close the app
2. Delete `%APPDATA%/CommandCenter/java/` and/or the JAR file
3. Relaunch — the splash screen will retry

---

## Developer Setup

### Prerequisites

- **Flutter SDK** 3.3.4+ ([install guide](https://docs.flutter.dev/get-started/install/windows/desktop))
- **Visual Studio 2022** with "Desktop development with C++" workload
- **Python 3.8+** with pip
- **Git**

Verify with:
```bash
flutter doctor
```

You need: Flutter SDK (stable channel) + Windows development toolchain.

### Clone and Bootstrap

```bash
git clone <repo-url>
cd command_center
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Running Locally

```bash
flutter run -d windows              # Debug mode
flutter build windows --release     # Release build (output: build/windows/x64/runner/Release/)
```

### Running Tests

```bash
flutter test                                    # Full suite (31 test files)
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

Runs `dart format --set-exit-if-changed .` on every commit.

### Commit Convention

All commits must follow conventional format (enforced by CI):

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`

Examples:
- `feat(proxy): add IP rotation scheduling`
- `fix(bot-engine): handle null JAR path on first launch`
- `test(watchdog): add ban detection unit tests`

### Python Environment (Optional Isolation)

```bash
cd scripts
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

### Adding Dependencies

**Python:** Add to `scripts/requirements.txt` — auto-installed on next app launch.

**Flutter:** Add to `pubspec.yaml` → `flutter pub get`.

## Architecture Notes

### DI Initialization Order

The app uses 3-phase dependency injection (see `lib/core/resource/dependency_injection.dart`):

1. **Sync phase** (`dependencies()`) - Controllers and lazy services
2. **Async phase** (`initializeAsyncServices()`) - DB, config, API services, MicrobotSetupService
3. **Post-setup phase** (`initializePostSetup()`) - BotEngine + WatchdogService (after splash screen)

### Data Flow: Launching a Bot

1. User clicks "Launch" in the Status screen
2. `LaunchDialog` collects: script, world, covert mode, render mode, extra params
3. `StatusController` calls `WatchdogService.launchClient(account, launchConfig)`
4. `WatchdogService` → `BotEngine.launch()`:
   - `MicrobotProfileWriter` writes credentials + config to profile directory
   - `MicrobotEngine` spawns Java process with env vars
   - Status port file is created by the Microbot instance
5. `WatchdogService` polls `localhost:<port>/status` for bot state
6. UI updates via `TrackedClient` status changes

### Security Model

- Credentials stored in SQLite (local only), passed to bots via env vars
- Log output sanitized by `PythonRunner.redact()` and `CredentialRedactor.java`
- IPQS API key sent as query param (not URL path) to avoid log exposure
- Proxy passwords obscured in UI
- All external API calls audited in `docs/security-audit.md` (Microbot fork)
