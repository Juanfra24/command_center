# Linux Compatibility — Design Spec

**Goal:** Make Command Center build and run on Linux alongside Windows, with identical UI (Fluent UI) and functionality.

**Approach:** Platform abstraction layer for the 4 Windows-specific code points. No UI changes — Fluent UI and window_manager already support Linux. Pure Dart for Linux process management (no native C++ needed — `/proc` and `ps` expose full command lines natively).

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

### NativeCommandsLinux

Pure Dart:

- `listJavaProcesses()`: Runs `ps aux`, filters lines containing `java`, parses PID + full command line. Returns `List<ProcessClient>` matching the Windows format.
- `killProcess(pid)`: Runs `kill -9 $pid` via `Process.run`.

No native code, no platform channel, no FFI. Linux exposes `/proc/{pid}/cmdline` and `ps` includes full command lines natively — the WMI complexity that forced C++ on Windows doesn't exist on Linux.

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

### AppImage packaging

Bundle the Flutter build output (`build/linux/x64/release/bundle/`) into an AppImage:
- `command_center.desktop` file (app name, icon, categories)
- App icon (reuse existing `runescape_icon.png`)
- `AppRun` script (standard AppImage entry point)
- Package with `appimagetool`

---

## What Does NOT Change

- **UI:** Fluent UI renders on both platforms (Windows 11 look on Linux — accepted)
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
| Platform file opener | 1 new + 1 edit | ~15 lines |
| DI wiring | 1 edit | ~3 lines |
| Linux scaffold | generated | `flutter create` |
| CI + AppImage | 1 edit + 2 new | ~40 lines |
| **Total** | **~10 files** | **~155 lines hand-written** |
