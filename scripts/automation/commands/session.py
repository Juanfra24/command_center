# scripts/automation/commands/session.py
import asyncio
import time
from typing import Optional, Callable

from ..models import AutomationResult, AutomationStatus
from ..proxy import preflight_proxy
from ..browser import launch_browser, close_browser
from ..helpers import extract_ip_from_response, human_delay, IP_CHECK_URLS


async def launch_session(
    proxy_url: Optional[str],
    expected_ip: str,
    keep_open: bool = False,
    debug: bool = False,
    log_fn: Callable[[str], None] = print,
) -> AutomationResult:
    """Launch a browser session with proxy for manual use.
    Blocks until the user closes the browser window."""
    log_fn("[INFO] ===== Browser Session =====")

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
            headless=False,  # Always headed for sessions
        )
        log_fn("[STEP 2/4] OK - browser started")

        # Step 3/4: Validate proxy IP
        log_fn("[STEP 3/4] Checking IP address...")
        actual_ip = None
        for i, url in enumerate(IP_CHECK_URLS):
            try:
                log_fn(f"[STEP 3/4] IP check {i + 1}/{len(IP_CHECK_URLS)}: {url}")
                await page.goto(url, wait_until="domcontentloaded")
                await human_delay(0.5, 1.0)
                body = await page.text_content("body") or ""
                actual_ip = extract_ip_from_response(body)
                if actual_ip:
                    log_fn(f"[STEP 3/4] Got IP: {actual_ip}")
                    break
            except Exception as e:
                log_fn(f"[STEP 3/4] IP check failed: {e}")

        if actual_ip:
            ip_matches = actual_ip.strip() == expected_ip.strip()
            if ip_matches:
                log_fn(f"[STEP 3/4] OK - proxy IP validated: {actual_ip}")
            else:
                log_fn(f"[STEP 3/4] WARNING - IP mismatch: expected {expected_ip}, got {actual_ip}")
        else:
            log_fn("[STEP 3/4] WARNING - could not determine IP")

        # Step 4/4: Navigate to Jagex
        log_fn("[STEP 4/4] Navigating to account.jagex.com...")
        await page.goto("https://account.jagex.com/", wait_until="domcontentloaded")
        await human_delay(2.0, 3.0)
        log_fn("[STEP 4/4] OK - browser is ready. Close the browser window when done.")

        # Block until browser is closed by user (max 4 hours to prevent orphans)
        max_duration = 4 * 60 * 60  # 4 hours
        start_time = time.monotonic()
        try:
            while True:
                await asyncio.sleep(2)
                if time.monotonic() - start_time > max_duration:
                    log_fn("[INFO] Session reached maximum duration (4h), closing")
                    break
                try:
                    await page.title()
                except Exception:
                    log_fn("[INFO] Browser closed by user")
                    break
        except (KeyboardInterrupt, asyncio.CancelledError):
            log_fn("[INFO] Session ended by signal")

        return AutomationResult(
            status=AutomationStatus.SUCCESS.value,
            message="Browser session ended",
            expected_ip=expected_ip,
            actual_ip=actual_ip,
        )

    except Exception as e:
        log_fn(f"[ERROR] Session launch failed: {type(e).__name__}: {e}")
        return AutomationResult(
            status=AutomationStatus.BROWSER_ERROR.value,
            message=f"Session launch failed: {type(e).__name__}: {e}",
            expected_ip=expected_ip,
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
