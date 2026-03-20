# Linux Compatibility — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Command Center build and run on Linux alongside Windows — same codebase, both platforms always built.

**Architecture:** Platform abstraction for 4 Windows-specific areas (process management, Java install, paths, file opener) + Python executable resolver + Linux CI build with AppImage packaging. No UI changes.

**Tech Stack:** Flutter/Dart, Fluent UI, GetX, flutter_test, GitHub Actions, appimagetool

**Spec:** `docs/superpowers/specs/2026-03-19-linux-compatibility-design.md`

---

### Task 1: NativeCommandsService — Abstract Interface

Extract the current `NativeCommandsService` into an abstract interface. This is the foundation — all other tasks depend on the abstract type existing.

**Files:**
- Modify: `lib/config/services/native_commands_service.dart`
- Modify: `lib/feature/Status/data/process_model.dart`

- [ ] **Step 1: Convert NativeCommandsService to abstract class**

Replace `lib/config/services/native_commands_service.dart` entirely with:

```dart
import 'package:command_center/feature/Status/data/process_model.dart';

/// Platform-agnostic interface for OS process operations.
/// Windows uses WMI COM API via method channel.
/// Linux uses ps/kill via pure Dart.
abstract class NativeCommandsService {
  /// List running Java processes with their PIDs and full command lines.
  Future<List<ProcessClient>> listJavaProcesses();

  /// Kill a process (and its children on Windows) by PID.
  Future<void> killProcess(int pid);
}
```

- [ ] **Step 2: Run analyzer to confirm the interface compiles**

Run: `cd /mnt/c/Projects/command_center && dart analyze lib/config/services/native_commands_service.dart`
Expected: No issues (the abstract class is valid, consumers reference the type not the constructor)

Note: The app will NOT compile fully yet — `dependency_injection.dart` calls `NativeCommandsService()` constructor which no longer exists. That's fixed in Task 4.

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/native_commands_service.dart
git commit -m "refactor(native): convert NativeCommandsService to abstract interface"
```

---

### Task 2: NativeCommandsWindows — Extract Existing Logic

Move the current Windows method channel implementation into its own file.

**Files:**
- Create: `lib/config/services/native_commands_windows.dart`

- [ ] **Step 1: Create the Windows implementation**

Create `lib/config/services/native_commands_windows.dart`:

```dart
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:flutter/services.dart';

/// Windows implementation using WMI COM API via platform channel.
class NativeCommandsWindows implements NativeCommandsService {
  static const _platform = MethodChannel('com.onemanco/commands');

  @override
  Future<List<ProcessClient>> listJavaProcesses() async {
    try {
      final List<dynamic> result =
          await _platform.invokeMethod('listJavaProcesses');
      return ProcessClient.fromPlatformList(result);
    } on PlatformException catch (e) {
      logger.e('Failed to get Java processes: ${e.message}');
      return [];
    }
  }

  @override
  Future<void> killProcess(int pid) async {
    try {
      await _platform.invokeMethod('killProcessAndChilds', {'pid': pid});
    } on PlatformException catch (e) {
      logger.e('Failed to kill process $pid: ${e.message}');
    }
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `cd /mnt/c/Projects/command_center && dart analyze lib/config/services/native_commands_windows.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/native_commands_windows.dart
git commit -m "refactor(native): extract NativeCommandsWindows from method channel logic"
```

---

### Task 3: NativeCommandsLinux — Pure Dart Implementation

Create the Linux implementation using `ps` and `kill`.

**Files:**
- Create: `lib/config/services/native_commands_linux.dart`
- Create: `test/config/services/native_commands_linux_test.dart`

- [ ] **Step 1: Write failing tests for parsePsOutput**

Create `test/config/services/native_commands_linux_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/native_commands_linux.dart';

void main() {
  group('NativeCommandsLinux', () {
    group('parsePsOutput', () {
      test('parses java process from ps output', () {
        const output = '  1234 java            java -jar /app/bot.jar --cc-profile-dir=/profiles/bot-42\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 1);
        expect(result.first.processId, 1234);
        expect(result.first.commandLine, contains('--cc-profile-dir'));
        expect(result.first.commandLine, contains('bot-42'));
      });

      test('filters non-java processes', () {
        const output = '  5678 python          python script.py\n'
            '  1234 java            java -jar bot.jar\n'
            '  9999 node            node server.js\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 1);
        expect(result.first.processId, 1234);
      });

      test('handles empty output', () {
        final result = NativeCommandsLinux.parsePsOutput('');
        expect(result, isEmpty);
      });

      test('handles multiple java processes', () {
        const output = '  1001 java            java -jar bot.jar --cc-profile-dir=/p/bot-1\n'
            '  1002 java            java -jar bot.jar --cc-profile-dir=/p/bot-2\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 2);
        expect(result[0].processId, 1001);
        expect(result[1].processId, 1002);
      });

      test('handles whitespace variations in ps output', () {
        const output = '1234 java java -jar test.jar\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 1);
        expect(result.first.processId, 1234);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they FAIL**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/native_commands_linux_test.dart -v`
Expected: FAIL — class/method doesn't exist

- [ ] **Step 3: Create NativeCommandsLinux**

Create `lib/config/services/native_commands_linux.dart`:

```dart
import 'dart:io';

import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/Status/data/process_model.dart';

/// Linux implementation using ps and kill (pure Dart, no native code).
class NativeCommandsLinux implements NativeCommandsService {
  @override
  Future<List<ProcessClient>> listJavaProcesses() async {
    try {
      final result = await Process.run(
        'ps',
        ['-eo', 'pid,comm,args', '--no-headers'],
      );
      if (result.exitCode != 0) {
        logger.e('ps command failed: ${result.stderr}');
        return [];
      }
      return parsePsOutput(result.stdout as String);
    } catch (e) {
      logger.e('Failed to list Java processes: $e');
      return [];
    }
  }

  /// Parse ps output into ProcessClient list.
  /// Format: `  PID COMM            ARGS...`
  /// Filters where COMM is exactly "java".
  static List<ProcessClient> parsePsOutput(String output) {
    final processes = <ProcessClient>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Split into at most 3 parts: PID, COMM, ARGS
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;

      final pid = int.tryParse(parts[0]);
      final comm = parts[1];
      final args = parts.sublist(2).join(' ');

      if (pid != null && comm == 'java') {
        processes.add(ProcessClient(
          processId: pid,
          commandLine: args,
        ));
      }
    }
    return processes;
  }

  @override
  Future<void> killProcess(int pid) async {
    try {
      final result = await Process.run('kill', ['-9', '$pid']);
      if (result.exitCode != 0) {
        logger.e('Failed to kill process $pid: ${result.stderr}');
      }
    } catch (e) {
      logger.e('Failed to kill process $pid: $e');
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they PASS**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/native_commands_linux_test.dart -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/native_commands_linux.dart test/config/services/native_commands_linux_test.dart
git commit -m "feat(native): add NativeCommandsLinux with ps/kill implementation"
```

---

### Task 4: DI Wiring — Platform-Aware Registration

Wire the DI to pick Windows or Linux implementation based on platform.

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart:44`

- [ ] **Step 1: Update DI registration**

In `lib/core/resource/dependency_injection.dart`, add imports at the top:

```dart
import 'dart:io' show Platform;
import 'package:command_center/config/services/native_commands_linux.dart';
import 'package:command_center/config/services/native_commands_windows.dart';
```

Replace line 44:
```dart
    Get.put<NativeCommandsService>(NativeCommandsService(), permanent: true);
```
with:
```dart
    Get.put<NativeCommandsService>(
      Platform.isWindows ? NativeCommandsWindows() : NativeCommandsLinux(),
      permanent: true,
    );
```

- [ ] **Step 2: Run full test suite**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All tests pass (tests run on the current platform, which uses the correct implementation)

- [ ] **Step 3: Commit**

```bash
git add lib/core/resource/dependency_injection.dart
git commit -m "feat(di): platform-aware NativeCommandsService registration"
```

---

### Task 5: JavaInstaller — Platform Branching

Add Linux support for Java download, extraction, and executable detection.

**Files:**
- Modify: `lib/config/services/bot_engine/java_installer.dart`
- Test: `test/config/services/bot_engine/java_installer_test.dart`

- [ ] **Step 1: Add Linux download URL constant**

In `lib/config/services/bot_engine/java_installer.dart`, replace the single `adoptiumDownloadUrl` constant (line 16-17) with platform-aware URLs:

```dart
  static String get adoptiumDownloadUrl => Platform.isWindows
      ? 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jre/hotspot/normal/eclipse'
      : 'https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jre/hotspot/normal/eclipse';
```

Add `import 'dart:io' show Platform;` at the top if not already present (it is — `dart:io` is already imported for `File`, `Directory`, `Process`, `HttpClient`).

- [ ] **Step 2: Platform-aware archive filename**

In the `install()` method, change line 37:
```dart
    final zipPath = p.join(javaDir, 'temurin-jre-17.zip');
```
to:
```dart
    final archiveExt = Platform.isWindows ? 'zip' : 'tar.gz';
    final zipPath = p.join(javaDir, 'temurin-jre-17.$archiveExt');
```

- [ ] **Step 3: Platform-aware extraction**

Replace lines 71-75 (the PowerShell extraction block):
```dart
    // Extract zip using PowerShell (Windows)
    final extractResult = await Process.run('powershell', [
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "$javaDir" -Force',
    ]);
```
with:
```dart
    // Extract archive (platform-specific)
    final ProcessResult extractResult;
    if (Platform.isWindows) {
      extractResult = await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Path "$zipPath" -DestinationPath "$javaDir" -Force',
      ]);
    } else {
      extractResult = await Process.run('tar', [
        '-xzf', zipPath, '-C', javaDir,
      ]);
    }
```

- [ ] **Step 4: Platform-aware executable name**

Replace line 96:
```dart
    final javaExePath = p.join(jreDirs.first.path, 'bin', 'java.exe');
```
with:
```dart
    final javaExeName = Platform.isWindows ? 'java.exe' : 'java';
    final javaExePath = p.join(jreDirs.first.path, 'bin', javaExeName);
```

Also update the error message on line 98 to use `javaExeName` instead of hardcoded `java.exe`:
```dart
    if (!await File(javaExePath).exists()) {
      throw Exception('Java JRE extraction incomplete: $javaExeName not found at $javaExePath');
    }
```

- [ ] **Step 5: Update existing test for cross-platform URL**

In `test/config/services/bot_engine/java_installer_test.dart`, replace line 26:
```dart
      expect(url, contains('windows'));
```
with:
```dart
      expect(url, anyOf(contains('windows'), contains('linux')));
```

This test runs on `ubuntu-latest` in CI where the getter returns the Linux URL.

- [ ] **Step 6: Run tests**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/java_installer_test.dart -v`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add lib/config/services/bot_engine/java_installer.dart test/config/services/bot_engine/java_installer_test.dart
git commit -m "feat(java): platform-aware download URL, extraction, and executable detection"
```

---

### Task 6: Python Executable Resolver

Add a helper to find `python3` or `python` depending on what's available, and wire it into all callers.

**Files:**
- Create: `lib/core/helper/python_resolver.dart`
- Modify: `lib/config/services/python_dependency_checker.dart`
- Modify: `lib/config/services/python_setup_service.dart`
- Modify: `lib/config/services/automation/python_runner.dart`

- [ ] **Step 1: Create python_resolver.dart**

Create `lib/core/helper/python_resolver.dart`:

```dart
import 'dart:io';

import 'package:command_center/core/helper/logger.dart';

/// Resolves the correct Python executable name for the current platform.
/// On Linux, `python3` is tried first (most distros don't have bare `python`).
/// On Windows, `python` is tried first (ships with the Python launcher).
/// Result is cached after first successful resolution.
class PythonResolver {
  static String? _cached;

  /// Get the cached Python executable, or resolve it.
  static Future<String> get executable async {
    return _cached ??= await resolve();
  }

  /// Resolve which Python command is available.
  /// Tries platform-preferred order, returns the first that succeeds.
  static Future<String> resolve() async {
    // Try platform-preferred order
    final candidates = Platform.isWindows
        ? ['python', 'python3']
        : ['python3', 'python'];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, ['--version']);
        if (result.exitCode == 0) {
          logger.i('Python resolved to: $candidate (${(result.stdout as String).trim()})');
          return candidate;
        }
      } catch (_) {
        // Not available, try next
      }
    }
    throw Exception('Python not found. Install Python 3.8+ and ensure it is in PATH.');
  }

  /// Reset the cache (for testing).
  static void resetCache() => _cached = null;
}
```

- [ ] **Step 2: Update PythonDependencyChecker — replace all 'python' with resolver**

In `lib/config/services/python_dependency_checker.dart`:

Add import:
```dart
import 'package:command_center/core/helper/python_resolver.dart';
```

Replace line 15 (`Process.run('python', ['--version'])`) with:
```dart
      final python = await PythonResolver.executable;
      final result = await Process.run(python, ['--version']);
```

Replace line 30 (`Process.run('python', ['-m', 'pip', '--version'])`) with:
```dart
      final python = await PythonResolver.executable;
      final result = await Process.run(python, ['-m', 'pip', '--version']);
```

Replace line 44 (`Process.run('python', ...)`) with:
```dart
      final python = await PythonResolver.executable;
      final result = await Process.run(
        python,
        ['-c', 'import patchright; print("OK")'],
      );
```

Replace line 64 (`Process.run('python', ...)`) with:
```dart
      final python = await PythonResolver.executable;
      final result = await Process.run(
        python,
```
(keep the rest of the args the same)

- [ ] **Step 3: Update PythonSetupService — replace 'python' with resolver**

In `lib/config/services/python_setup_service.dart`:

Add import:
```dart
import 'package:command_center/core/helper/python_resolver.dart';
```

Replace line 101 (`Process.start('python', ...)`) with:
```dart
      final python = await PythonResolver.executable;
      final process = await Process.start(
        python,
```
(keep the rest of the args the same)

Replace line 180 (`Process.run('python', ...)`) with:
```dart
      final python = await PythonResolver.executable;
      final result = await Process.run(
        python,
```
(keep the rest of the args the same)

- [ ] **Step 4: Update PythonRunner — replace 'python' with resolver**

In `lib/config/services/automation/python_runner.dart`:

Add import:
```dart
import 'package:command_center/core/helper/python_resolver.dart';
```

Replace line 112 (`Process.start('python', ...)`) with:
```dart
    final python = await PythonResolver.executable;
    _currentProcess = await Process.start(python, ['-u', ...args],
```

Replace line 182 (`Process.start('python', ...)`) with:
```dart
    final python = await PythonResolver.executable;
    _currentProcess = await Process.start(python, ['-u', ...args],
```

- [ ] **Step 5: Run full test suite**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add lib/core/helper/python_resolver.dart lib/config/services/python_dependency_checker.dart lib/config/services/python_setup_service.dart lib/config/services/automation/python_runner.dart
git commit -m "feat(python): add PythonResolver for cross-platform python/python3 detection"
```

---

### Task 7: Path Resolution + Platform File Opener

Fix USERPROFILE → HOME fallback and replace `explorer.exe` with cross-platform opener.

**Files:**
- Create: `lib/core/helper/platform_open.dart`
- Modify: `lib/core/helper/scripts_path.dart:21-29`
- Modify: `lib/config/services/automation/python_runner.dart:36`
- Modify: `lib/feature/dev_tools/controller/dev_tools_controller.dart:120`

- [ ] **Step 1: Create platform_open.dart**

Create `lib/core/helper/platform_open.dart`:

```dart
import 'dart:io';

/// Opens a file or directory in the platform's default file manager.
Future<void> openInFileManager(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
}
```

- [ ] **Step 2: Fix scripts_path.dart — guard workspace fallback with Platform.isWindows**

In `lib/core/helper/scripts_path.dart`, replace lines 20-30:

```dart
  // Try relative to workspace
  final userProfile = Platform.environment['USERPROFILE'] ?? '';
  if (userProfile.isNotEmpty) {
    final workspacePath = path.join(
      userProfile,
      'projects',
      'command_center',
      'scripts',
    );
    if (Directory(workspacePath).existsSync()) return workspacePath;
  }
```

with:

```dart
  // Windows dev workspace fallback (USERPROFILE-based path structure)
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isNotEmpty) {
      final workspacePath = path.join(
        userProfile,
        'projects',
        'command_center',
        'scripts',
      );
      if (Directory(workspacePath).existsSync()) return workspacePath;
    }
  }
```

- [ ] **Step 3: Fix python_runner.dart — USERPROFILE → HOME fallback**

In `lib/config/services/automation/python_runner.dart`, replace line 36:
```dart
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
```
with:
```dart
      final userProfile = Platform.environment['USERPROFILE']
          ?? Platform.environment['HOME']
          ?? '';
```

- [ ] **Step 4: Fix dev_tools_controller.dart — use platform_open**

In `lib/feature/dev_tools/controller/dev_tools_controller.dart`, add import:
```dart
import 'package:command_center/core/helper/platform_open.dart';
```

Replace line 120:
```dart
      await Process.run('explorer.exe', [dir.path]);
```
with:
```dart
      await openInFileManager(dir.path);
```

Remove the `dart:io` import if `Process` is no longer used directly in this file (check first — it may be used elsewhere in the file).

- [ ] **Step 5: Run full test suite**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add lib/core/helper/platform_open.dart lib/core/helper/scripts_path.dart lib/config/services/automation/python_runner.dart lib/feature/dev_tools/controller/dev_tools_controller.dart
git commit -m "feat(platform): cross-platform paths, file opener, USERPROFILE/HOME fallback"
```

---

### Task 8: Flutter Linux Scaffold

Generate the `linux/` directory for GTK desktop support.

**Files:**
- Create: `linux/` directory (generated by Flutter)

- [ ] **Step 1: Generate Linux platform support**

Run: `cd /mnt/c/Projects/command_center && flutter create --platforms=linux .`

This generates `linux/` with GTK runner boilerplate. No custom native code needed.

- [ ] **Step 2: Verify the directory was created**

Run: `ls linux/`
Expected: `CMakeLists.txt`, `flutter/`, `runner/`, etc.

- [ ] **Step 3: Verify analyzer passes**

Run: `cd /mnt/c/Projects/command_center && dart analyze`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add linux/
git commit -m "feat(linux): add Flutter Linux desktop scaffold (GTK runner)"
```

---

### Task 9: CI — Linux Build + AppImage + Dual-Artifact Release

Add Linux build to the GitHub Actions workflow with AppImage packaging.

**Files:**
- Modify: `.github/workflows/release.yml`
- Create: `packaging/linux/command_center.desktop`
- Create: `packaging/linux/AppRun`

- [ ] **Step 1: Create AppImage desktop file**

Create `packaging/linux/command_center.desktop`:

```desktop
[Desktop Entry]
Name=Command Center
Comment=RuneScape Bot Command Center
Exec=command_center
Icon=command_center
Type=Application
Categories=Utility;
```

- [ ] **Step 2: Create AppRun script**

Create `packaging/linux/AppRun`:

```bash
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/command_center" "$@"
```

Make executable: `chmod +x packaging/linux/AppRun`

- [ ] **Step 3: Add Linux GTK deps to lint job**

The `lint` job runs on `ubuntu-latest` and executes `flutter test`. After adding the Linux scaffold, Flutter needs GTK headers to resolve platform imports. Add this step to the `lint` job, after "Checkout code" and before "Setup Flutter":

```yaml
      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

- [ ] **Step 4: Update release.yml — convert build job to matrix**

Replace the entire `build` job in `.github/workflows/release.yml` with:

```yaml
  build:
    name: Build ${{ matrix.platform }} Application
    runs-on: ${{ matrix.os }}
    needs: [lint-commits, lint]
    strategy:
      matrix:
        include:
          - os: windows-latest
            platform: Windows
            artifact: windows-build
            build-cmd: flutter build windows --release
          - os: ubuntu-latest
            platform: Linux
            artifact: linux-build
            build-cmd: flutter build linux --release
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Linux dependencies
        if: matrix.platform == 'Linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install dependencies
        run: flutter pub get

      - name: Build
        run: ${{ matrix.build-cmd }}

      - name: Package AppImage
        if: matrix.platform == 'Linux'
        run: |
          # Prepare AppImage directory
          mkdir -p AppDir/usr/lib
          cp -r build/linux/x64/release/bundle/* AppDir/
          cp packaging/linux/AppRun AppDir/
          cp packaging/linux/command_center.desktop AppDir/
          cp assets/images/runescape_icon.png AppDir/command_center.png
          chmod +x AppDir/AppRun

          # Download appimagetool
          wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
          chmod +x appimagetool-x86_64.AppImage

          # Build AppImage (--appimage-extract-and-run avoids FUSE requirement in CI)
          ./appimagetool-x86_64.AppImage AppDir --appimage-extract-and-run
          mv Command_Center-x86_64.AppImage command-center.AppImage

      - name: Upload Windows artifact
        if: matrix.platform == 'Windows'
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: build/windows/x64/runner/Release/**/*

      - name: Upload Linux artifact
        if: matrix.platform == 'Linux'
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: command-center.AppImage
```

- [ ] **Step 5: Update release job for dual artifacts**

Replace the `release` job's `needs`, download, zip, and files sections:

Change `needs: build` (line 105) — this already works since the matrix job is still named `build`.

Replace lines 146-166 (the download/zip/release steps after version bump) with:

```yaml
      - name: Download Windows build
        if: steps.version.outputs.skip == 'false'
        uses: actions/download-artifact@v4
        with:
          name: windows-build
          path: release-windows/

      - name: Download Linux build
        if: steps.version.outputs.skip == 'false'
        uses: actions/download-artifact@v4
        with:
          name: linux-build
          path: release-linux/

      - name: Zip Windows artifact
        if: steps.version.outputs.skip == 'false'
        run: |
          cd release-windows
          zip -r "../command-center-v${{ steps.version.outputs.new_version }}-windows.zip" .

      - name: Rename Linux artifact
        if: steps.version.outputs.skip == 'false'
        run: |
          mv release-linux/command-center.AppImage "command-center-v${{ steps.version.outputs.new_version }}-linux.AppImage"

      - name: Create GitHub Release
        if: steps.version.outputs.skip == 'false'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: "v${{ steps.version.outputs.new_version }}"
          name: "v${{ steps.version.outputs.new_version }}"
          body_path: /tmp/release_body.md
          files: |
            command-center-v${{ steps.version.outputs.new_version }}-windows.zip
            command-center-v${{ steps.version.outputs.new_version }}-linux.AppImage
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/release.yml packaging/linux/
git commit -m "ci: add Linux build matrix with AppImage packaging + dual-artifact release"
```

---

### Final: Full Verification

- [ ] **Step 1: Run full test suite**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All pass, no regressions

- [ ] **Step 2: Run analyzer on all changed files**

Run: `cd /mnt/c/Projects/command_center && dart analyze`
Expected: No issues

- [ ] **Step 3: Verify NativeCommandsService abstraction is clean**

Run: `cd /mnt/c/Projects/command_center && grep -r "NativeCommandsService()" lib/ | grep -v "_windows\|_linux\|dependency_injection"`
Expected: No results (no one is constructing the abstract class directly)
