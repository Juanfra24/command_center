# SeleniumBase → Patchright Migration Design

**Date:** 2026-03-08
**Status:** Approved
**Goal:** Replace SeleniumBase with Patchright for browser automation, fixing broken Cloudflare bypass while keeping the standalone Dart→Python subprocess architecture.

## Problem

SeleniumBase's `uc_open_with_reconnect()` no longer bypasses Cloudflare on `account.jagex.com`. Cloudflare detects the CDP `Runtime.enable` leak that SeleniumBase cannot patch. Account creation is non-functional.

## Decision: Patchright

Patchright is a patched Playwright fork that fixes the CDP leak Cloudflare exploits. It provides:
- Binary-level stealth patches (not JavaScript injection)
- Native authenticated proxy support
- Clean async Playwright API with auto-wait
- `patchright install chromium` for self-contained browser bundling
- Active maintenance, Python package on PyPI

Alternatives considered:
- **rebrowser-playwright** — similar approach, less Python community traction
- **Camoufox** — best stealth but unstable beta, risky for production

## Architecture: What Changes, What Stays

### Unchanged (zero modifications)
- Dart `AutomationService` / `PythonRunner` / `ResultParser`
- `=== RESULT ===` JSON stdout protocol
- `AutomationResult` / `AutomationStatus` enums on both sides
- Three subcommands: `validate`, `create-account`, `session`
- Proxy format: `username:password@host:port`
- IMAP email verification flow

### Changed
- `scripts/account_automation.py` — rewrite from SeleniumBase → Patchright async API
- `scripts/requirements.txt` — `seleniumbase` → `patchright`
- `PythonSetupService` — install patchright + `patchright install chromium`
- Chromium verification uses Patchright instead of SeleniumBase

## Python Script Structure

Split the monolithic 1,100-line script into modules:

```
scripts/
├── account_automation.py          (≤150) CLI entry point — argparse, dispatch
├── automation/
│   ├── __init__.py
│   ├── browser.py                 (≤200) Browser launch + proxy + stealth config
│   ├── commands/
│   │   ├── __init__.py
│   │   ├── validate.py            (≤150) IP validation command
│   │   ├── create_account.py      (≤300) Account creation flow
│   │   └── session.py             (≤150) Manual browser session
│   ├── helpers.py                 (≤150) human_type, click_first_match, delays
│   ├── imap_poller.py             (≤150) IMAP verification code polling
│   ├── models.py                  (≤80)  AutomationResult, AutomationStatus
│   └── proxy.py                   (≤100) Proxy cleaning, validation, TCP ping
└── requirements.txt
```

## Browser Launch Configuration

All stealth decisions centralized in `browser.py`:

```python
async def launch_browser(proxy_url, headless=False):
    pw = await async_playwright().start()
    browser = await pw.chromium.launch(
        channel="chrome",          # Real Chrome for better fingerprint
        headless=headless,
        args=[
            "--disable-dev-shm-usage",
            "--disable-webrtc",
            "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
        ],
    )
    context = await browser.new_context(
        proxy={"server": f"http://{host}:{port}", "username": user, "password": pwd},
        viewport={"width": 1920, "height": 1080},
        locale="en-US",
        timezone_id="America/New_York",
    )
    page = await context.new_page()
    return pw, browser, context, page
```

Key decisions:
- `channel="chrome"` prefers real Chrome, falls back to bundled Chromium
- Headed mode by default (headless detectable even with patches)
- Proxy at context level (native auth, no Chrome extension needed)
- WebRTC disabled to prevent IP leak
- Fresh context per run (no persistent profiles needed)

## PythonSetupService Changes

| Step | Current (SeleniumBase) | New (Patchright) |
|------|----------------------|------------------|
| 1 | Check Python | Check Python |
| 2 | `pip install -r requirements.txt` | `pip install -r requirements.txt` |
| 3 | `sbase install chromedriver latest` | `patchright install chromium` |
| 4 | `import seleniumbase` | `import patchright` |
| 5 | SB(uc=True) → about:blank | Patchright launch → about:blank |

requirements.txt:
```
patchright>=1.49.0
requests>=2.32.0
```

## Cloudflare Turnstile Strategy

Stealth-only approach (no CAPTCHA solver initially):

1. `page.goto("https://account.jagex.com/")`
2. Wait for Turnstile iframe: `page.wait_for_selector("iframe[src*='challenges.cloudflare.com']")`
3. Click checkbox inside iframe
4. Wait for callback/page progression
5. Retry once if not resolved within 30s
6. Return `captcha_required` status if still blocked

Patchright's patched CDP should make Turnstile present easier challenges. If stealth alone isn't sufficient, the `captcha_required` status allows plugging in CapSolver/2Captcha later without architectural changes.

## Async Bridge

Patchright is async. Entry point bridges with `asyncio.run()`:
```python
if __name__ == "__main__":
    asyncio.run(main())
```
Invisible to Dart side — subprocess sees stdout/JSON as before.

## Timeouts

| Command | Python-side | Dart-side (safety net) |
|---------|------------|----------------------|
| validate | 60s | 2 min |
| create-account | 5 min | 10 min |
| session | none | none |

## Migration Strategy

- Full replacement, not incremental
- Old script preserved as `account_automation_legacy.py` for comparison
- Delete legacy once Patchright confirmed working
- Rollback: swap Python files only, zero Dart changes needed
