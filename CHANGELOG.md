# Changelog

All notable changes to the RuneScape Bot Command Center will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Custom Windows title bar with minimize, maximize, and close buttons
- Onboarding flow for first-time setup
- Create character button in Accounts section
- Music volume control slider in Settings
- AppConfigService for Firestore-based configuration persistence
- Webshare API integration with single "Connect & Sync" button
- Unlink option for configured Webshare API key
- Clickable onboarding checklist items
- Enhanced slot selection UI with visual feedback
- Custom RuneScape app icon for Windows taskbar

### Changed
- Consolidated "Test Connection" and "Save & Sync" into single button with progress states
- Simplified onboarding to single step: "Connect Webshare & Sync Proxies"
- Merged Sync and Refresh buttons into single "Sync & Refresh" button in Proxy screen
- "Go to Settings" now navigates to settings tab instead of showing dialog
- Default music volume lowered to 10%
- NavigationPane uses auto display mode for better responsiveness
- Improved async service initialization for proper dependency order

### Fixed
- API key save failure due to improper async service initialization
- Duplicate proxy slots created on multiple sync attempts
- Navigation pane button stacking issue

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
