# Changelog

All notable changes to the RuneScape Bot Command Center will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Proxy Management Enhancements**
  - Automatic low-score proxy replacement feature (proxies with score < 50%)
  - Real-time display of remaining proxy replacements from Webshare subscription plan API
  - Proxy replacement counter showing available/total replacements in dialog
  - Soft delete mechanism for proxies with webshareId-based upsert to prevent duplicates
  - Proxy details display showing all low-score slots and their scores
  
- **Improved Proxy Replacement UX**
  - Replace buttons now show loading spinner during replacement operation
  - Replace buttons are disabled while replacement is in progress (both slot header and score card)
  - Persistent "Replacing Proxy..." info bar removed - only final result is shown
  
- **Interactive Home Page Stats**
  - All home page stat cards (Total Accounts, Proxy Slots, Issues) are now clickable for quick navigation
  - Pointer cursor indicates clickable stat cards
  - Issues stat card shows detailed tooltip with list of low-score proxies on hover
  - Tooltip displays slot name, IP address, and score for each low-score proxy

- **Browser Automation System**
  - Python-based automation using SeleniumBase with undetected Chrome driver
  - Automatic Python dependency installation on first use
  - Automatic Chromium/ChromeDriver installation via SeleniumBase
  - Proxy IP validation before account creation
  - Human-like behavior patterns (random delays, typing simulation)
  - WebRTC leak prevention
  
- **Account Creation Flow**
  - New character creation dialog with proxy slot selection
  - Real-time proxy validation with progress indicator
  - Cancel button to abort validation mid-process
  - 2-minute timeout protection against stuck processes
  
- **Proxy Quality Indicators**
  - Badge tooltips showing what each indicator means (VPN, Datacenter, Tor, Proxy)
  - Badges only visible when proxy has been scored
  - Improved badge styling with proper spacing

- **Home Screen Updates**
  - Character Status section showing running/stopped counts
  - Removed Quick Actions section for cleaner layout
  
- **Settings Improvements**
  - Redesigned About section with modern styling
  - App version and build info display
  - Links to GitHub and documentation

- **System Services**
  - AutomationService for Flutter-Python bridge
  - PythonSetupService for dependency management
  - Setup progress tracking with step-by-step status

### Changed
- GitHub Actions CI/CD updated from v3 to v4 (checkout, upload-artifact)
- Python requirements simplified to only seleniumbase and requests
- ComboBox items in dialogs now use single-line layout
- ProxyController now tracks and manages proxy replacement state separately from sync state

### Fixed
- Compilation errors with StatusController.runningProcessMap (now processClients)
- ProcessClient property access (pid → processId)
- FluentIcons.chrome_full_logo not found (replaced with globe)
- Python dependency conflicts in requirements.txt
- ComboBox overflow in character creation dialog
- Proxy duplication during sync operations (now uses webshareId for idempotent upsert)
- Replace button feedback during long-running replacement operations

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
