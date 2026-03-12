# Changelog

All notable changes to the RuneScape Bot Command Center will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
