# scripts/automation/commands/validate.py
import sys
from typing import Optional, Callable

from ..models import AutomationResult, AutomationStatus
from ..proxy import preflight_proxy
from ..browser import launch_browser, close_browser
from ..helpers import extract_ip_from_response, human_delay

IP_CHECK_URLS = [
    "https://api.ipify.org?format=json",
    "https://httpbin.org/ip",
    "https://api.myip.com",
]


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

    err, cleaned_proxy = preflight_proxy(proxy_url, expected_ip, log_fn)
    if err:
        return err

    pw = browser = None
    try:
        pw, browser, context, page = await launch_browser(
            proxy_url=cleaned_proxy,
            headless=headless,
        )
        log_fn("[INFO] Browser started successfully")

        actual_ip = None
        last_error = None

        for i, url in enumerate(IP_CHECK_URLS):
            try:
                log_fn(f"[INFO] IP check {i + 1}/{len(IP_CHECK_URLS)}: {url}")
                await page.goto(url, wait_until="domcontentloaded")
                human_delay(0.3, 0.8)

                body = await page.text_content("body") or ""
                actual_ip = extract_ip_from_response(body)
                if actual_ip:
                    log_fn(f"[INFO] Got IP: {actual_ip}")
                    break
            except Exception as e:
                last_error = f"{type(e).__name__}: {e}"
                log_fn(f"[WARNING] IP check failed: {last_error}")

        if not actual_ip:
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message=f"Could not determine current IP. Last error: {last_error}",
                expected_ip=expected_ip,
            )

        ip_matches = (expected_ip in actual_ip) or (actual_ip in expected_ip)
        if ip_matches:
            return AutomationResult(
                status=AutomationStatus.SUCCESS.value,
                message="Proxy IP validation successful",
                expected_ip=expected_ip,
                actual_ip=actual_ip,
            )

        return AutomationResult(
            status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
            message=f"IP mismatch: expected {expected_ip}, got {actual_ip}",
            expected_ip=expected_ip,
            actual_ip=actual_ip,
        )

    except Exception as e:
        return AutomationResult(
            status=AutomationStatus.BROWSER_ERROR.value,
            message=f"Browser startup failed: {type(e).__name__}: {e}",
            expected_ip=expected_ip,
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
