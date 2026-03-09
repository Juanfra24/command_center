# RuneScape Bot Command Center

A Windows desktop application for managing and orchestrating RuneScape bot automation tasks — accounts, proxies, and browser-based Jagex account creation.

## Features

- **Account Management** - Track and manage multiple RuneScape accounts and characters
- **Proxy Management** - Integrated Webshare proxy support with IP rotation, replacement, and IPQS quality scoring
- **Browser Automation** - Automated Jagex account creation using Patchright (patched Playwright) with stealth Chromium and proxy validation
- **Status Monitoring** - Real-time bot process status tracking (running/stopped)
- **Background Music** - Built-in music player
- **Modern UI** - Windows 11 Fluent Design interface with light/dark theme support
- **Local Database** - SQLite via Drift ORM for persistent storage

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Windows desktop) |
| UI | Fluent UI (Windows 11 design) |
| State Management | GetX |
| Database | Drift ORM (SQLite) |
| Automation | Python + Patchright (patched Playwright) |
| Proxy Provider | Webshare API |
| IP Scoring | IPQualityScore API |

## Getting Started

### Prerequisites

- Flutter SDK 3.x+
- Windows 10/11
- Python 3.8+ (for browser automation)
- Webshare account (for proxy management)
- IPQualityScore account (for IP scoring)

### Installation

```bash
git clone https://github.com/yourusername/command_center.git
cd command_center
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

### Python Automation Setup

The app auto-installs Python dependencies on first use. For manual setup:

```bash
cd scripts
pip install -r requirements.txt
python -m patchright install chromium
```

## Configuration

1. **Webshare** - Go to Settings > Integrations > Webshare, enter your API key, click "Connect & Sync"
2. **IPQualityScore** - Go to Settings > Integrations > IPQS, enter your API key

## Architecture

Clean Architecture with 4 layers:

```
lib/
├── domain/          # Entities + abstract repository interfaces
├── data/            # Drift tables, database, concrete repositories
├── feature/         # UI screens + GetX controllers
│   ├── main_menu/   # Dashboard overview
│   ├── Status/      # Account & character management
│   ├── proxy/       # Proxy slot management
│   └── music/       # Background music
├── config/          # Services (Automation, Webshare, IPQS, etc.), routes, theme
└── core/            # Constants, helpers, DI, shared widgets

scripts/
├── account_automation.py        # CLI entry point (validate, create-account, session)
└── automation/                  # Patchright automation package
    ├── browser.py               # Stealth browser launch/close
    ├── models.py                # Result/status data models
    ├── commands/                # Subcommand implementations
    │   ├── validate.py
    │   ├── create_account.py
    │   └── session.py
    ├── proxy.py, helpers.py     # Proxy parsing & utilities
    └── imap_poller.py           # Email polling for verification
```

## Database Schema

| Table | Purpose |
|-------|---------|
| `AppConfigTable` | Key-value app configuration |
| `ProxySlotsTable` | Webshare proxy slots (with soft delete) |
| `ProxyIpAddressesTable` | IP history per slot with IPQS scores |
| `AccountsTable` | Jagex accounts (email, password, birthday) |
| `CharactersTable` | Game characters linked to accounts |

## Development

```bash
# Run in debug mode
flutter run -d windows

# Regenerate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Build release
flutter build windows --release
```

## Releases

Releases are automated via GitHub Actions using conventional commits:

- `feat:` commits trigger a **minor** version bump
- `fix:` / `perf:` commits trigger a **patch** version bump
- `BREAKING CHANGE` triggers a **major** version bump
- Other commit types (`chore:`, `docs:`, etc.) do not trigger a release

Each release auto-generates changelog entries and publishes a GitHub Release with the Windows build.

## License

This project is private and not licensed for public use.

---

*Made for the RuneScape botting community*
