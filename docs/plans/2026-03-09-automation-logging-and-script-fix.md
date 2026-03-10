# Automation Logging & Script Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the broken script result parsing that swallows real error messages, and add step-by-step logging across Python and Dart so developers can see exactly where automation fails.

**Architecture:** Three layers of fixes — (1) Dart `ResultParser` reordered to parse JSON before checking exit codes, (2) Python scripts emit flushed step-by-step logs, (3) Dart `PythonRunner` forwards stderr to the logger.

**Tech Stack:** Dart/Flutter (result_parser.dart, python_runner.dart), Python (automation scripts)

---

### Task 1: Fix ResultParser — parse JSON result before exit code

This is the critical bug. Currently `processScriptOutput()` returns a generic error on exit code != 0 and never parses the JSON result that Python writes after `=== RESULT ===`.

**Files:**
- Modify: `lib/config/services/automation/result_parser.dart`

**Step 1: Reorder processScriptOutput logic**

Open `lib/config/services/automation/result_parser.dart` and replace the `processScriptOutput` method (lines 45-85) with this version that tries JSON parsing first:

```dart
static AutomationResult processScriptOutput({
  required int exitCode,
  required String stdout,
  required String stderr,
  required void Function(String) onLog,
  String timeoutMessage = 'Operation timed out.',
}) {
  onLog('Script exit code: $exitCode');

  if (stderr.isNotEmpty) {
    onLog('Script errors: $stderr');

    // Module import errors are fatal — no JSON result will exist
    if (stderr.contains('ModuleNotFoundError') ||
        stderr.contains('No module named')) {
      return AutomationResult.error(
        'Python dependency error: $stderr\n\n'
        'Please ensure Python dependencies are installed correctly. '
        'Try running: python -m pip install -r scripts/requirements.txt',
      );
    }
  }

  // Always try to parse JSON result first — Python writes structured
  // results even on failure (exit code 1). The JSON contains the real
  // error info (captcha_required, proxy_validation_failed, etc).
  final resultJson = extractJsonResult(stdout);
  if (resultJson != null) {
    final result = AutomationResult.fromJson(resultJson);
    onLog('Result: ${result.status.name} - ${result.message}');
    return result;
  }

  // No JSON found — fall back to exit code + stderr
  if (exitCode != 0) {
    return AutomationResult.error(
      'Script failed with exit code $exitCode:\n$stderr',
    );
  }

  return AutomationResult.error(
    'Could not parse script output: $stdout',
  );
}
```

**Step 2: Verify the change compiles**

Run: `flutter analyze lib/config/services/automation/result_parser.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/config/services/automation/result_parser.dart
git commit -m "fix: parse JSON result before checking exit code in ResultParser"
```

---

### Task 2: Forward Python stderr to Dart logger

Currently `python_runner.dart` captures stderr in a StringBuffer but never forwards it to the `onLog` callback. Developers can't see Python errors in the debug console.

**Files:**
- Modify: `lib/config/services/automation/python_runner.dart`

**Step 1: Add stderr forwarding in the `run` method**

In `lib/config/services/automation/python_runner.dart`, replace the stderr listener (lines 112-114):

```dart
// OLD:
_currentProcess!.stderr.transform(utf8.decoder).listen((data) {
  stderr.write(data);
});
```

With:

```dart
_currentProcess!.stderr.transform(utf8.decoder).listen((data) {
  stderr.write(data);
  for (final line in data.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      onLog('[py:err] $trimmed');
    }
  }
});
```

**Step 2: Verify the change compiles**

Run: `flutter analyze lib/config/services/automation/python_runner.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/config/services/automation/python_runner.dart
git commit -m "fix: forward Python stderr to logger in PythonRunner"
```

---

### Task 3: Add flushing log wrapper in Python entry point

Python's default `print` doesn't flush, so log output can be buffered and arrive late (or not at all before a crash). The `-u` flag helps but `log_fn=print` inside commands doesn't guarantee flush.

**Files:**
- Modify: `scripts/account_automation.py`

**Step 1: Add flushing print wrapper and pass it to commands**

Replace the `run` function (lines 70-102) in `scripts/account_automation.py`:

```python
def _log(msg: str):
    """Flushing log function passed to all commands."""
    print(msg, flush=True)


async def run(args) -> AutomationResult:
    if args.command == "validate":
        from automation.commands.validate import validate_proxy_ip
        return await validate_proxy_ip(
            proxy_url=args.proxy_url,
            expected_ip=args.expected_ip,
            headless=getattr(args, "headless", False),
            debug=getattr(args, "debug", False),
            log_fn=_log,
        )
    elif args.command == "create-account":
        from automation.commands.create_account import create_account
        return await create_account(
            proxy_url=args.proxy_url,
            expected_ip=args.expected_ip,
            headless=getattr(args, "headless", False),
            debug=getattr(args, "debug", False),
            imap_host=getattr(args, "imap_host", None),
            imap_user=getattr(args, "imap_user", None),
            imap_pass=getattr(args, "imap_pass", None),
            log_fn=_log,
        )
    elif args.command == "session":
        from automation.commands.session import launch_session
        return await launch_session(
            proxy_url=args.proxy_url,
            expected_ip=args.expected_ip,
            keep_open=getattr(args, "keep_open", False),
            debug=getattr(args, "debug", False),
            log_fn=_log,
        )
    else:
        return AutomationResult(
            status=AutomationStatus.UNKNOWN_ERROR.value,
            message=f"Unknown command: {args.command}",
        )
```

**Step 2: Commit**

```bash
git add scripts/account_automation.py
git commit -m "fix: add flushing log wrapper in Python entry point"
```

---

### Task 4: Add step-by-step logging to validate.py

**Files:**
- Modify: `scripts/automation/commands/validate.py`

**Step 1: Replace the entire validate function with step-labeled version**

Replace `validate_proxy_ip` in `scripts/automation/commands/validate.py`:

```python
async def validate_proxy_ip(
    proxy_url: Optional[str],
    expected_ip: str,
    headless: bool = False,
    debug: bool = False,
    log_fn: Callable[[str], None] = print,
) -> AutomationResult:
    """Validate that the proxy routes traffic through the expected IP."""
    log_fn("[INFO] ===== Proxy IP Validation =====")
    log_fn(f"[INFO] Python: {sys.version.split()[0]}")
    log_fn(f"[INFO] Headless: {headless}")

    # Step 1/4: Proxy preflight
    log_fn("[STEP 1/4] Running proxy preflight checks...")
    err, cleaned_proxy = preflight_proxy(proxy_url, expected_ip, log_fn)
    if err:
        log_fn("[STEP 1/4] FAILED - proxy preflight error")
        return err
    log_fn("[STEP 1/4] OK")

    pw = browser = None
    try:
        # Step 2/4: Launch browser
        log_fn("[STEP 2/4] Launching browser...")
        pw, browser, context, page = await launch_browser(
            proxy_url=cleaned_proxy,
            headless=headless,
        )
        log_fn("[STEP 2/4] OK - browser started")

        # Step 3/4: Check IP
        log_fn("[STEP 3/4] Checking IP address...")
        actual_ip = None
        last_error = None

        for i, url in enumerate(IP_CHECK_URLS):
            try:
                log_fn(f"[STEP 3/4] IP check {i + 1}/{len(IP_CHECK_URLS)}: {url}")
                await page.goto(url, wait_until="domcontentloaded")
                human_delay(0.3, 0.8)

                body = await page.text_content("body") or ""
                actual_ip = extract_ip_from_response(body)
                if actual_ip:
                    log_fn(f"[STEP 3/4] Got IP: {actual_ip}")
                    break
            except Exception as e:
                last_error = f"{type(e).__name__}: {e}"
                log_fn(f"[STEP 3/4] IP check failed: {last_error}")

        if not actual_ip:
            log_fn("[STEP 3/4] FAILED - could not determine IP")
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message=f"Could not determine current IP. Last error: {last_error}",
                expected_ip=expected_ip,
            )
        log_fn("[STEP 3/4] OK")

        # Step 4/4: Verify IP match
        log_fn(f"[STEP 4/4] Verifying IP match: expected={expected_ip}, actual={actual_ip}")
        ip_matches = (expected_ip in actual_ip) or (actual_ip in expected_ip)
        if ip_matches:
            log_fn("[STEP 4/4] OK - IPs match")
            return AutomationResult(
                status=AutomationStatus.SUCCESS.value,
                message="Proxy IP validation successful",
                expected_ip=expected_ip,
                actual_ip=actual_ip,
            )

        log_fn("[STEP 4/4] FAILED - IP mismatch")
        return AutomationResult(
            status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
            message=f"IP mismatch: expected {expected_ip}, got {actual_ip}",
            expected_ip=expected_ip,
            actual_ip=actual_ip,
        )

    except Exception as e:
        log_fn(f"[ERROR] Browser error: {type(e).__name__}: {e}")
        return AutomationResult(
            status=AutomationStatus.BROWSER_ERROR.value,
            message=f"Browser startup failed: {type(e).__name__}: {e}",
            expected_ip=expected_ip,
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
```

**Step 2: Commit**

```bash
git add scripts/automation/commands/validate.py
git commit -m "feat: add step-by-step logging to validate command"
```

---

### Task 5: Add step-by-step logging to create_account.py

The file already has `Step N` labels but they're inconsistent and don't use the `[STEP X/N]` format. Standardize them.

**Files:**
- Modify: `scripts/automation/commands/create_account.py`

**Step 1: Update all step log messages to use consistent format**

In `scripts/automation/commands/create_account.py`, replace every `log_fn("[INFO] Step N:` line with the `[STEP N/13]` format. The changes are purely in the log message strings within the `create_account` function:

Replace these log lines (keep all surrounding code identical):

```
Line 107: log_fn("[INFO] ===== Account Creation =====")
Line 129: log_fn("[INFO] Step 1: Validating proxy IP...")
Line 138: log_fn(f"[INFO] Got IP: {actual_ip}")
Line 156: log_fn(f"[INFO] Proxy IP validated: {actual_ip}")
Line 159: log_fn("[INFO] Step 2: Navigating to account.jagex.com...")
Line 164: log_fn("[INFO] Step 3: Handling Cloudflare Turnstile...")
Line 173: log_fn("[INFO] Step 4: Handling cookie consent...")
Line 184: log_fn("[INFO] Step 5: Clicking 'Create an account'...")
Line 200: log_fn("[INFO] Step 6: Filling email...")
Line 224: log_fn("[INFO] Step 7: Filling DOB...")
Line 241: log_fn("[INFO] Step 8: Accepting terms...")
Line 250: log_fn("[INFO] Step 9: Clicking Continue...")
Line 258: log_fn("[INFO] Step 10: Email verification...")
Line 289: log_fn("[INFO] Step 11: Setting display name...")
Line 310: log_fn("[INFO] Step 12: Setting password...")
Line 345: log_fn("[INFO] Step 13: Checking for confirmation...")
Line 360: log_fn("[INFO] Account creation flow completed")
```

With these (respectively):

```
log_fn("[INFO] ===== Account Creation =====")
log_fn("[STEP 1/13] Validating proxy IP...")
log_fn(f"[STEP 1/13] Got IP: {actual_ip}")
log_fn(f"[STEP 1/13] OK - proxy IP validated: {actual_ip}")
log_fn("[STEP 2/13] Navigating to account.jagex.com...")
log_fn("[STEP 3/13] Handling Cloudflare Turnstile...")
log_fn("[STEP 4/13] Handling cookie consent...")
log_fn("[STEP 5/13] Clicking 'Create an account'...")
log_fn("[STEP 6/13] Filling email...")
log_fn("[STEP 7/13] Filling DOB...")
log_fn("[STEP 8/13] Accepting terms...")
log_fn("[STEP 9/13] Clicking Continue...")
log_fn("[STEP 10/13] Email verification...")
log_fn("[STEP 11/13] Setting display name...")
log_fn("[STEP 12/13] Setting password...")
log_fn("[STEP 13/13] Checking for confirmation...")
log_fn("[INFO] Account creation flow completed")
```

Also add failure markers at each early-return point. For example after the IP check failure (line 143-148):
```python
log_fn("[STEP 1/13] FAILED - could not determine IP")
```

After IP mismatch (line 150-155):
```python
log_fn(f"[STEP 1/13] FAILED - IP mismatch: expected {expected_ip}, got {actual_ip}")
```

After Turnstile failure (line 165-170):
```python
log_fn("[STEP 3/13] FAILED - could not pass Cloudflare Turnstile")
```

After email field not found (line 216-221):
```python
log_fn("[STEP 6/13] FAILED - could not find email field")
```

In the catch block (line 375-380):
```python
log_fn(f"[ERROR] Account creation failed at unexpected point: {type(e).__name__}: {e}")
```

**Step 2: Commit**

```bash
git add scripts/automation/commands/create_account.py
git commit -m "feat: standardize step-by-step logging in create_account command"
```

---

### Task 6: Add step-by-step logging to session.py

**Files:**
- Modify: `scripts/automation/commands/session.py`

**Step 1: Replace log messages with step format**

In `scripts/automation/commands/session.py`, update the `launch_session` function log messages:

Replace:
```
log_fn("[INFO] ===== Browser Session =====")
```
With:
```
log_fn("[INFO] ===== Browser Session =====")
log_fn("[STEP 1/4] Running proxy preflight checks...")
```

After preflight success, add:
```
log_fn("[STEP 1/4] OK")
```

Replace `log_fn("[INFO] Browser started for session")` with:
```
log_fn("[STEP 2/4] OK - browser started")
```

Replace `log_fn("[INFO] Validating proxy IP...")` with:
```
log_fn("[STEP 3/4] Checking IP address...")
```

Replace `log_fn("[INFO] Navigating to account.jagex.com...")` with:
```
log_fn("[STEP 4/4] Navigating to account.jagex.com...")
```

Add step labels before each existing section. Add failure labels at error returns.

**Step 2: Commit**

```bash
git add scripts/automation/commands/session.py
git commit -m "feat: add step-by-step logging to session command"
```

---

### Task 7: Verify end-to-end and final commit

**Step 1: Verify Dart compiles**

Run: `flutter analyze`
Expected: No errors (only pre-existing info-level warnings)

**Step 2: Verify Python scripts parse correctly**

Run: `cd scripts && python -c "from automation.commands.validate import validate_proxy_ip; print('OK')"`
Run: `cd scripts && python -c "from automation.commands.create_account import create_account; print('OK')"`
Run: `cd scripts && python -c "from automation.commands.session import launch_session; print('OK')"`
Expected: Each prints "OK"

**Step 3: Quick manual test**

Launch the app, go to proxy screen, select a slot, click "Launch Browser". Check debug console for `[STEP X/N]` messages and `[py:err]` stderr output. If the script fails, verify the real error message appears (not "Script failed with exit code 1").
