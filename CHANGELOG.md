# Changelog

All notable changes to the RuneScape Bot Command Center will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.4] - 2026-03-20

### Bug Fixes

- set explicit ContentDialog background for Linux (acrylic renders as grey box) (theme)
## [0.9.3] - 2026-03-20

### Bug Fixes

- search all releases for shaded JAR (latest release may have no assets) (setup)
## [0.9.2] - 2026-03-20

### Bug Fixes

- splash screen updates during setup + PAT retry re-prompts on auth failure (setup)
## [0.9.1] - 2026-03-20

### Bug Fixes

- resolve 7 critical bugs — path on 2nd launch, pip timeout, retry stuck, PAT recovery, error boundary, dep check (setup)
- add detailed substep progress + fix retry stuck on isChecking guard (setup)
- prompt for GitHub PAT during Microbot step when not configured (setup)
## [0.9.0] - 2026-03-20

### Features

- rewrite splash screen as 4-step setup wizard with progress tiles (setup)
- wire SetupOrchestrator into DI and app lifecycle (setup)
- add SetupOrchestrator with 4-step reactive flow (setup)
- add ScriptsExtractor + bundle scripts in pubspec.yaml assets (setup)
- add platform-specific setup error messages (setup)
- add SetupStepState model and StepStatus enum (setup)
## [0.8.0] - 2026-03-20

### Features

- add Flutter Linux desktop scaffold (GTK runner) (linux)
- add Flutter Linux desktop scaffold (GTK runner) (linux)
- add PythonResolver for cross-platform python/python3 detection (python)
- cross-platform paths, file opener, USERPROFILE/HOME fallback (platform)
- platform-aware download URL, extraction, and executable detection (java)
- platform-aware NativeCommandsService registration (di)
- add NativeCommandsLinux with ps/kill implementation (native)
- add 5 CC script names to default registry (scripts)
- add Status API polling in tick loop (watchdog)
- add statusPort and lastStatus fields to TrackedClient (watchdog)
- replace --profile with --cc-profile-dir, add port polling (bot-engine)
- add BotStatus model for Status API response (bot-engine)
- point JAR downloader to private fork with PAT auth (bot-engine)
- add GitHub PAT storage for private repo access (config)
- Microbot Integration — BotEngine, WatchdogService & auto-setup (#20)
- add branded splash screen with dependency installation progress (ui)
- add MicrobotSetupService orchestrator for dependency installation (bot-engine)
- add MicrobotJarDownloader for GitHub Releases auto-download (bot-engine)
- add JavaInstaller for Eclipse Temurin JRE 17 auto-download (bot-engine)
- wire BotEngine into StatusController, update LaunchDialog, split DI phases (integration)
- wire BotEngine into WatchdogService/Handlers, replace DreamBot patterns (watchdog)
- add MicrobotEngine with Process.start() launch and profile management (bot-engine)
- add MicrobotProfileWriter for transient RuneLite profiles (bot-engine)
- add BotEngine abstract interface (bot-engine)
- add Microbot config keys (jar path, version, java path) (config)
- add socks_port column to ProxySlotsTable (migration v5→v6) (db)
- add ProxyUrlBuilder for SOCKS5 URL construction (bot-engine)
- add AppDataPath helper for application data directory resolution (bot-engine)
- unified UX improvements — data migration, proxy pane, accounts table, dashboard (#17)
- Script Management & Launch with process watchdog (#16)
- register controller in DI and add navigation entry (debug only) (dev-tools)
- add DevToolsScreen layout shell (dev-tools)
- add SqlRunnerSection with text input and results (dev-tools)
- add TableViewerSection with dropdown and data grid (dev-tools)
- add ResultDataTable shared component (dev-tools)
- add DevToolsController with table list, data loading, and SQL execution (dev-tools)

### Bug Fixes

- store ever() workers + dispose on close, fix ProxyScreen DI bypass (proxy)
- add 30s timeout to all HTTP calls to prevent event loop hangs (webshare)
- run IMAP polling in thread pool to unblock asyncio event loop (automation)
- resetOnboarding now clears API keys from SQLite, not SharedPreferences (onboarding)
- forward scriptParams to profile writer and launch args (bot-engine)
- register recaptured PIDs in engine for profile cleanup on stop (watchdog)
- wrap updateAccount in transaction + upsert characters to preserve IDs (data)
- atomic .tmp download for JAR to prevent data loss on failure (bot-engine)
- address review findings — walk class hierarchy in injectConfig, zero-thread stub pool (plan)
- add CCScript lifecycle tests + fix counts and TDD steps (plan)
- address review findings — 2 critical, 5 important fixes (plan)
- address deep review findings in engine and watchdog
- use shared HttpClient for status polling, reduce unnecessary refreshes (watchdog)
- use API URL for private repo asset downloads (bot-engine)
- correct private fork repo name to Microbot_Frieren (bot-engine)
- resolve 24 bugs from full codebase audit across all features
- address deep review findings — score labels, LoadingButton state, filter counter, stale entities (#18)
- codebase audit — 11 bug fixes across watchdog, DB, security (#21)
- clean _pidToCharacterId on natural process exit (bot-engine)
- use NativeCommandsService.killProcess() for process tree kill, replace dart:developer with project logger (bot-engine)
- resolve static analysis warnings — unnecessary cast, deprecated API, unused import
- pass MicrobotSetupService via constructor, remove hardcoded version, add error logging (ui)
- rename SetupStep to MicrobotSetupStep, add concurrency guard, sanitize error msg (bot-engine)
- remove redundant client.close(), fix test names in MicrobotJarDownloader (bot-engine)
- address code review — use project logger, fix resource cleanup in JavaInstaller (bot-engine)
- harden credential handling across automation, logging, and UI (#19) (security)
- wrap OnboardingSection checklist in Obx for reactive updates
- extend NotificationService from GetxService for Rx lifecycle management (services)
- declare accountList as RxList to preserve reactive contract
- store and dispose ever() workers in _AppState to prevent leaks
- wrap dashboard sections in Obx for reactive data updates
- convert dialog static methods to StatefulWidgets for proper disposal
- cancel previous ever() listeners in OnboardingService before re-registering
- store and cancel MusicController stream subscriptions to prevent leaks
- convert AddSlotDialog to StatefulWidget for proper controller lifecycle
- use caller's key parameter in LocalStorage instead of hardcoded 'token'
- add actions for empty account rows (accounts)

### Performance

- add indices on proxy_ip(slot_id,is_active), characters(account_id), notifications(is_read) (db)
- resolve GetX controller references once instead of per-build lookup
- batch soft-delete all proxy slots in single SQL statement
- replace eager Table with ListView.builder in AccountListSection
- use lazy Iterable chaining in getFilteredSlots instead of 3 intermediate lists
- move selection observation into ProxySlotCard to avoid full list rebuild on select
- replace N+1 account query with batch character fetch (2 queries total)
- cache scoring stats as observables instead of recomputing on every Obx access
- cache getCurrentIpForSlot with Map lookups instead of O(M) linear scans
- scope Obx wrappers in app.dart to minimize rebuild scope
- replace Table widget with ListView.builder for virtualized rendering (dev-tools)
## [0.7.0] - 2026-03-13

### Features

- add auto-rotation settings UI section
- add notification bell with badge to window title bar
- add notification card and flyout UI components
- add NotificationController
- integrate auto-rotation into scoring controller with startup trigger
- add ProxyAutoRotationService with score-triggered replacement
- add auto-rotation config keys to AppConfigService
- add NotificationService with tests
- add notification repository with Drift implementation and tests
- add NotificationEntity and repository interface
- add notifications table, bump schema to v4 (db)

### Bug Fixes

- address code review findings for auto-rotation feature
- add per-failure notification in auto-rotation service
## [0.6.0] - 2026-03-13

### Features

- add cascade delete for characters, bump schema to v3 (db)
- add file logging with rotation to logger
- add Result<T> sealed class for unified error handling

### Bug Fixes

- mask account passwords in validation result display (security)
- remove unnecessary cast in replace_proxy_dialog
- fix use_build_context_synchronously in proxy_screen (lint)
- add mounted guards for use_build_context_synchronously (lint)
- replace deprecated printTime with dateTimeFormat in logger (lint)
- replace print() calls with logger (lint)
- comprehensive app audit — 22 bug fixes across all core flows (#8)
## [0.5.0] - 2026-03-10

### Features

- semantic release, Patchright migration, and architecture refactor (#4)
- add commands, entry point, and update Dart service (scripts)
- add Patchright automation modules (Phase 1-2) (scripts)
- add automation models module (scripts)
- Add Claude configuration and guidelines for account creation pipeline
- add soft delete functionality to proxy slots (database)
- Implement Python setup and automation service for proxy validation
- add ProxyScreen for managing proxy slots with detailed views and actions

### Bug Fixes

- pin fluent_ui to 4.13.0 to prevent CI build failures (deps)
- automation logging, result parsing, and proxy score display (#6)
- lint only pushed commits, add commit convention docs (ci)
## [0.4.0] - 2026-02-15

### Added
- Fluent UI Windows 11-style interface
- Webshare proxy integration
- Proxy slot management with IP history
- Character/Account management system
- Music player with background audio
- Theme switching (Light/Dark mode)

### Changed
- Migrated from Material Design to Fluent UI
- Refactored to GetX state management

## [0.3.0] - Previous Version

### Added
- Initial Firebase Firestore integration
- Basic proxy slot tracking
- Account status monitoring

## [0.2.0] - Previous Version

### Added
- Material Design UI
- Basic navigation structure

## [0.1.0] - Initial Release

### Added
- Project scaffolding
- Basic Flutter Windows app setup
