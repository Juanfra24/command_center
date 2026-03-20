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

**Bundle:** Add `scripts/` contents to `pubspec.yaml` assets. Flutter copies them to `data/flutter_assets/` at build time.

**Extract:** New `ScriptsExtractor` service extracts bundled scripts from Flutter assets to the app data directory on first launch:
- Windows: `%APPDATA%/CommandCenter/scripts/`
- Linux: `~/.local/share/command_center/scripts/`

**Version check:** Write a `.scripts_version` marker file after extraction. On subsequent launches, compare the marker against the app version (from `package_info_plus` or baked-in constant). Re-extract only when the app version changes — ensures updated scripts ship with app updates.

**Path resolution change:** `scripts_path.dart` resolution order becomes:
1. App data dir (extracted scripts) — primary for both dev and release
2. Dev path (`../../scripts` relative to executable) — development fallback
3. Bundled fallback (`<execDir>/data/scripts`) — last resort

### Files

- **Modify:** `pubspec.yaml` — add scripts to assets
- **Create:** `lib/config/services/setup/scripts_extractor.dart`
- **Modify:** `lib/core/helper/scripts_path.dart` — new resolution order

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

```
SetupOrchestrator.run()
  for each step in [extractScripts, pythonSetup, javaSetup, microbotSetup]:
    update step → status: running
    try:
      await step.execute(onProgress: (detail, percent) => update step)
      update step → status: completed
    catch:
      update step → status: failed, errorMessage, fixHint
      STOP — wait for user to press Retry
      on retry: re-run this step (not the whole sequence)
```

All steps are mandatory. If any step fails, the orchestrator stops. The user sees the error, the fix hint, and a Retry button. The app main UI never loads until all 4 steps are completed.

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

Existing files modified:
├── pubspec.yaml                     # Add scripts/ to assets
├── lib/core/helper/scripts_path.dart                    # New resolution order
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
