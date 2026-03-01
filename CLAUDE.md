# Command Center - Claude Code Guidelines

## Project Overview

RuneScape Bot Command Center - A Windows desktop app (Flutter + Fluent UI) for managing bot accounts, proxies, and browser automation for Jagex account creation.

## Tech Stack

- **Framework:** Flutter (Windows desktop only)
- **UI:** Fluent UI (`fluent_ui` ^4.13.0) - Windows 11 Fluent Design
- **State Management:** GetX (`get` ^4.6.5) - controllers, services, DI, reactivity
- **Database:** Drift ORM (`drift` ^2.22.1) - SQLite with code generation
- **Automation:** Python + SeleniumBase (undetected Chrome) via `scripts/account_automation.py`
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
- **PythonSetupService** - Python + SeleniumBase + ChromeDriver installer
- **NativeCommandsService** - Windows platform channel (list/kill processes, run game client)
- **OnboardingService** - Tracks setup completion (Webshare + IPQS configured)

## Python Automation (`scripts/`)

- `account_automation.py` - SeleniumBase script with subcommands: `validate`, `create-account`, `session`
- Proxy format: `username:password@p.webshare.io:80`
- Results communicated via stdout JSON after `=== RESULT ===` marker
- Chrome profiles stored in `scripts/automation_debug/profiles/`

## Current State & Known Issues

- Account creation flow exists but does NOT persist created accounts to the database
- `StatusController.getAccountsData()` has TODO placeholders for proxy resolution and character loading
- `StatusController.runPythonScript()` uses hardcoded venv path (legacy, pre-AutomationService)
- Version in pubspec.yaml (0.2.1) is behind CHANGELOG (0.4.0)

## Next Task: Create Account Feature

The account creation pipeline needs completion:
1. Python script creates Jagex accounts via browser automation
2. Dart side needs to persist the created account (email, password, DOB) to AccountsTable
3. Character creation should link to the new account
4. The full flow: select proxy slot -> validate IP -> create account -> save to DB -> create character
