# scripts/automation/browser.py
from typing import Optional, Tuple

from patchright.async_api import async_playwright, Browser, BrowserContext, Page, Playwright

from .proxy import parse_proxy_credentials


async def launch_browser(
    proxy_url: Optional[str] = None,
    headless: bool = False,
) -> Tuple[Playwright, Browser, BrowserContext, Page]:
    """Launch a stealth Patchright browser with optional proxy.

    Returns (playwright, browser, context, page) tuple.
    Caller is responsible for closing: await browser.close(); await pw.stop()
    """
    pw = await async_playwright().start()

    launch_args = [
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--disable-webrtc",
        "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
        "--disable-features=IsolateOrigins,site-per-process",
    ]

    # Use bundled Chromium (no channel) — system Chrome may not be installed (e.g. WSL)
    browser = await pw.chromium.launch(
        headless=headless,
        args=launch_args,
    )

    proxy_config = parse_proxy_credentials(proxy_url) if proxy_url else None

    context = await browser.new_context(
        proxy=proxy_config,
        viewport={"width": 1920, "height": 1080},
        locale="en-US",
        timezone_id="America/New_York",
    )

    page = await context.new_page()
    return pw, browser, context, page


async def close_browser(pw: Playwright, browser: Browser):
    """Cleanly shut down browser and playwright."""
    try:
        await browser.close()
    except Exception:
        pass
    try:
        await pw.stop()
    except Exception:
        pass
