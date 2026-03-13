# Changelog

All notable changes to the RuneScape Bot Command Center will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
