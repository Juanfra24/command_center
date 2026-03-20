# Linux Compatibility — Design Spec

**Goal:** Make Command Center build and run on Linux alongside Windows, with near-identical UI (Fluent UI) and functionality.

**Approach:** Platform abstraction layer for the Windows-specific code points. No UI framework changes — Fluent UI and window_manager already support Linux. Pure Dart for Linux process management (no native C++ needed — `/proc` exposes full command lines natively).

**Distribution:** AppImage (portable, single file, works on all distros).

---

## Component 1: NativeCommandsService Abstraction

**Problem:** Current `NativeCommandsService` calls a C++ method channel that uses WMI COM API to list Java processes and `taskkill` to kill them. This only works on Windows.

**Solution:** Split into an abstract interface + two platform implementations. DI picks the right one.

### Files

- **Modify:** `lib/config/services/native_commands_service.dart` — becomes abstract interface
- **Create:** `lib/config/services/native_commands_windows.dart` — existing C++ method channel logic (extracted, unchanged)
- **Create:** `lib/config/services/native_commands_linux.dart` — pure Dart implementation

### NativeCommandsService (abstract)

```dart
abstract class NativeCommandsService {
  Future<List<ProcessClient>> listJavaProcesses();
  Future<void> killProcess(int pid);
}
```

### NativeCommandsWindows

Extracted from current `NativeCommandsService`. Keeps the `MethodChannel('com.onemanco/commands')` bridge to the existing C++ WMI code. No changes to the C++ side.

**Note:** The C++ handler in `windows/runner/main.cpp` also registers a `runGameClient` method (legacy DreamBot launcher). This method is dead code — never called from Dart since the Microbot integration. It will NOT be ported to Linux and can be removed from `main.cpp` as cleanup.

### NativeCommandsLinux

Pure Dart:

- `listJavaProcesses()`: Runs `ps -eo pid,comm,args --no-headers`, filters where `comm` column is exactly `java` (avoids false matches from args containing "java"). Parses PID (column 1) + full command line (column 3+). Returns `List<ProcessClient>` matching the Windows format.
- `killProcess(pid)`: Runs `kill -9 $pid` via `Process.run`.

No native code, no platform channel, no FFI. Linux exposes `/proc/{pid}/cmdline` natively — the WMI complexity that forced C++ on Windows doesn't exist on Linux.

---

## Component 2: JavaInstaller Platform Branching

**Problem:** `java_installer.dart` downloads a Windows `.zip` JRE and extracts with PowerShell `Expand-Archive`.

**Solution:** Branch on `Platform.isWindows` in 3 spots within the existing file:

1. **Download URL:** Windows `.zip` vs Linux `.tar.gz` from Adoptium
2. **Extraction command:** `powershell Expand-Archive` vs `tar -xzf`
3. **Executable path:** `java.exe` (Windows) vs `java` (Linux, no extension)

### Changes (in `lib/config/services/bot_engine/java_installer.dart`)

```dart
// Download URL
final url = Platform.isWindows
    ? 'https://api.adoptium.net/.../windows/x64/jre/hotspot/...zip'
    : 'https://api.adoptium.net/.../linux/x64/jre/hotspot/...tar.gz';

// Extraction
if (Platform.isWindows) {
  await Process.run('powershell', ['-Command', 'Expand-Archive -Path "$zipPath" -DestinationPath "$javaDir" -Force']);
} else {
  await Process.run('tar', ['-xzf', zipPath, '-C', javaDir]);
}

// Executable detection
final exeName = Platform.isWindows ? 'java.exe' : 'java';
final javaExePath = p.join(jreDirs.first.path, 'bin', exeName);
```

No new files.

---

## Component 3: Path Resolution + File Opener

### Path resolution

**Problem:** `scripts_path.dart` and `python_runner.dart` use `Platform.environment['USERPROFILE']` which doesn't exist on Linux.

**Solution:** Fall back to `HOME`:

```dart
Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? ''
```

Two files, ~2 lines changed each.

**Note:** `scripts_path.dart` also has a hardcoded workspace fallback path (`projects/command_center/scripts`) that assumes Windows directory conventions. This path is development-only (only used when the bundled scripts path doesn't exist). Guard the entire block with `Platform.isWindows` — the AppImage uses the bundled path, so this dev-only fallback is Windows-specific.

### Python executable resolution

**Problem:** The codebase calls `python` (bare) in `python_dependency_checker.dart`, `python_setup_service.dart`, and `python_runner.dart`. On most Linux distros, only `python3` is available — `python` doesn't exist unless `python-is-python3` is installed.

**Solution:** Add a helper that resolves the correct Python executable:

```dart
Future<String> resolvePythonExecutable() async {
  for (final candidate in ['python3', 'python']) {
    try {
      final result = await Process.run(candidate, ['--version']);
      if (result.exitCode == 0) return candidate;
    } catch (_) {}
  }
  throw Exception('Python not found');
}
```

Call once at startup (in `PythonSetupService.onInit`), cache the result, and use it everywhere instead of hardcoded `'python'`. On Windows, `python` is found first (it ships with the launcher). On Linux, `python3` is found first.

### File opener

**Problem:** `dev_tools_controller.dart` calls `explorer.exe` to open directories.

**Solution:** New utility + one callsite edit.

**Create:** `lib/core/helper/platform_open.dart`

```dart
import 'dart:io';

Future<void> openInFileManager(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
}
```

**Modify:** `dev_tools_controller.dart` — replace `Process.run('explorer.exe', ...)` with `openInFileManager(dir.path)`.

---

## Component 4: Dependency Injection Wiring

**Modify:** `lib/core/resource/dependency_injection.dart`

Change NativeCommandsService registration to platform-aware:

```dart
import 'dart:io' show Platform;

Get.put<NativeCommandsService>(
  Platform.isWindows ? NativeCommandsWindows() : NativeCommandsLinux(),
  permanent: true,
);
```

All consumers depend on the abstract `NativeCommandsService` type — zero changes to WatchdogService, WatchdogHandlers, MicrobotEngine, or any other consumer.

---

## Component 5: Build & CI

### Flutter Linux scaffold

Run `flutter create --platforms=linux .` to generate the `linux/` directory with GTK runner boilerplate. No custom native code on the Linux side — process management is pure Dart.

`sqlite3_flutter_libs` already supports Linux. `fluent_ui` and `window_manager` already support Linux.

### GitHub Actions — Linux build matrix

**Modify:** `.github/workflows/release.yml`

Add a Linux matrix entry alongside the existing Windows build:

```yaml
strategy:
  matrix:
    include:
      - os: windows-latest
        artifact: windows
      - os: ubuntu-latest
        artifact: linux
```

Linux steps:
1. Install Flutter + Linux dependencies (`sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev`)
2. `flutter build linux --release`
3. Package as AppImage using `appimagetool`
4. Upload `.AppImage` to GitHub Release alongside Windows `.zip`

### Release job update

The existing `release` job must be updated to handle dual artifacts:
- `needs:` depends on the matrix `build` job (waits for both Windows and Linux)
- `download-artifact` called twice: `windows-build` and `linux-build`
- `softprops/action-gh-release` `files:` list includes both the Windows `.zip` and Linux `.AppImage`

### AppImage packaging

Bundle the Flutter build output (`build/linux/x64/release/bundle/`) into an AppImage:
- `command_center.desktop` file (app name, icon, categories)
- App icon (reuse existing `runescape_icon.png`)
- `AppRun` script (standard AppImage entry point)
- Package with `appimagetool`

---

## Accepted Visual Differences on Linux

- **System accent color:** `system_theme` reads the Windows registry accent color. On Linux it returns a fallback (blue). `FluentAppTheme` already has a try/catch that falls back to `Colors.blue` — no crash, just always-blue accent. Accepted.
- **Typography:** `FluentAppTheme` hardcodes `'Segoe UI Variable Display/Text/Small'` — Windows 11 system fonts. On Linux, Flutter falls back to platform default (Noto Sans/Roboto). Text will render slightly different. Accepted — bundling Segoe UI would be a licensing issue.

## What Does NOT Change

- **UI framework:** Fluent UI renders on both platforms (Windows 11 look on Linux)
- **Database:** Drift + SQLite works cross-platform via `sqlite3_flutter_libs`
- **Python scripts:** Patchright is cross-platform. `scripts/` directory unchanged.
- **Bot engine logic:** MicrobotEngine, WatchdogService, WatchdogHandlers — all unchanged (they depend on the abstract NativeCommandsService interface)
- **All other services:** AppConfigService, WebshareService, IpqsService, etc. — unchanged

## Scope Summary

| Change | Files | Effort |
|--------|-------|--------|
| NativeCommands abstraction | 3 (1 abstract, 2 impls) | ~80 lines |
| JavaInstaller branching | 1 edit | ~15 lines |
| Path resolution | 2 edits | ~4 lines |
| Python executable resolver | 1 new + 3 edits | ~25 lines |
| Platform file opener | 1 new + 1 edit | ~15 lines |
| DI wiring | 1 edit | ~3 lines |
| Linux scaffold | generated | `flutter create` |
| CI + AppImage | 1 edit + 2 new | ~50 lines |
| **Total** | **~14 files** | **~195 lines hand-written** |
