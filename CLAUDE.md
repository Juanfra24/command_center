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
├── feature/         # UI screens + GetX controllers (Status, Proxy, MainMenu, Music)
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

## Database Schema (v2)

- **AppConfigTable** - Key-value config store (webshare_api_key, ipqs_api_key, theme_mode)
- **ProxySlotsTable** - Webshare proxy slots with soft delete
- **ProxyIpAddressesTable** - IP history per slot with IPQS scoring
- **AccountsTable** - Jagex accounts (email, password, birthday, proxy_slot_id)
- **CharactersTable** - Game characters linked to accounts (skills JSON, banned flag)

## Services

- **DatabaseService** - Aggregates DB + all repositories
- **AppConfigService** - Reads/writes app config from SQLite
- **WebshareService** - Webshare API (proxy list, replace IP, plan info)
- **IpqsService** - IPQualityScore API (IP fraud scoring)
- **AutomationService** - Orchestrates Python browser automation (validate IP, create account)
- **PythonSetupService** - Python + Patchright dependency installer
- **NativeCommandsService** - Windows platform channel (list/kill processes, run game client)
- **OnboardingService** - Tracks setup completion (Webshare + IPQS configured)

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

## Current State & Known Issues

- Account creation flow persists accounts to DB via AutomationService.createAccount()
- Automation migrated from SeleniumBase to Patchright (patched Playwright) for stealth browser automation
- AutomationService decomposed: PythonRunner handles process management, ResultParser handles output parsing
- Version in pubspec.yaml (0.2.1) is behind CHANGELOG (0.4.0)
- Architecture refactor in progress: decomposing heavy files per layered atomic design (see docs/plans/)
