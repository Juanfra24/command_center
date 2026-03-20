# Setup Flow Overhaul — Design Spec

**Goal:** Fix the broken release build (missing scripts), add clear step-by-step setup progress, and provide user-friendly error messages with platform-specific fix hints.

**Problems solved:**
1. `scripts/` directory never bundled in release builds — Python setup fails with "requirements.txt not found"
2. DI Phase 2 (DB, Config, services) shows zero progress — user sees a blank splash
3. Setup progress is one vague progress bar — no indication of what's happening or how many steps remain
4. Error messages are technical paths — not actionable for users

**Approach:** Bundle scripts via Flutter assets with first-launch extraction. Replace the monolithic `MicrobotSetupService.ensureDependencies()` with a `SetupOrchestrator` that runs 4 discrete, observable steps with reactive state. All steps are mandatory — app cannot proceed until all complete.

---

## Component 1: Scripts Bundling + Extraction

### Problem

The `scripts/` directory (containing `requirements.txt`, `account_automation.py`, and the `automation/` package) is never included in release builds:
- Not in `pubspec.yaml` assets
- Not in CMake install rules
- Not in AppImage packaging

At runtime, `scriptsPath` resolves to `<execDir>/data/scripts/` which doesn't exist.

### Solution

**Bundle:** Add runtime scripts to `pubspec.yaml` assets. Flutter requires each directory level listed explicitly (no recursive includes):

```yaml
assets:
  - scripts/
  - scripts/automation/
  - scripts/automation/commands/
```

Only runtime files are bundled. Dev-only files (`scripts/hooks/`, `scripts/release/`, `scripts/openChrome.py`, `scripts/test_captcha.py`) are excluded by not listing their directories. `__pycache__/` directories must be cleaned before release builds (add to `.gitignore` if not already).

Flutter copies bundled assets to `data/flutter_assets/` at build time.

**Extract:** New `ScriptsExtractor` service extracts bundled scripts from Flutter assets to the app data directory on first launch:
- Windows: `%APPDATA%/CommandCenter/scripts/`
- Linux: `~/.local/share/command_center/scripts/`

The extractor only copies `.py` and `.txt` files (skips any stray `.pyc` or metadata files). Directory structure is recreated from the asset manifest.

**Version check:** Write a `.scripts_version` marker file after extraction containing the app version (baked-in constant in `lib/core/constants/app_version.dart`, kept in sync with `pubspec.yaml`). On subsequent launches, compare the marker against the constant. Re-extract only when versions differ.

**Path resolution change:** `scripts_path.dart` gains a `setScriptsPath(String path)` function that overrides the cached value. `ScriptsExtractor` calls this after extraction so all subsequent consumers get the correct path. Resolution order becomes:
1. Override path (set by `ScriptsExtractor` after extraction)
2. Dev path (`../../scripts` relative to executable) — development fallback
3. Bundled fallback (`<execDir>/data/scripts`) — last resort

**PythonRunner.scriptsPath deduplication:** `PythonRunner` currently has its own hardcoded copy of the path resolution logic (lines 24-50). This must be changed to delegate to `scripts_path.dart` instead of re-implementing the resolution. This ensures all consumers use the same extracted path.

### Files

- **Modify:** `pubspec.yaml` — add scripts asset directories
- **Create:** `lib/config/services/setup/scripts_extractor.dart`
- **Create:** `lib/core/constants/app_version.dart` — baked-in version constant
- **Modify:** `lib/core/helper/scripts_path.dart` — add `setScriptsPath()`, new resolution order
- **Modify:** `lib/config/services/automation/python_runner.dart` — delegate `scriptsPath` to `scripts_path.dart`

---

## Component 2: Setup Steps Architecture

### Current State

`MicrobotSetupService.ensureDependencies()` runs 3 steps sequentially with `progressPercent` and `currentStep` observables. `PythonSetupService` has its own `SetupStep` enum and progress fields that are **non-reactive** (not `.obs`). The splash screen can only observe `MicrobotSetupService` state.

### New Architecture

**`SetupOrchestrator`** — a GetxService that owns the full setup flow. Holds `RxList<SetupStepState>` with 4 entries, one per step. Each step is observable individually.

**`SetupStepState`** — immutable model for one step's current state:

```dart
enum StepStatus { pending, running, completed, failed }

class SetupStepState {
  final String label;         // "Python Setup"
  final String detail;        // "Installing Chromium browser driver..."
  final StepStatus status;    // pending, running, completed, failed
  final double progress;      // 0.0-1.0 within this step
  final String? errorMessage; // user-friendly error
  final String? fixHint;      // "Install Python 3.8+: sudo apt install python3 python3-pip"
}
```

### 4 Mandatory Steps

| # | Label | Service | Substeps | Duration |
|---|-------|---------|----------|----------|
| 1 | Extract Scripts | `ScriptsExtractor` | Check version marker → extract from assets → write marker | <1s |
| 2 | Python Setup | `PythonSetupService` | Check python3 → check pip → install deps from requirements.txt → install Chromium → verify headless launch | 30s-2m |
| 3 | Java Setup | `JavaInstaller` | Check saved path → check system java → download Adoptium JRE 17 → extract (PowerShell/tar) → verify | 1s or 1-3m |
| 4 | Microbot Setup | `MicrobotJarDownloader` | Check GitHub PAT → check cached JAR version → download latest → verify file | 1s or 30s-2m |

### Flow

`SetupOrchestrator.run()` is a **blocking async call** — it only returns when all 4 steps complete successfully. The caller (`app_lifecycle.dart`) simply `await`s it; no polling loop needed.

```
Future<void> run() async {
  for each step in [extractScripts, pythonSetup, javaSetup, microbotSetup]:
    update step → status: running
    try:
      await step.execute(onProgress: (detail, percent) => update step)
      update step → status: completed
    catch:
      update step → status: failed, errorMessage, fixHint
      STOP — await _retryCompleter.future  // blocks until user presses Retry
      reset step → status: pending
      re-run this step (loop back, not the whole sequence)
}
```

The `_retryCompleter` is a `Completer<void>` that `retryCurrentStep()` completes. This means `run()` stays blocked on the failed step until the user retries, then continues from where it left off.

**Retry safety:** Before re-running a step, the orchestrator ensures the previous attempt's resources are cleaned up. For `PythonSetupService`, this means checking `isChecking` is false before calling `installDependencies()` again. If it's still true (e.g. a pip process is being killed), the orchestrator waits briefly before retrying.

All steps are mandatory. The app main UI never loads until `run()` returns (all 4 steps completed).

**Behavioral change from current:** The current splash screen has a "Skip" button. This is **removed**. The app requires all dependencies to function. Users who previously skipped setup will now need to complete it.

### Integration

- `app_lifecycle.dart` calls `SetupOrchestrator.run()` instead of `MicrobotSetupService.ensureDependencies()`
- `dependency_injection.dart` registers `SetupOrchestrator`
- `MicrobotSetupService` simplified — no longer owns the full flow, just wraps Java + JAR setup
- Existing services (`PythonSetupService`, `JavaInstaller`, `MicrobotJarDownloader`) keep their logic. The orchestrator calls them and translates their state/errors into `SetupStepState`.

### Files

- **Create:** `lib/config/services/setup/setup_orchestrator.dart`
- **Create:** `lib/config/services/setup/setup_step_state.dart`
- **Modify:** `lib/feature/app/views/components/app_lifecycle.dart` — use SetupOrchestrator
- **Modify:** `lib/core/resource/dependency_injection.dart` — register SetupOrchestrator
- **Modify:** `lib/config/services/bot_engine/microbot_setup_service.dart` — simplify

---

## Component 3: Splash Screen UI

### Layout

Vertical step list showing all 4 steps simultaneously:

```
┌──────────────────────────────────────────┐
│         RuneScape Bot Command Center     │
│              [app icon]                  │
│                                          │
│  ✓  Extract Scripts          Complete    │
│  ◉  Python Setup             Running     │
│     Installing Chromium...   ████░░ 60%  │
│  ○  Java Setup               Pending     │
│  ○  Microbot Setup           Pending     │
│                                          │
│          Step 2 of 4                     │
└──────────────────────────────────────────┘
```

### Failure State

```
┌──────────────────────────────────────────┐
│  ✓  Extract Scripts          Complete    │
│  ✗  Python Setup             Failed      │
│     Python 3 not found.                  │
│     Install: sudo apt install python3    │
│                                          │
│              [ Retry ]                   │
│  ○  Java Setup               Pending     │
│  ○  Microbot Setup           Pending     │
└──────────────────────────────────────────┘
```

### Implementation

- Uses Fluent UI: `InfoBar` for errors, `ProgressBar` for step progress, icons for status
- Each step row is a **`SetupStepTile`** stateless widget
- `Obx()` wraps each tile — only the active step rebuilds on state changes
- "Retry" button calls `SetupOrchestrator.retryCurrentStep()`
- "Step X of 4" summary below the list

### Files

- **Modify:** `lib/feature/app/views/splash_screen.dart` — rewrite to observe SetupOrchestrator
- **Create:** `lib/feature/app/views/components/setup_step_tile.dart` — single step row widget

---

## Component 4: Platform-Specific Error Messages

All user-facing setup messages centralized in one file. Each failure has:
- `errorMessage`: what went wrong (human-readable)
- `fixHint`: how to fix it (platform-specific)

### Message Table

| Failure | Error Message | Windows Fix Hint | Linux Fix Hint |
|---------|--------------|------------------|----------------|
| Python not found | "Python 3.8+ is required" | "Download from python.org and check 'Add to PATH'" | "Run: sudo apt install python3 python3-pip" |
| pip not found | "pip is required for dependency installation" | "Reinstall Python with pip enabled" | "Run: sudo apt install python3-pip" |
| Scripts extraction failed | "Failed to extract application scripts" | "Reinstall the application" | "Reinstall the AppImage" |
| pip install fails | "Failed to install Python dependencies" | "Check your internet connection and retry" | "Check your internet connection and retry" |
| Chromium install fails | "Browser driver installation failed" | "Check your internet connection and retry" | "Check your internet connection and retry" |
| Java download fails | "Failed to download Java 17" | "Check your internet connection and retry" | "Check your internet connection and retry" |
| Java extraction fails | "Failed to extract Java runtime" | "Check available disk space and retry" | "Check available disk space and retry" |
| GitHub PAT missing | "GitHub access token not configured" | "Configure in Settings after setup completes" | "Configure in Settings after setup completes" |
| JAR download fails | "Failed to download Microbot engine" | "Check internet connection and GitHub PAT" | "Check internet connection and GitHub PAT" |

### Files

- **Create:** `lib/config/services/setup/setup_messages.dart`

---

## File Structure Summary

```
lib/config/services/setup/          # NEW directory
├── setup_orchestrator.dart          # Runs 4 steps, holds RxList<SetupStepState>
├── setup_step_state.dart            # SetupStepState model + StepStatus enum
├── setup_messages.dart              # Platform-specific error messages + fix hints
└── scripts_extractor.dart           # Extract bundled scripts to app data dir

lib/feature/app/views/
├── splash_screen.dart               # REWRITTEN: observes SetupOrchestrator, renders step list
└── components/
    └── setup_step_tile.dart         # NEW: single step row widget

New files:
├── lib/core/constants/app_version.dart  # Baked-in version constant

Existing files modified:
├── pubspec.yaml                     # Add scripts asset directories
├── lib/core/helper/scripts_path.dart                    # Add setScriptsPath(), new resolution
├── lib/config/services/automation/python_runner.dart     # Delegate scriptsPath to scripts_path.dart
├── lib/feature/app/views/components/app_lifecycle.dart   # Use SetupOrchestrator
├── lib/core/resource/dependency_injection.dart           # Register SetupOrchestrator
└── lib/config/services/bot_engine/microbot_setup_service.dart  # Simplified
```

## What Does NOT Change

- **PythonSetupService** — keeps all its logic (check python, install deps, install chromium, verify). Orchestrator calls it and translates state.
- **JavaInstaller** — keeps all its logic (find path, download, extract, verify). Orchestrator calls it.
- **MicrobotJarDownloader** — keeps all its logic (check cache, download, atomic rename). Orchestrator calls it.
- **PythonDependencyChecker** — unchanged.
- **PythonResolver** — unchanged.
- **All other services and features** — unchanged.

## Accepted Limitations

- Flutter assets don't preserve file permissions (execute bit). After extraction, `scripts/*.py` may need no special permissions since they're run via `python3 script.py` (not executed directly). If any script needs execute permission, `ScriptsExtractor` will set it post-extraction.
- First-launch extraction adds <1s to startup. Subsequent launches skip extraction (version marker check).
