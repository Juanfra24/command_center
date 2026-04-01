# scripts/automation/browser.py
from typing import Optional, Tuple

from patchright.async_api import (
    async_playwright,
    Browser,
    BrowserContext,
    Page,
    Playwright,
)

from .proxy import parse_proxy_credentials


async def launch_browser(
    proxy_url: Optional[str] = None,
    headless: bool = False,
) -> Tuple[Playwright, Browser, BrowserContext, Page]:
    """Launch a stealth browser with optional proxy.

    Prefers system Chrome (channel="chrome") for better anti-detection —
    Cloudflare fingerprints bundled Chromium differently.
    Falls back to bundled Chromium if Chrome is not installed.

    Returns (playwright, browser, context, page) tuple.
    Caller is responsible for closing: await browser.close(); await pw.stop()
    """
    pw = await async_playwright().start()

    try:
        launch_args = [
            "--disable-dev-shm-usage",
            "--no-sandbox",
            "--disable-webrtc",
            "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
            "--disable-features=IsolateOrigins,site-per-process",
        ]

        # Try system Chrome first — much better Cloudflare bypass rate.
        # Falls back to bundled Chromium if Chrome is not installed.
        browser = None
        for channel in ("chrome", None):
            try:
                browser = await pw.chromium.launch(
                    headless=headless,
                    channel=channel,
                    args=launch_args,
                )
                label = f"Chrome ({browser.version})" if channel else f"Chromium ({browser.version})"
                print(f"[browser] Launched {label}", flush=True)
                break
            except Exception:
                if channel is None:
                    raise  # both failed, propagate
                # Chrome not installed, try bundled Chromium next

        proxy_config = parse_proxy_credentials(proxy_url) if proxy_url else None

        context = await browser.new_context(
            proxy=proxy_config,
            viewport={"width": 1920, "height": 1080},
            locale="en-US",
            timezone_id="America/New_York",
        )

        page = await context.new_page()
        return pw, browser, context, page
    except Exception:
        await pw.stop()
        raise


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
