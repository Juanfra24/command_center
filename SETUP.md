# Command Center Setup Guide

## Automatic Setup

The application will automatically check and install Python dependencies on first run. No manual intervention required!

## Requirements

### System Requirements
- **Python 3.8+** (with pip)
- Windows OS (for native commands)
- Internet connection (for dependency installation)

### Python Dependencies
The following Python packages will be automatically installed:
- `patchright` - Stealth browser automation (patched Playwright for Chromium)
- `requests` - HTTP client for API calls

See [scripts/requirements.txt](scripts/requirements.txt) for specific versions.

### Flutter/Dart Dependencies
All Flutter dependencies are managed in `pubspec.yaml` and will be installed with:
```bash
flutter pub get
```

## Manual Python Setup (Optional)

If you prefer to set up Python dependencies manually:

```bash
cd scripts
python -m pip install -r requirements.txt
```

## Troubleshooting

### Python not found
If the app reports "Python not found":
1. Install Python from [python.org](https://www.python.org/downloads/)
2. Make sure to check "Add Python to PATH" during installation
3. Restart the application

### Dependency installation fails
If automatic installation fails:
1. Open a terminal
2. Navigate to the `scripts` folder
3. Run: `python -m pip install -r requirements.txt --user`
4. Restart the application

### Check Python Setup Status
The app provides a Python setup service that shows:
- Installation progress
- Any errors that occurred
- Current setup status

You can access this information through the automation service logs.

## Updating Dependencies

### Python Dependencies
To update Python packages:
```bash
cd scripts
python -m pip install -r requirements.txt --upgrade
```

### Flutter Dependencies
To update Flutter packages:
```bash
flutter pub upgrade
```

## Development Environment Setup

### Flutter SDK

1. Install the Flutter SDK by following the [official guide](https://docs.flutter.dev/get-started/install/windows/desktop).
2. Ensure the `flutter` command is on your PATH.
3. Run `flutter doctor` to verify your installation. You need:
   - Flutter SDK (stable channel)
   - Windows development toolchain (Visual Studio 2022 with "Desktop development with C++" workload)

### Clone and Bootstrap

```bash
git clone <repo-url>
cd command_center
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Running Locally

Launch the app on Windows:

```bash
flutter run -d windows
```

For a release-mode build:

```bash
flutter build windows --release
```

The built executable will be in `build/windows/x64/runner/Release/`.

### Running Tests

Run the full test suite:

```bash
flutter test
```

Run a specific test file:

```bash
flutter test test/path/to/test_file.dart
```

### Static Analysis

Run the Dart analyzer to catch lint issues:

```bash
flutter analyze
```

The analyzer rules are configured in `analysis_options.yaml`.

### Code Formatting

Check formatting (CI enforces this):

```bash
dart format --set-exit-if-changed .
```

Auto-fix formatting:

```bash
dart format .
```

### Drift Code Generation

After modifying any Drift table definition in `lib/data/database/tables/`, regenerate the companion code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This updates `lib/data/database/app_database.g.dart`. Always commit the regenerated file alongside your table changes.

### Commit Message Convention

All commits must follow the conventional format:

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`, `revert`

Examples:
- `feat(proxy): add IP rotation scheduling`
- `fix(db): handle null proxy slot on account deletion`
- `docs: update SETUP.md with dev instructions`

## Development Notes

### Python Environment
The app uses the system Python installation. For development isolation, you can create a virtual environment:

```bash
cd scripts
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Then update the automation service to use `.venv\Scripts\python.exe`.

### Adding New Python Dependencies
1. Add the package to `scripts/requirements.txt`
2. The app will automatically install it on next run
3. Or manually install: `pip install <package>`

### Adding New Flutter Dependencies
1. Add to `pubspec.yaml` under `dependencies`
2. Run `flutter pub get`
3. Import in your Dart files

### Pre-commit Hook (Recommended)
Install the formatting pre-commit hook to catch issues before push:

```bash
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

This runs `dart format --set-exit-if-changed .` on every commit.

## Architecture

### Python Scripts
- **account_automation.py** - CLI entry point (validate, create-account, session)
- **automation/** - Patchright-based automation package
- **requirements.txt** - Python dependencies

### Flutter Services
- **PythonSetupService** - Manages Python dependency installation
- **AutomationService** - Bridges Flutter to Python scripts
- Automatically initialized on app startup

## Security Notes

- Python scripts run locally on your machine
- No data is sent to external servers (except target websites)
- Proxy credentials are handled securely in memory
- All automation uses stealth techniques to avoid detection
