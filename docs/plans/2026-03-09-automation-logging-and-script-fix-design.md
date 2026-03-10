# Automation Logging & Script Fix Design

**Date:** 2026-03-09
**Status:** Approved

## Problem Statement

1. **Script exit code 1 swallows real errors:** `ResultParser.processScriptOutput()` checks exit code BEFORE parsing the JSON result. When Python exits with code 1 (any non-success status like captcha_required, proxy_validation_failed, browser_error), Dart returns a generic `"Script failed with exit code 1:\n$stderr"` and never reads the actual JSON result that has the detailed error info. This is why the user sees a useless error message after IP validation.

2. **No developer visibility:** Python logs go to `AutomationService.logs` observable but nothing displays them. Python stderr is captured but never forwarded to the logger. The developer cannot see what step the script is on or where it fails.

## Design

### Fix 1: ResultParser — Parse JSON first, exit code second

**File:** `lib/config/services/automation/result_parser.dart`

Current order (broken):
1. Check stderr for module errors → early return
2. Check exit code != 0 → early return with generic error
3. Parse JSON result ← never reached on failure

New order:
1. Check stderr for module errors (ImportError) → early return
2. **Always try to parse JSON result from stdout** → return if found
3. Fall back to exit code + stderr only if no JSON found

### Fix 2: PythonRunner — Forward stderr to logger

**File:** `lib/config/services/automation/python_runner.dart`

Currently stderr is captured in a StringBuffer but never forwarded to `onLog`. Add stderr forwarding with `[py:err]` prefix so it shows in the debug console.

### Fix 3: Python step-by-step logging with flush

**Files:** All Python command files

Add consistent `[STEP X/N]` logging with `flush=True` to every print call so output reaches Dart in real-time (not buffered).

#### `validate.py` (4 steps):
1. Proxy preflight checks
2. Browser launch
3. IP validation
4. IP match verification

#### `create_account.py` (13 steps — already has step labels, needs flush):
Steps 1-13 already labeled. Add `flush=True` to `log_fn` wrapper and ensure consistent format.

#### `session.py` (4 steps):
1. Proxy preflight
2. Browser launch
3. IP validation
4. Navigate to Jagex + wait

#### `account_automation.py` entry point:
Wrap the default `log_fn=print` with a flushing version so all downstream `log_fn()` calls flush automatically.

### Fix 4: User-facing InfoBar toasts

**File:** `lib/feature/proxy/views/proxy_screen.dart` (for session launch)
**File:** `lib/feature/Status/views/dialogs/create_character_dialog.dart` (for account creation)

Add InfoBar feedback at key moments using the existing `displayInfoBar` pattern:
- "Validating proxy..." → "Proxy validated" / "Proxy validation failed: [reason]"
- "Creating account..." → "Account created!" / "Failed: [reason]"

These already partially exist. The main improvement is showing the **actual error message** from the parsed JSON result instead of the generic exit code message (which is fixed by Fix 1).

## Files Changed

| File | Change |
|------|--------|
| `result_parser.dart` | Reorder: parse JSON before checking exit code |
| `python_runner.dart` | Forward stderr lines to onLog callback |
| `account_automation.py` | Flushing log wrapper |
| `commands/validate.py` | Step-by-step logging with flush |
| `commands/create_account.py` | Ensure flush on all log calls |
| `commands/session.py` | Step-by-step logging with flush |

## Out of Scope

- UI log viewer screen (not needed — debug console is sufficient)
- File-based log persistence
- Structured/JSON logging format
- New dependencies
