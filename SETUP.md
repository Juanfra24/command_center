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
flutter test                                    # Full suite (36 test files, 315 tests)
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

### Adding Dependencies

**Python:** Add to `scripts/requirements.txt` — auto-installed on next app launch via setup wizard.

**Flutter:** Add to `pubspec.yaml` → `flutter pub get`.

## Architecture Notes

### DI Initialization Order

The app uses 3-phase dependency injection (see `lib/core/resource/dependency_injection.dart`):

1. **Sync phase** (`dependencies()`) - Controllers and lazy services
2. **Async phase** (`initializeAsyncServices()`) - DB, config, API services, SetupOrchestrator
3. **Post-setup phase** (`initializePostSetup()`) - BotEngine + WatchdogService (after setup wizard)

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
