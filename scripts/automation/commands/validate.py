# scripts/automation/commands/validate.py
import sys
from typing import Optional, Callable

from ..models import AutomationResult, AutomationStatus
from ..proxy import preflight_proxy
from ..browser import launch_browser, close_browser
from ..helpers import extract_ip_from_response, human_delay, IP_CHECK_URLS


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
                await human_delay(0.3, 0.8)

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
        ip_matches = actual_ip.strip() == expected_ip.strip()
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
