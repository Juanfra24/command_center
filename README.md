# RuneScape Bot Command Center

A Windows desktop application for managing a RuneScape bot farm — accounts, proxies, bot engine orchestration, and browser-based Jagex account creation. Integrates with a private [Microbot](https://github.com/chsami/Microbot) fork for headless OSRS automation.

## Features

- **Bot Engine** - Launch and manage Microbot (RuneLite-based OSRS client) instances per account, with auto-download of Java 17 and the latest JAR from GitHub Releases
- **Process Watchdog** - Adaptive polling, death classification, exponential backoff restart, ban detection (3 quick deaths), and proxy rotation on failure
- **Script Management** - Launch dialog with script/world/covert/render/param selection; bot status badges and farm summary bar
- **Account Management** - Track multiple RuneScape accounts and characters with proxy assignment
- **Proxy Management** - Integrated Webshare proxy support with IP rotation, replacement, IPQS fraud scoring, and score-triggered auto-rotation
- **Browser Automation** - Automated Jagex account creation using Patchright (stealth Chromium) with proxy validation
- **Dashboard** - System overview with bot status grid, proxy health, and quick actions
- **Notifications** - Persistent notification system with bell/flyout UI (auto-rotation events, ban alerts, etc.)
- **Modern UI** - Windows 11 Fluent Design with light/dark theme, branded splash screen with setup progress
- **Local Database** - SQLite via Drift ORM (schema v4) with 6 tables

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.3.4+ (Windows desktop) |
| UI | Fluent UI 4.13.0 (Windows 11 design) |
| State Management | GetX 4.6.5 |
| Database | Drift ORM 2.22.1 (SQLite) |
| Bot Engine | Microbot (private RuneLite fork) via Java 17 |
| Automation | Python 3.8+ / Patchright (patched Playwright) |
| Proxy Provider | Webshare API |
| IP Scoring | IPQualityScore API |
| CI/CD | GitHub Actions (semantic release) |

## Getting Started

### Prerequisites

- **Windows 10/11**
- **Flutter SDK** 3.3.4+ ([install guide](https://docs.flutter.dev/get-started/install/windows/desktop))
- **Visual Studio 2022** with "Desktop development with C++" workload (for Flutter Windows builds)
- **Python 3.8+** with pip (for browser automation)
- **Git**

### 1. Clone and Build

```bash
git clone <repo-url>
cd command_center
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

### 2. First Launch (Splash Screen Setup)

On first launch, the splash screen automatically installs dependencies:

1. **Python + Patchright** - Browser automation dependencies (stealth Chromium)
2. **Java 17 (Eclipse Temurin)** - Downloaded to `%APPDATA%/CommandCenter/java/`
3. **Microbot JAR** - Latest release from the private GitHub fork

If any step fails, the app still launches — bot engine features will be unavailable until dependencies are resolved.

### 3. Configure Integrations

1. **Webshare** - Settings > Integrations > Webshare > enter API key > "Connect & Sync"
2. **IPQualityScore** - Settings > Integrations > IPQS > enter API key
3. **GitHub PAT** (for private Microbot fork) - Settings > Bot Engine > enter Personal Access Token with `repo` scope

### 4. Environment Variables (Security)

Credentials are passed to bot instances via environment variables, never command-line arguments:

| Variable | Purpose |
|----------|---------|
| `CC_PROFILE_DIR` | Path to bot profile directory |
| `CC_STATUS_PORT_FILE` | Path to status port file for IPC |

Bot profiles are written to `%APPDATA%/CommandCenter/microbot_profiles/<account_id>/`.

## How It Works

```
Command Center (Flutter)
    |
    |-- Splash Screen ── MicrobotSetupService
    |                      ├── PythonSetupService (patchright + chromium)
    |                      ├── JavaInstaller (Eclipse Temurin JRE 17)
    |                      └── MicrobotJarDownloader (GitHub Releases + PAT)
    |
    |-- BotEngine (MicrobotEngine)
    |     ├── MicrobotProfileWriter (credentials.properties + commandcenter.properties)
    |     ├── Process.start() with env vars (no credentials in argv)
    |     └── NativeCommandsService (WMI COM API for process management)
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
    |     └── CC Bot Scripts (5 scripts + 6 behaviors)
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
│   ├── bot_engine/      # BotEngine, MicrobotEngine, JavaInstaller, JarDownloader, ProfileWriter, SetupService
│   ├── watchdog/        # WatchdogService, TrackedClient, LaunchConfig, Handlers
│   ├── proxy/           # AutoRotation, Replacement, Sync, ScoredIpResult
│   ├── automation/      # AutomationService, PythonRunner, ResultParser
│   ├── webshare/        # WebshareApiClient, WebshareService, ReplacementHandler
│   └── ipqs/            # IpqsApiClient, IpqsService
└── core/                # Constants, helpers, DI bindings, shared widgets

scripts/
├── account_automation.py   # CLI: validate, create-account, session
└── automation/             # Patchright automation package
```

## Database Schema (v4)

| Table | Purpose |
|-------|---------|
| `AppConfigTable` | Key-value config (API keys, theme, auto-rotation settings, Java/JAR paths, GitHub PAT) |
| `ProxySlotsTable` | Webshare proxy slots with soft delete and IP rotation tracking |
| `ProxyIpAddressesTable` | IP history per slot with IPQS fraud scoring, geo-location, ASN |
| `AccountsTable` | Jagex accounts (email, password, birthday, proxy_slot_id) |
| `CharactersTable` | Game characters linked to accounts (skills JSON, banned flag, CASCADE delete) |
| `NotificationsTable` | Persistent notifications (type, severity, read status, timestamps) |

Migrations: v1 initial > v2 soft delete > v3 cascade delete > v4 notifications

## Development

See [SETUP.md](SETUP.md) for detailed development environment setup.

```bash
flutter run -d windows                                      # Debug mode
flutter build windows --release                             # Release build
dart run build_runner build --delete-conflicting-outputs     # Regenerate Drift code
flutter test                                                # Run tests (31 test files)
flutter analyze                                             # Static analysis
dart format --set-exit-if-changed .                         # Check formatting
```

### Test Suite

31 test files covering:
- Bot engine services (7): engine, JAR downloader, Java installer, profile writer, setup service, bot status, integration
- Core services (7): app config, automation, IPQS, notification, proxy auto-rotation, proxy sync, webshare
- Data repositories (4): account, config, notification, proxy
- Feature controllers (5): status, status selection, dev tools, proxy, proxy scoring
- UI components (2): IP history list, IP score indicator
- Core utilities (4): result, loading button, app data path, proxy URL builder
- Domain entities (1): proxy IP address

## Contributing

### Commit Convention (Enforced by CI)

```
<type>(<scope>): <description>
```

| Type | Purpose | Triggers Release? |
|------|---------|-------------------|
| `feat` | New feature | Yes (minor) |
| `fix` | Bug fix | Yes (patch) |
| `perf` | Performance improvement | Yes (patch) |
| `chore` | Maintenance | No |
| `docs` | Documentation | No |
| `refactor` | Code restructure | No |
| `test` | Tests | No |

### Releases

Automated via GitHub Actions: push to `main` triggers commit lint, build, and (if releasable) version bump + GitHub Release with Windows zip.

## License

This project is private and not licensed for public use.
