# RuneScape Bot Command Center

A cross-platform desktop application (Windows + Linux) for managing a RuneScape bot farm — accounts, proxies, bot engine orchestration, and browser-based Jagex account creation. Integrates with a private [Microbot](https://github.com/chsami/Microbot) fork for headless OSRS automation.

## Features

- **Bot Engine** - Launch and manage Microbot (RuneLite-based OSRS client) instances per account, with auto-download of Java 17 and the latest JAR from GitHub Releases
- **Process Watchdog** - Adaptive polling, death classification, exponential backoff restart, ban detection (3 quick deaths), and proxy rotation on failure
- **Script Management** - Launch dialog with script/world/covert/render/param selection; bot status badges and farm summary bar
- **Account Management** - Track multiple RuneScape accounts and characters with proxy assignment
- **Proxy Management** - Integrated Webshare proxy support with IP rotation, replacement, IPQS fraud scoring, and score-triggered auto-rotation
- **Browser Automation** - Automated Jagex account creation using Patchright (stealth Chromium) with proxy validation and IMAP-based email verification
- **IMAP Email Config** - Configure email server credentials (host/user/pass) for automated account creation email polling; onboarding-gated
- **Dashboard** - System overview with bot status grid, proxy health, and quick actions
- **Notifications** - Persistent notification system with bell/flyout UI (auto-rotation events, ban alerts, etc.)
- **Modern UI** - Windows 11 Fluent Design (renders on both platforms) with light/dark theme
- **4-Step Setup Wizard** - Guided dependency installation with progress tiles, retry, and GitHub PAT prompt
- **Local Database** - SQLite via Drift ORM (schema v7) with 6 tables and performance indices

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.3.4+ (Windows + Linux desktop) |
| UI | Fluent UI 4.13.0 (Windows 11 Fluent Design) |
| State Management | GetX 4.6.5 |
| Database | Drift ORM 2.22.1 (SQLite, schema v7) |
| Bot Engine | Microbot (private RuneLite fork) via Java 17 |
| Automation | Python 3.8+ / Patchright (patched Playwright) |
| Proxy Provider | Webshare API |
| IP Scoring | IPQualityScore API |
| CI/CD | GitHub Actions (semantic release, Windows + Linux builds) |

## Getting Started

### Prerequisites

**Windows:**
- Windows 10/11
- Flutter SDK 3.3.4+ ([install guide](https://docs.flutter.dev/get-started/install/windows/desktop))
- Visual Studio 2022 with "Desktop development with C++" workload
- Python 3.8+ with pip
- Git

**Linux:**
- Ubuntu 22.04+ / Debian 12+ (or equivalent)
- Flutter SDK 3.3.4+
- Build dependencies: `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`
- Python 3.8+ with pip and venv: `sudo apt install python3 python3-pip python3-venv`
- Git

### 1. Clone and Build

```bash
git clone <repo-url>
cd command_center
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

### 2. First Launch (Setup Wizard)

On first launch, the 4-step setup wizard automatically installs dependencies:

1. **Extract Scripts** - Bundled Python automation scripts extracted to app data dir
2. **Python Setup** - Checks python3/pip, creates venv (Linux), installs patchright + requests, installs Chromium
3. **Java 17 (Eclipse Temurin)** - Downloaded and extracted (PowerShell on Windows, tar on Linux)
4. **Microbot JAR** - Prompts for GitHub PAT, then downloads latest shaded JAR from private repo

All steps are mandatory with retry on failure. Each step shows detailed progress.

### 3. Configure Integrations

1. **Webshare** - Settings > Integrations > Webshare > enter API key > "Connect & Sync"
2. **IPQualityScore** - Settings > Integrations > IPQS > enter API key
3. **IMAP Email** - Settings > Integrations > Email > enter IMAP host/username/password (required for account creation email verification)

### 4. Environment Variables (Security)

Credentials are passed to bot instances via environment variables, never command-line arguments:

| Variable | Purpose |
|----------|---------|
| `CC_PROFILE_DIR` | Path to bot profile directory |
| `CC_STATUS_PORT_FILE` | Path to status port file for IPC |

Bot profiles are written to the app data directory under `microbot_profiles/<account_id>/`.

## How It Works

```
Command Center (Flutter)
    |
    |-- Setup Wizard ── SetupOrchestrator
    |                      ├── ScriptsExtractor (Flutter assets → app data)
    |                      ├── PythonSetupService (venv + patchright + chromium)
    |                      ├── JavaInstaller (Eclipse Temurin JRE 17)
    |                      └── MicrobotJarDownloader (GitHub Releases + PAT)
    |
    |-- BotEngine (MicrobotEngine)
    |     ├── MicrobotProfileWriter (credentials.properties + commandcenter.properties)
    |     ├── Process.start() with env vars (no credentials in argv)
    |     └── NativeCommandsService (Windows: WMI COM API / Linux: ps + kill)
    |
    |-- WatchdogService
    |     ├── Adaptive polling (5s running / 30s idle)
    |     ├── Status API polling (HTTP GET localhost:<port>/status)
    |     ├── Death classification + exponential backoff restart
    |     ├── Ban detection (3 quick deaths within window)
    |     └── Proxy rotation on failure
    |
    |-- Microbot Instance (Java)
    |     ├── StatusApiServer (localhost-only HTTP, ephemeral port)
    |     ├── AutoLoginPlugin (profile-based credentials)
    |     ├── ScriptAutoStartPlugin (plugin activation by name)
    |     └── CC Bot Scripts (5 scripts + 7 behaviors)
    |
    └── Python Automation
          ├── IP validation via proxy
          └── Jagex account creation (stealth Chromium)
```

## Architecture

Clean Architecture with 4 layers:

```
lib/
├── domain/              # Entities + abstract repository interfaces (pure Dart)
├── data/                # Drift tables, database, concrete repositories
├── feature/             # UI screens + GetX controllers
│   ├── Status/          # Account & character management, launch dialog
│   ├── proxy/           # Proxy slots, IP scoring, auto-rotation
│   ├── main_menu/       # Dashboard (bot status grid, proxy health, quick actions)
│   ├── notification/    # Bell + flyout, persistent notifications
│   ├── music/           # Background audio player
│   ├── app/             # Navigation shell, settings, onboarding, splash screen
│   └── dev_tools/       # Database viewer, SQL runner (debug only)
├── config/services/     # Business logic services
│   ├── bot_engine/      # BotEngine, MicrobotEngine, JavaInstaller, JarDownloader, ProfileWriter
│   ├── watchdog/        # WatchdogService, TrackedClient, LaunchConfig, Handlers
│   ├── proxy/           # AutoRotation, Replacement, Sync, ScoredIpResult
│   ├── automation/      # AutomationService, PythonRunner, ResultParser
│   ├── setup/           # SetupOrchestrator, ScriptsExtractor, SetupStepState, SetupMessages
│   ├── webshare/        # WebshareApiClient, WebshareService
│   └── ipqs/            # IpqsApiClient, IpqsService
└── core/                # Constants, helpers, DI bindings, shared widgets

scripts/
├── account_automation.py   # CLI: validate, create-account, session
└── automation/             # Patchright automation package
```

## Platform Abstraction

| Concern | Windows | Linux |
|---------|---------|-------|
| Process management | WMI COM API (C++ platform channel) | Pure Dart (`ps` + `kill`) |
| Java extraction | PowerShell `Expand-Archive` | `tar -xzf` |
| Python executable | `python` (launcher) | `python3` + venv (PEP 668) |
| File manager | `explorer.exe` | `xdg-open` |
| Distribution | `.zip` in GitHub Release | `.AppImage` in GitHub Release |

## Database Schema (v7)

| Table | Purpose |
|-------|---------|
| `AppConfigTable` | Key-value config (API keys, theme, auto-rotation settings, Java/JAR paths, GitHub PAT) |
| `ProxySlotsTable` | Webshare proxy slots with soft delete and IP rotation tracking |
| `ProxyIpAddressesTable` | IP history per slot with IPQS fraud scoring, geo-location, ASN (indexed: slot_id+is_active) |
| `AccountsTable` | Jagex accounts (email, password, birthday, proxy_slot_id) |
| `CharactersTable` | Game characters linked to accounts (skills JSON, banned flag, CASCADE delete, indexed: account_id) |
| `NotificationsTable` | Persistent notifications (type, severity, read status, indexed: is_read) |

Migrations: v1 initial > v2 soft delete > v3 cascade delete > v4 notifications > v5 IPQS columns > v6 socksPort > v7 performance indices

## Development

See [SETUP.md](SETUP.md) for detailed development environment setup.

```bash
# Windows
flutter run -d windows
flutter build windows --release

# Linux
flutter run -d linux
flutter build linux --release

# Code generation, tests, analysis
dart run build_runner build --delete-conflicting-outputs
flutter test                                                # 37 test files, 326 tests
flutter analyze
dart format --set-exit-if-changed .
```

### Test Suite

37 test files, 326 tests covering:
- Bot engine services (7): engine, JAR downloader, Java installer, profile writer, setup service, bot status, integration
- Watchdog (2): launch config, death classification/restart backoff/ban detection
- Core services (8): app config, automation, IMAP config, IPQS, notification, proxy auto-rotation, proxy sync, webshare
- Setup (1): scripts extractor
- Data repositories (4): account, config, notification, proxy
- Feature controllers (5): status, status selection, dev tools, proxy, proxy scoring
- Onboarding (1): onboarding service
- UI components (3): IP history list, IP score indicator, loading button
- Core utilities (5): result, app data path, proxy URL builder, native commands linux, python runner
- Domain entities (1): proxy IP address

## Release Flow

Automated semantic releases via GitHub Actions:

1. Push to `main` triggers: lint & test (Linux) → build (Windows x64 + Linux x64) → release
2. Commits analyzed: `feat:` (minor), `fix:`/`perf:` (patch), `BREAKING CHANGE` (major)
3. If releasable: bumps `pubspec.yaml`, updates `CHANGELOG.md`, tags, creates GitHub Release with Windows `.zip` + Linux `.AppImage`
4. ARM64 builds not in CI — Flutter SDK lacks ARM64 CI binaries. Build from source locally.

## License

This project is private and not licensed for public use.
