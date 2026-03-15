# Command Center - Claude Code Guidelines

## Project Overview

RuneScape Bot Command Center - A Windows desktop app (Flutter + Fluent UI) for managing bot accounts, proxies, and browser automation for Jagex account creation.

## Tech Stack

- **Framework:** Flutter (Windows desktop only)
- **UI:** Fluent UI (`fluent_ui` ^4.13.0) - Windows 11 Fluent Design
- **State Management:** GetX (`get` ^4.6.5) - controllers, services, DI, reactivity
- **Database:** Drift ORM (`drift` ^2.22.1) - SQLite with code generation
- **Automation:** Python + Patchright (patched Playwright) via `scripts/account_automation.py`
- **APIs:** Webshare (proxy management), IPQualityScore (IP scoring)

## Architecture

Clean Architecture with 4 layers:

```
lib/
├── domain/          # Entities + abstract repository interfaces (pure Dart)
├── data/            # Drift tables, DB config, concrete repository implementations
├── feature/         # UI screens + GetX controllers (Status, Proxy, MainMenu, Music, Notification, DevTools)
├── config/          # Services, routes, theme
└── core/            # Constants, helpers, DI bindings, shared widgets
```

## Component Architecture (Layered Atomic)

Each UI feature follows: `screen -> sections -> components -> dialogs`. Each logic layer follows single-responsibility services.

### File Size Ceilings (ENFORCED)

| Layer | Max Lines | Responsibility | Naming |
|-------|-----------|----------------|--------|
| Screen | 150 | Layout shell — compose sections, no logic | `*_screen.dart` |
| Section | 300 | Meaningful chunk of a screen | `*_section.dart` |
| Component | 200 | Reusable widget, single visual concern | descriptive name |
| Dialog | 200 | Always separate file, never inline | `*_dialog.dart` |
| Controller | 300 | Presentation state only — delegates to services | `*_controller.dart` |
| Service | 250 | Single domain responsibility, orchestration | `*_service.dart` |
| API Client | 200 | HTTP transport only, returns parsed models | `*_api_client.dart` |

### Layering Rules

- Screens never call services directly — go through controllers
- Controllers never make HTTP calls — go through services
- Services never build widgets or hold UI state
- Dialogs receive data via constructor params, return results via `Navigator.pop`
- Components are `StatelessWidget` unless they need local animation/form state
- Every external API gets `*_api_client.dart` (HTTP) + `*_service.dart` (logic)

### Feature Directory Structure

```
feature/<name>/
├── views/
│   ├── <name>_screen.dart           # Layout shell
│   ├── sections/                    # Screen chunks
│   ├── components/                  # Reusable widgets
│   └── dialogs/                     # Modal dialogs
└── controller/
    └── <name>_controller.dart       # Presentation state
```

### Service Directory Structure

```
config/services/<domain>/
├── <domain>_api_client.dart         # HTTP transport only
└── <domain>_service.dart            # Business logic + orchestration
```

See `docs/plans/2026-03-08-layered-atomic-architecture-design.md` for full decomposition plan.

## Key Conventions

- **State management:** Use GetX (`GetxController`, `.obs`, `Obx()`)
- **Database:** Drift ORM with code generation (`dart run build_runner build --delete-conflicting-outputs`)
- **DI:** Services registered in `core/resource/dependency_injection.dart` (`AppBindings`)
- **Navigation:** Fluent UI `NavigationView` + `NavigationPane` (not GetX routes)
- **Entities:** Use `Equatable` for domain entities
- **Naming:** Feature folders use PascalCase for screens (e.g., `Status/`), camelCase for files

## Build & Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Generate Drift code
flutter run -d windows
flutter build windows --release
```

## Release Flow

Automated semantic releases via GitHub Actions (`.github/workflows/release.yml`):

1. Push to `main` triggers: commit lint → build → release
2. Commits are analyzed for `feat:` (minor), `fix:`/`perf:` (patch), `BREAKING CHANGE` (major)
3. If releasable commits exist: bumps `pubspec.yaml`, updates `CHANGELOG.md`, tags, creates GitHub Release with Windows zip
4. Non-releasable commits (`chore:`, `docs:`, `style:`, `refactor:`, `test:`) only build — no release

**Commit message format (enforced):**
```
<type>(<scope>): <description>
```
Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`


## Database Schema (v4)

- **AppConfigTable** - Key-value config store (webshare_api_key, ipqs_api_key, theme_mode, auto_rotation_*)
- **ProxySlotsTable** - Webshare proxy slots with soft delete, IP rotation tracking
- **ProxyIpAddressesTable** - IP history per slot with IPQS scoring, geo-location, fraud indicators
- **AccountsTable** - Jagex accounts (email, password, birthday, proxy_slot_id)
- **CharactersTable** - Game characters linked to accounts (skills JSON, banned flag, CASCADE delete on account)
- **NotificationsTable** - Persistent notifications (type, severity, read status, timestamps)

Migrations: v1 initial → v2 soft delete → v3 cascade delete → v4 notifications table

## Services

### Core Services
- **DatabaseService** - Aggregates DB + all repositories
- **AppConfigService** - Reads/writes app config from SQLite (extends GetxService)
- **WebshareService** - Webshare API (proxy list, replace IP, plan info) (extends GetxService)
- **IpqsService** - IPQualityScore API (IP fraud scoring) (extends GetxService)
- **AutomationService** - Orchestrates Python browser automation (validate IP, create account)
- **PythonSetupService** - Python + Patchright dependency installer
- **PythonDependencyChecker** - Chromium installation verification
- **NativeCommandsService** - Windows platform channel (list/kill processes, run game client)
- **OnboardingService** - Tracks setup completion (Webshare + IPQS configured) (extends GetxService)
- **NotificationService** - Notification persistence & UI dispatch (extends GetxService)

### Proxy Domain Services
- **ProxyReplacementService** - IP rotation orchestration
- **ProxySyncService** - Sync Webshare slots with local DB
- **ProxyAutoRotationService** - Score-triggered automatic IP replacement

### API Clients (HTTP transport only)
- **WebshareApiClient** - Webshare REST API
- **IpqsApiClient** - IPQualityScore REST API

## Python Automation (`scripts/`)

- `account_automation.py` - CLI entry point with subcommands: `validate`, `create-account`, `session`
- `automation/` - Patchright-based automation package:
  - `browser.py` - Stealth browser launch/close (Chromium via Patchright)
  - `models.py` - `AutomationResult` / `AutomationStatus` data models
  - `proxy.py` - Proxy URL parsing helpers
  - `helpers.py` - Shared utilities
  - `imap_poller.py` - IMAP email polling for account verification
  - `commands/` - Subcommand implementations (`validate.py`, `create_account.py`, `session.py`)
- Proxy format: `username:password@p.webshare.io:80`
- Results communicated via stdout JSON after `=== RESULT ===` marker
- Dependencies: `patchright>=1.49.0`, `requests>=2.32.0` (see `scripts/requirements.txt`)

## Features

| Feature | Path | Controllers | Key Functionality |
|---------|------|-------------|-------------------|
| **Status** | `feature/Status/` | StatusController | Account list, character creation, process management |
| **Proxy** | `feature/proxy/` | ProxyController, ProxyScoringController, ProxyReplacementController | Proxy slots, IP scoring, auto-rotation, replacement |
| **App Shell** | `feature/app/` | — | Navigation, settings, onboarding, about |
| **MainMenu** | `feature/main_menu/` | MainMenuController | Dashboard: system overview, character status, recent activity |
| **Music** | `feature/music/` | MusicController | Background audio player |
| **Notification** | `feature/notification/` | NotificationController | Bell + flyout in title bar, persistent notifications |
| **DevTools** | `feature/dev_tools/` | DevToolsController | Database viewer, SQL runner (debug only) |

## Current State

- **Version:** 0.7.0 (pubspec.yaml and CHANGELOG in sync)
- **Test suite:** 18 test files covering services, repositories, controllers, UI components, and helpers
- Layered atomic architecture enforced across all features
- Performance optimized: cached IP lookups, batched DB queries, scoped Obx rebuilds
- Rx lifecycle clean: no leaked workers, no dead observables, proper disposal throughout
- AutomationService decomposed: PythonRunner (process management) + ResultParser (output parsing)
