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
