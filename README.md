# RuneScape Bot Command Center

A Windows desktop application for managing and orchestrating RuneScape bot automation tasks with ease.

## Features

- **🎮 Account Management** - Track and manage multiple RuneScape accounts/characters
- **🌐 Proxy Management** - Integrated Webshare proxy support with IP rotation and quality scoring
- **🤖 Browser Automation** - Automated account creation with proxy validation using undetected Chrome
- **📊 Status Monitoring** - Real-time bot status and activity tracking  
- **🎵 Background Music** - Built-in music player with volume control
- **🎨 Modern UI** - Windows 11 Fluent Design interface
- **💾 Local Storage** - SQLite database with Drift ORM for persistent configuration

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- Flutter SDK (3.x or later)
- Windows 10/11
- Python 3.8 or higher (for browser automation)
- Webshare account (for proxy management)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/command_center.git
cd command_center
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Generate Drift database code:
```bash
dart run build_runner build
```

4. Build and run:
```bash
flutter run -d windows
```

### Python Automation Setup

The application automatically installs Python dependencies on first use. If you need to install them manually:

```bash
cd scripts
pip install -r requirements.txt
```

The automation uses SeleniumBase with undetected Chrome driver, which automatically downloads the appropriate ChromeDriver version.

## Configuration

### Webshare Integration

1. Create an account at [Webshare](https://www.webshare.io/)
2. Navigate to API Settings in your Webshare dashboard
3. Copy your API key
4. In the app, go to **Settings > Integrations > Webshare**
5. Click "Connect & Sync" and enter your API key

## Architecture

The application follows Clean Architecture principles:

### Domain Layer (`lib/domain/`)
- **Entities** - Pure Dart classes representing business objects
- **Repositories** - Abstract interfaces defining data operations

### Data Layer (`lib/data/`)
- **Database** - Drift ORM tables and database configuration
- **Repositories** - Concrete implementations of domain repositories

### Feature Layer (`lib/feature/`)
- **Controllers** - GetX controllers for state management
- **Views** - UI widgets and screens

### Services (`lib/config/services/`)
- **AutomationService** - Bridge between Flutter and Python automation scripts
- **PythonSetupService** - Manages Python dependencies and Chromium installation
- **WebshareService** - Handles Webshare API integration
- **IPQSService** - Proxy quality scoring via IP Quality Score API

### Python Automation (`scripts/`)
- **account_automation.py** - Browser automation using SeleniumBase with undetected Chrome
- Proxy validation and IP verification
- Human-like behavior patterns for anti-bot evasion

## Project Structure

```
lib/
├── config/
│   ├── services/        # Core services (Webshare, Native Commands, etc.)
│   ├── theme/           # Theme configuration
│   └── routes/          # Navigation routes
├── core/
│   ├── constants/       # App constants
│   ├── helper/          # Utility helpers
│   ├── resource/        # Dependency injection
│   └── widgets/         # Shared widgets
├── data/
│   ├── database/        # Drift ORM tables and database
│   └── repositories/    # Repository implementations
├── domain/
│   ├── entities/        # Business entities
│   └── repositories/    # Repository interfaces
└── feature/
    ├── main_menu/       # Home screen
    ├── Status/          # Account management
    ├── proxy/           # Proxy management
    └── music/           # Music player
```

## Development

### Building for Release

```bash
flutter build windows --release
```

### Regenerating Database Code

After modifying Drift tables:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Running Tests

```bash
flutter test
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is private and not licensed for public use.

## Acknowledgments

- [Fluent UI](https://pub.dev/packages/fluent_ui) - Windows 11 style widgets
- [GetX](https://pub.dev/packages/get) - State management
- [Firebase](https://firebase.google.com/) - Backend services
- [Webshare](https://www.webshare.io/) - Proxy services

---

*Made with ❤️ for the RuneScape botting community*
