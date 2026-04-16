# Command Center - Claude Code Guidelines

## Project Overview

RuneScape Bot Command Center - A cross-platform desktop app (Flutter + Fluent UI, Windows + Linux) for managing a bot farm: accounts, proxies, bot engine orchestration (Microbot/RuneLite), and browser-based Jagex account creation.

## Tech Stack

- **Framework:** Flutter (Windows + Linux desktop), SDK >=3.3.4
- **UI:** Fluent UI (`fluent_ui` 4.13.0 pinned) - Windows 11 Fluent Design (renders on both platforms)
- **State Management:** GetX (`get` ^4.6.5) - controllers, services, DI, reactivity
- **Database:** Drift ORM (`drift` ^2.22.1) - SQLite with code generation
- **Bot Engine:** Microbot (private RuneLite fork) via Java 17 (Eclipse Temurin)
- **Automation:** Python + Patchright (patched Playwright) via `scripts/account_automation.py`
- **APIs:** Webshare (proxy management), IPQualityScore (IP scoring), GitHub Releases (JAR downloads)

## Architecture

Clean Architecture with 4 layers:

```
lib/
├── domain/          # Entities + abstract repository interfaces (pure Dart)
├── data/            # Drift tables, DB config, concrete repository implementations
├── feature/         # UI screens + GetX controllers (Status, Proxy, MainMenu, Music, Notification, DevTools, App)
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
├── controller/
│   └── <name>_controller.dart       # Presentation state
└── data/                            # Feature-local models (optional)
```

### Service Directory Structure

```
config/services/<domain>/
├── <domain>_api_client.dart         # HTTP transport only
├── <domain>_service.dart            # Business logic + orchestration
└── <domain>_models.dart             # Service-local DTOs (optional)
```

## Key Conventions

- **State management:** Use GetX (`GetxController`, `.obs`, `Obx()`)
- **Database:** Drift ORM with code generation (`dart run build_runner build --delete-conflicting-outputs`)
- **DI:** Services registered in `core/resource/dependency_injection.dart` (`AppBindings`) — 3-phase init (see below)
- **Navigation:** Fluent UI `NavigationView` + `NavigationPane` (not GetX routes)
- **Entities:** Use `Equatable` for domain entities
- **Naming:** Feature folders use PascalCase for screens (e.g., `Status/`), camelCase for files
- **Security:** Credentials via env vars (never argv), log sanitization via `PythonRunner.redact()`, IPQS key out of URL path

## Build & Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Generate Drift code

# Windows
flutter run -d windows
flutter build windows --release

# Linux (requires: clang cmake ninja-build pkg-config libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev)
flutter run -d linux
flutter build linux --release
```

## Release Flow

Automated semantic releases via GitHub Actions (`.github/workflows/release.yml`):

1. Push to `main` triggers: commit lint → lint & test (Linux) → build (Windows x64 + Linux x64) → release
2. Commits are analyzed for `feat:` (minor), `fix:`/`perf:` (patch), `BREAKING CHANGE` (major)
3. If releasable commits exist: bumps `pubspec.yaml`, updates `CHANGELOG.md`, tags, creates GitHub Release with Windows zip + Linux AppImage
4. Non-releasable commits (`chore:`, `docs:`, `style:`, `refactor:`, `test:`) only build — no release
5. ARM64 builds (Windows/Linux) not in CI — Flutter SDK lacks ARM64 CI binaries. Build from source locally.

**Commit message format (enforced):**
```
<type>(<scope>): <description>
```
Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`

## Database Schema (v7)

- **AppConfigTable** - Key-value config store (API keys, theme, auto-rotation settings, Java/JAR paths, GitHub PAT)
- **ProxySlotsTable** - Webshare proxy slots with soft delete, IP rotation tracking
- **ProxyIpAddressesTable** - IP history per slot with IPQS scoring, geo-location, fraud indicators (indexed: slot_id+is_active)
- **AccountsTable** - Jagex accounts (email, password, birthday, proxy_slot_id)
- **CharactersTable** - Game characters linked to accounts (skills JSON, banned flag, CASCADE delete on account, indexed: account_id)
- **NotificationsTable** - Persistent notifications (type, severity, read status, timestamps, indexed: is_read)

Migrations: v1 initial → v2 soft delete → v3 cascade delete → v4 notifications → v5 IPQS columns + defaultScriptName → v6 socksPort → v7 performance indices

## Dependency Injection (3-Phase)

Registered in `core/resource/dependency_injection.dart` (`AppBindings`):

### Phase 1: `dependencies()` (synchronous)
- `AppDataPath`, `MusicController`, `NativeCommandsService` (permanent)
- Feature controllers (lazy, fenix=true): MainMenu, Status, StatusSelection, Proxy, ProxyScoring, ProxyReplacement, Notification
- Proxy services (lazy): ProxyReplacementService, ProxySyncService, ProxyAutoRotationService
- DevToolsController (debug only)

### Phase 2: `initializeAsyncServices()`
1. DatabaseService (no deps)
2. AppConfigService (depends: DB)
3. WebshareService (depends: AppConfig)
4. IpqsService (depends: DB)
5. PythonSetupService (background init)
6. AutomationService (depends: Python)
7. OnboardingService (depends: Webshare, IPQS)
8. NotificationService (depends: DB)
9. MicrobotSetupService (depends: PythonSetup, AppConfig → JavaInstaller + JarDownloader)

### Phase 3: `initializePostSetup()` (after splash screen dependencies install)
1. BotEngine/MicrobotEngine (depends: AppConfig for Java/JAR paths, NativeCommands)
2. WatchdogService (depends: BotEngine, Notification, ProxyAutoRotation, DB repos)

Skips BotEngine if Java path is unavailable (app still works without bot engine).

## Services

### Bot Engine Services (`config/services/bot_engine/`)
- **BotEngine** (abstract) - Interface for launching/stopping bot instances
- **MicrobotEngine** - Concrete: Process.start() with env vars, profile management
- **MicrobotSetupService** - Orchestrates dependency installation (Python + Java + JAR)
- **JavaInstaller** - Downloads Eclipse Temurin JRE 17 (platform-aware: .zip/PowerShell on Windows, .tar.gz/tar on Linux)
- **MicrobotJarDownloader** - Downloads latest JAR from GitHub Releases (PAT auth for private repo)
- **MicrobotProfileWriter** - Writes `credentials.properties` + `commandcenter.properties` per account

### Watchdog Services (`config/services/watchdog/`)
- **WatchdogService** - Process monitoring with adaptive polling (5s/30s), startup recapture, status API polling
- **WatchdogHandlers** - Death classification, exponential backoff restart, ban detection, proxy rotation
- **TrackedClient** - In-memory model per running bot (status, statusPort, lastStatus, deathCount)
- **LaunchConfig** - Presentation model for launch parameters (script, world, covert, render, params)

### Core Services
- **DatabaseService** - Aggregates DB + all repositories
- **AppConfigService** - Reads/writes app config from SQLite (extends GetxService)
- **WebshareService** - Webshare API (proxy list, replace IP, plan info) (extends GetxService)
- **IpqsService** - IPQualityScore API (IP fraud scoring) (extends GetxService)
- **AutomationService** - Orchestrates Python browser automation (validate IP, create account)
- **PythonSetupService** - Python + Patchright dependency installer
- **PythonDependencyChecker** - Chromium installation verification
- **NativeCommandsService** - Abstract interface for OS process operations (list/kill Java processes)
  - **NativeCommandsWindows** - Windows: WMI COM API via platform channel
  - **NativeCommandsLinux** - Linux: pure Dart using `ps`/`kill`
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
| **Status** | `feature/Status/` | StatusController, StatusSelectionController | Account table, character creation, launch dialog, bot status badges, farm summary bar |
| **Proxy** | `feature/proxy/` | ProxyController, ProxyScoringController, ProxyReplacementController | Proxy slots, IP scoring, auto-rotation, replacement, linked characters |
| **App Shell** | `feature/app/` | — | Navigation, settings, onboarding, splash screen (dependency setup progress) |
| **MainMenu** | `feature/main_menu/` | MainMenuController | Dashboard: bot status grid, proxy health overview, quick actions |
| **Music** | `feature/music/` | MusicController | Background audio player |
| **Notification** | `feature/notification/` | NotificationController | Bell + flyout in title bar, persistent notifications |
| **DevTools** | `feature/dev_tools/` | DevToolsController | Database viewer, SQL runner (debug only) |

## Platform Abstraction

Process management, Java installation, Python resolution, and file opening are abstracted behind platform-aware helpers:

- **NativeCommandsService** - abstract → Windows (WMI C++) / Linux (Dart ps/kill)
- **JavaInstaller** - `Platform.isWindows` branching for download URL, extraction, executable name
- **PythonResolver** - `python3` (Linux) / `python` (Windows) with caching (`core/helper/python_resolver.dart`)
- **`openInFileManager()`** - `explorer.exe` (Windows) / `xdg-open` (Linux) (`core/helper/platform_open.dart`)
- **DI wiring** - `Platform.isWindows ? NativeCommandsWindows() : NativeCommandsLinux()`

## Current State

- **Version:** 0.9.5 (pubspec.yaml and CHANGELOG in sync)
- **Platforms:** Windows x64, Linux x64 (ARM64 build-from-source only)
- **Test suite:** 36 test files, 315 tests covering bot engine, watchdog handlers, services, repositories, controllers, UI components, and helpers
- **Feature files:** 94 Dart files across 7 features
- Layered atomic architecture enforced across all features
- Performance optimized: cached IP lookups, batched DB queries, scoped Obx rebuilds, DB indices on FK columns
- Rx lifecycle clean: no leaked workers, no dead observables, proper disposal throughout
- AutomationService decomposed: PythonRunner (process management) + ResultParser (output parsing)
- Security hardened: credentials via env vars, log sanitization, IPQS key in URL path (not query), proxy password obscured in UI, stderr redacted in error results
- App shell decomposed: app.dart (160 lines) + extracted title bar, navigation, lifecycle components
- Setup flow: 4-step wizard (scripts extraction, Python/venv, Java 17, Microbot JAR) with PAT prompt, retry, progress tiles
- Python venv: auto-created on Linux to bypass PEP 668 externally-managed-environment

## UX Style Guide (ENFORCED)

All UI code must follow these conventions. Violations should be fixed on sight.

### Semantic Color Tokens

**Never use raw `Colors.green`, `Colors.red`, `Colors.orange`, `Colors.grey`, `Colors.blue`, or hex `Color(0xFF...)` for status/state colors.** Use `StatusColors.of(context)` from `lib/config/theme/status_colors.dart`.

| Token | Meaning | Usage |
|-------|---------|-------|
| `colors.success` | Running, active, healthy, created, add | Badges, icons, borders |
| `colors.error` | Banned, failed permanently, danger, delete | Badges, icons, destructive buttons |
| `colors.warning` | Restarting, retrying, poor score, caution | Badges, InfoBar, attention cards |
| `colors.info` | Awaiting, validating, in-progress | Badges, progress containers |
| `colors.muted` | Stopped, inactive, unscored, disabled | Badges, placeholder text |
| `colors.fair` | Moderate score, acceptable but not ideal | Proxy health bar, score badges |

Background tints: use `colors.successBg()`, `colors.errorBg()`, etc. Default alpha is 0.15.

```dart
final colors = StatusColors.of(context);
// Badge with background
Container(
  decoration: BoxDecoration(color: colors.successBg()),
  child: Text('Running', style: TextStyle(color: colors.success)),
)
```

### Destructive Actions

- **Delete/Stop confirmation**: Always show a `ContentDialog` before destructive operations (delete account, stop all bots, unlink service)
- **Button styling**: Cancel is `FilledButton` (primary/safe). Destructive action is `Button` with red foreground:
  ```dart
  Button(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(StatusColors.of(ctx).error),
    ),
    onPressed: () => Navigator.pop(ctx, true),
    child: const Text('Delete'),
  )
  ```
- **Never** use `FilledButton` for destructive actions — it makes them look like the primary/safe choice

### Error Handling in UI

- **Never swallow errors silently**: No empty `catch (_) {}` blocks in UI code. Always surface feedback:
  ```dart
  catch (e) {
    if (!context.mounted) return;
    displayInfoBar(context, builder: (ctx, close) => InfoBar(
      title: const Text('Launch failed'),
      content: Text('$e'),
      severity: InfoBarSeverity.error,
    ));
  }
  ```
- **LoadingButton**: Use `errorLabel` parameter for contextual error messages instead of generic "Failed"
- **Error messages must include cause + recovery path** — not just "Error" or "Failed"

### Form Validation

- **Required fields**: Mark with `*` in the label: `InfoLabel(label: 'Slot Name *', ...)`
- **Inline errors**: Show error text below the field, not in a distant InfoBar toast:
  ```dart
  InfoLabel(
    label: 'Port *',
    child: TextBox(controller: _portController, ...),
  ),
  if (_portError != null)
    Text(_portError!, style: TextStyle(fontSize: 12, color: StatusColors.of(context).error)),
  ```
- **Validate on submit, clear on edit**: Run `_validate()` on submit. Clear individual field errors `onChanged`
- **API key fields**: Use `obscureText: true` and mark as required

### Interactive Elements

- **No raw `GestureDetector` + `MouseRegion` for clickable text**: Use `HyperlinkButton` instead — it provides focus ring, keyboard nav, and hover/pressed states
- **Clickable cards**: Wrap with `HoverButton` + `FocusBorder` for proper focus/keyboard support:
  ```dart
  HoverButton(
    onPressed: onTap,
    cursor: SystemMouseCursors.click,
    builder: (context, states) => FocusBorder(
      focused: states.isFocused,
      child: card,
    ),
  )
  ```

### Typography in Data Tables

- **Headers**: Use `theme.typography.caption` with `fontWeight: FontWeight.w600`
- **Primary cell content** (names, emails): Use `theme.typography.body` (14px)
- **Secondary cell content** (metadata, timestamps): Use `theme.typography.caption` (12px)
- **Never hardcode `fontSize: 12`** for primary content — always use theme typography

### Color-Only Information

- **Never convey meaning by color alone**: Pair color with text labels, icons, or tooltips
- **Health bars / progress bars**: Add `Tooltip` with label + count to each colored segment
- **Status badges**: Always include text label alongside the colored dot

### Empty States

Every empty state must include:
1. An icon (using `theme.resources.textFillColorSecondary` for muted color)
2. A title ("No characters found")
3. A description ("Create characters in the Accounts page to see them here.")
4. A CTA when applicable (`HyperlinkButton` to navigate, or action button)

### Accent Color Swatch

The system accent swatch generates proper HSL lightness variants (not flat identical colors). This ensures hover, pressed, and disabled states are visually distinct. The swatch is built via `FluentAppTheme._buildAccentSwatch()`.

### Toast Notifications

- Use `showInfoBarToast()` from `info_bar_helper.dart` for user feedback
- Toast severity colors derive from `StatusColors` for consistency
- Background colors for toasts use hardcoded dark/light surface tones (not alpha-blended) for readability
- Auto-dismiss: 5s for non-errors, persistent for errors
