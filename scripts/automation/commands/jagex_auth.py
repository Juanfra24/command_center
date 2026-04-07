# scripts/automation/commands/jagex_auth.py
"""
Jagex OAuth browser flow automation.
Acquires a Jagex game session and writes credentials.properties to a
bot profile directory. Returns refresh_token for future renewals.

Credentials file format written:
  JX_CHARACTER_ID=<accountId>
  JX_SESSION_ID=<sessionId>
  JX_REFRESH_TOKEN=
  JX_DISPLAY_NAME=<displayName>
  JX_ACCESS_TOKEN=
"""
import asyncio
import requests
from pathlib import Path
from typing import Callable, Optional

from ..models import AutomationResult, AutomationStatus
from ..browser import launch_browser, close_browser
from ..helpers import human_type, click_first_match, human_delay
from ..imap_poller import fetch_verification_code


_JAGEX_TOKEN_URL = "https://account.jagex.com/oauth2/token"
_JAGEX_SESSION_URL = "https://auth.jagex.com/game-session/v1/sessions"
_JAGEX_ACCOUNTS_URL = "https://auth.jagex.com/game-session/v1/accounts"
_JAGEX_LOGIN_URL = "https://account.jagex.com/login"

_SUBMIT_SELECTORS = [
    'button[type="submit"]',
    'button:has-text("Continue")',
    'button:has-text("Next")',
    'button:has-text("Log in")',
]


def _write_credentials_file(profile_dir: str, session_id: str, character_id: str, display_name: str) -> None:
    """Write the Jagex credentials.properties file the game client reads."""
    jagex_dir = Path(profile_dir)
    jagex_dir.mkdir(parents=True, exist_ok=True)
    content = "\n".join([
        "#Do not share this file with anyone",
        f"JX_CHARACTER_ID={character_id}",
        f"JX_SESSION_ID={session_id}",
        "JX_REFRESH_TOKEN=",
        f"JX_DISPLAY_NAME={display_name}",
        "JX_ACCESS_TOKEN=",
        "",  # trailing newline
    ])
    (jagex_dir / "credentials.properties").write_text(content, encoding="utf-8")


def _exchange_id_token_for_session(id_token: str, log_fn: Callable) -> tuple:
    """
    HTTP-only: exchange id_token for a game sessionId + accountId + displayName.
    Returns (session_id, character_id, display_name).
    Raises requests.HTTPError on failure.
    """
    log_fn("[jagex-auth] Creating game session from id_token...")
    session_resp = requests.post(
        _JAGEX_SESSION_URL,
        json={"idToken": id_token},
        timeout=15,
    )
    session_resp.raise_for_status()
    session_id = session_resp.json()["sessionId"]

    log_fn("[jagex-auth] Fetching account list...")
    accounts_resp = requests.get(
        _JAGEX_ACCOUNTS_URL,
        headers={"Authorization": f"Bearer {session_id}"},
        timeout=15,
    )
    accounts_resp.raise_for_status()
    accounts = accounts_resp.json()
    if not accounts:
        raise ValueError("No accounts returned from game-session API")

    account = accounts[0]
    return session_id, account["accountId"], account["displayName"]


async def jagex_auth(
    email: str,
    password: str,
    profile_dir: str,
    imap_host: Optional[str] = None,
    imap_user: Optional[str] = None,
    imap_pass: Optional[str] = None,
    debug: bool = False,
    log_fn: Callable = print,
) -> AutomationResult:
    """
    Full Jagex OAuth browser flow.
    Writes credentials.properties to profile_dir/credentials.properties.
    Returns AutomationResult with data={'refresh_token', 'character_id', 'display_name'}.
    """
    pw = None
    browser = None
    captured_tokens: dict = {}

    try:
        log_fn("[jagex-auth] Launching browser...")
        pw, browser, _context, page = await launch_browser(
            proxy_url=None,  # OAuth flow runs on user's own IP
            headless=not debug,
        )

        # Intercept the token endpoint response to capture tokens
        async def on_response(response):
            if _JAGEX_TOKEN_URL in response.url:
                try:
                    body = await response.json()
                    captured_tokens.update(body)
                    log_fn("[jagex-auth] OAuth token response captured")
                except Exception:
                    pass

        page.on("response", on_response)

        # Navigate to Jagex login
        log_fn("[jagex-auth] Navigating to Jagex login...")
        await page.goto(_JAGEX_LOGIN_URL, wait_until="networkidle", timeout=30000)
        await human_delay(1.0, 2.0)

        # Fill email
        log_fn("[jagex-auth] Entering email...")
        email_selector = 'input[type="email"], input[name="email"], input[id*="email"]'
        await page.wait_for_selector(email_selector, timeout=15000)
        await human_type(page, email_selector, email)
        await human_delay(0.5, 1.0)

        # Click Next / Continue (Jagex login is a two-step form)
        await click_first_match(page, _SUBMIT_SELECTORS, label="Submit email", log_fn=log_fn)
        await human_delay(1.0, 2.0)

        # Fill password
        log_fn("[jagex-auth] Entering password...")
        pass_selector = 'input[type="password"]'
        await page.wait_for_selector(pass_selector, timeout=10000)
        await human_type(page, pass_selector, password)
        await human_delay(0.5, 1.0)

        # Submit login
        await click_first_match(page, _SUBMIT_SELECTORS, label="Submit password", log_fn=log_fn)

        # Wait for token capture or email verification prompt (up to 20s)
        code_selector = 'input[name*="code"], input[placeholder*="code"], input[aria-label*="code"]'
        for _ in range(40):
            await asyncio.sleep(0.5)
            if "refresh_token" in captured_tokens or "id_token" in captured_tokens:
                break

            # Check for email verification code input
            try:
                if await page.locator(code_selector).first.is_visible(timeout=300):
                    if imap_host and imap_user and imap_pass:
                        log_fn("[jagex-auth] Email verification required, polling IMAP...")
                        loop = asyncio.get_running_loop()
                        code = await loop.run_in_executor(
                            None,
                            lambda: fetch_verification_code(
                                imap_host=imap_host,
                                imap_user=imap_user,
                                imap_pass=imap_pass,
                                target_email=email,
                                timeout=120,
                                log_fn=log_fn,
                            ),
                        )
                        if code:
                            log_fn(f"[jagex-auth] Verification code received: {code[:3]}***")
                            await human_type(page, code_selector, code)
                            await human_delay(0.3, 0.6)
                            await click_first_match(
                                page, _SUBMIT_SELECTORS, label="Submit code", log_fn=log_fn
                            )
            except Exception:
                pass

        if "refresh_token" not in captured_tokens and "id_token" not in captured_tokens:
            return AutomationResult(
                status=AutomationStatus.UNKNOWN_ERROR.value,
                message="OAuth token was not captured. Login may have failed or Jagex changed their auth flow.",
            )

        id_token = captured_tokens.get("id_token", "")
        refresh_token = captured_tokens.get("refresh_token", "")

        if not id_token:
            return AutomationResult(
                status=AutomationStatus.UNKNOWN_ERROR.value,
                message="id_token missing from OAuth response — cannot create game session",
            )

        log_fn("[jagex-auth] Exchanging id_token for game session...")
        session_id, character_id, display_name = _exchange_id_token_for_session(id_token, log_fn)

        log_fn(f"[jagex-auth] Writing credentials.properties for {display_name}...")
        _write_credentials_file(profile_dir, session_id, character_id, display_name)

        log_fn("[jagex-auth] Done.")
        return AutomationResult(
            status=AutomationStatus.SUCCESS.value,
            message=f"Jagex auth complete for {display_name}",
            data={
                "refresh_token": refresh_token,
                "character_id": character_id,
                "display_name": display_name,
            },
        )

    except Exception as e:
        log_fn(f"[jagex-auth] Error: {e}")
        return AutomationResult(
            status=AutomationStatus.UNKNOWN_ERROR.value,
            message=f"Jagex auth failed: {e}",
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
