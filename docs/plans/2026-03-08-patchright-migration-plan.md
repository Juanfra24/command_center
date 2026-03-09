# SeleniumBase → Patchright Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace SeleniumBase with Patchright for browser automation, fixing broken Cloudflare bypass while restructuring the monolithic Python script into modules.

**Architecture:** Dart side unchanged — same subprocess + JSON stdout protocol. Python side rewritten from SeleniumBase sync API to Patchright async API, split into `scripts/automation/` modules. `PythonSetupService` updated to install Patchright + bundled Chromium.

**Tech Stack:** Python 3.8+, Patchright (patched Playwright), asyncio, IMAP, argparse

---

## Phase 1: Foundation (models, proxy, helpers)

### Task 1: Create models.py

**Files:**
- Create: `scripts/automation/__init__.py`
- Create: `scripts/automation/models.py`

**Step 1: Create the automation package**

```python
# scripts/automation/__init__.py
```
(empty file)

**Step 2: Write models.py**

Port `AutomationResult` and `AutomationStatus` from the old script. These are pure data — no browser dependency.

```python
# scripts/automation/models.py
import json
from dataclasses import dataclass, asdict
from enum import Enum
from typing import Optional, Dict, Any


class AutomationStatus(Enum):
    SUCCESS = "success"
    PROXY_VALIDATION_FAILED = "proxy_validation_failed"
    BROWSER_ERROR = "browser_error"
    TIMEOUT = "timeout"
    CAPTCHA_REQUIRED = "captcha_required"
    ACCOUNT_CREATED = "account_created"
    UNKNOWN_ERROR = "unknown_error"


@dataclass
class AutomationResult:
    status: str
    message: str
    expected_ip: Optional[str] = None
    actual_ip: Optional[str] = None
    data: Optional[Dict[str, Any]] = None

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2)
```

**Step 3: Verify import works**

Run: `cd scripts && python -c "from automation.models import AutomationResult, AutomationStatus; print('OK')"`
Expected: `OK`

**Step 4: Commit**

```bash
git add scripts/automation/__init__.py scripts/automation/models.py
git commit -m "feat(scripts): add automation models module"
```

---

### Task 2: Create proxy.py

**Files:**
- Create: `scripts/automation/proxy.py`

**Step 1: Write proxy.py**

Port proxy helpers: cleaning, format validation, TCP ping, host/port parsing, masking.

```python
# scripts/automation/proxy.py
import re
import socket
from typing import Optional, Tuple

from .models import AutomationResult, AutomationStatus


def mask_proxy(proxy: Optional[str]) -> str:
    """Mask password in proxy string for logging."""
    if not proxy:
        return "None"
    s = proxy.strip().strip("'\"")
    try:
        if "@" in s:
            creds, hostport = s.split("@", 1)
            user = creds.split(":", 1)[0]
            return f"{user}:***@{hostport}"
        return s
    except Exception:
        return s


def clean_proxy(proxy: Optional[str]) -> Optional[str]:
    """Clean proxy string: strip whitespace, quotes, scheme prefix.
    Patchright expects: user:pass@host:port (no scheme)."""
    if not proxy or proxy.lower() == "none":
        return None
    p = proxy.strip().strip("'\"")
    p = p.replace("http://", "").replace("https://", "")
    return p


def validate_proxy_format(proxy: str) -> Optional[str]:
    """Return error message if proxy format is invalid, None if OK."""
    if not proxy:
        return None
    if proxy.startswith(("socks4://", "socks5://")):
        return None
    ok = re.fullmatch(
        r"([^:@\s]+):(\d+)|([^:@\s]+):([^@\s]+)@([^:@\s]+):(\d+)", proxy
    )
    if not ok:
        return f"Bad proxy format: {proxy}. Use host:port or user:pass@host:port"
    if proxy.count("@") > 1:
        return f"Proxy contains multiple '@': {proxy}. URL-encode the password."
    return None


def parse_host_port(proxy: str) -> Optional[Tuple[str, int]]:
    """Extract (host, port) from proxy string."""
    if not proxy:
        return None
    try:
        target = proxy.split("@", 1)[-1]
        host, port_s = target.split(":", 1)
        return host, int(port_s)
    except Exception:
        return None


def parse_proxy_credentials(proxy: str) -> Optional[dict]:
    """Parse user:pass@host:port into Playwright proxy dict."""
    if not proxy:
        return None
    try:
        if "@" in proxy:
            creds, hostport = proxy.split("@", 1)
            user, pwd = creds.split(":", 1)
            host, port = hostport.split(":", 1)
            return {
                "server": f"http://{host}:{port}",
                "username": user,
                "password": pwd,
            }
        else:
            host, port = proxy.split(":", 1)
            return {"server": f"http://{host}:{port}"}
    except Exception:
        return None


def tcp_ping(host: str, port: int, timeout: int = 6) -> Tuple[bool, str]:
    """Check if proxy host:port is reachable via TCP."""
    try:
        sock = socket.create_connection((host, port), timeout=timeout)
        sock.close()
        return True, "TCP connect OK"
    except Exception as e:
        return False, f"TCP connect failed: {e}"


def preflight_proxy(proxy_raw: Optional[str], expected_ip: str, log_fn=print) -> Tuple[Optional[AutomationResult], Optional[str]]:
    """Run proxy preflight checks. Returns (error_result, cleaned_proxy).
    error_result is None on success."""
    cleaned = clean_proxy(proxy_raw)
    log_fn(f"[INFO] Proxy (masked): {mask_proxy(cleaned)}")
    log_fn(f"[INFO] Expected IP: {expected_ip}")

    if cleaned:
        fmt_err = validate_proxy_format(cleaned)
        if fmt_err:
            return AutomationResult(
                status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                message=fmt_err,
                expected_ip=expected_ip,
            ), None

        hp = parse_host_port(cleaned)
        if hp:
            ok, msg = tcp_ping(hp[0], hp[1])
            log_fn(f"[INFO] Proxy reachability {hp[0]}:{hp[1]}: {msg}")
            if not ok:
                return AutomationResult(
                    status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                    message=f"Proxy not reachable: {hp[0]}:{hp[1]}. {msg}",
                    expected_ip=expected_ip,
                ), None

    return None, cleaned
```

**Step 2: Verify import works**

Run: `cd scripts && python -c "from automation.proxy import preflight_proxy, parse_proxy_credentials; print('OK')"`
Expected: `OK`

**Step 3: Commit**

```bash
git add scripts/automation/proxy.py
git commit -m "feat(scripts): add proxy validation module"
```

---

### Task 3: Create helpers.py

**Files:**
- Create: `scripts/automation/helpers.py`

**Step 1: Write helpers.py**

Port shared helpers: human_type, click_first_match, human_delay, IP extraction, name/email/password/DOB generation.

```python
# scripts/automation/helpers.py
import re
import json
import time
import random
import string
from typing import Optional, List

from patchright.async_api import Page


async def human_type(page: Page, selector: str, text: str,
                     min_delay: float = 30, max_delay: float = 120):
    """Type text character-by-character with human-like delays.
    Delays are in milliseconds (Playwright convention)."""
    await page.click(selector)
    await page.type(selector, text, delay=random.uniform(min_delay, max_delay))


async def click_first_match(page: Page, selectors: List[str],
                            timeout: int = 5000, label: str = "",
                            log_fn=print) -> bool:
    """Try clicking each selector in order; return True on first success.
    timeout is in milliseconds."""
    for sel in selectors:
        try:
            await page.click(sel, timeout=timeout)
            if label:
                log_fn(f"[INFO] {label} with: {sel}")
            return True
        except Exception:
            continue
    return False


def human_delay(min_sec: float = 0.5, max_sec: float = 2.0):
    """Sleep for a random duration to mimic human behavior."""
    time.sleep(random.uniform(min_sec, max_sec))


def extract_ip_from_response(text: str) -> Optional[str]:
    """Extract IP address from JSON API response text."""
    try:
        data = json.loads(text)
        for key in ("ip", "origin", "query"):
            if key in data:
                val = data[key]
                if isinstance(val, str):
                    return val.split(",")[0].strip()
    except Exception:
        pass
    match = re.search(r"\d{1,3}(?:\.\d{1,3}){3}", text)
    return match.group() if match else None


def generate_account_name() -> str:
    """Generate a gaming-style account name like SwiftArcher42."""
    adjectives = [
        "Dark", "Shadow", "Iron", "Swift", "Storm", "Frost", "Wild", "Steel",
        "Brave", "Silent", "Noble", "Fierce", "Crimson", "Ancient", "Mystic",
        "Golden", "Chaos", "Void", "Ember", "Ash", "Stone", "Rune", "Blood",
    ]
    nouns = [
        "Knight", "Mage", "Archer", "Blade", "Wolf", "Dragon", "Hunter",
        "Slayer", "Warrior", "Ranger", "Guard", "Titan", "Phoenix", "Hawk",
        "Bear", "Viper", "Sage", "Reaper", "Lord", "King", "Rogue", "Scout",
    ]
    name = random.choice(adjectives) + random.choice(nouns)
    if random.random() < 0.7:
        name += str(random.randint(10, 999))
    return name


def generate_email(account_name: str) -> str:
    """Derive email from account name: e.g., swiftarcher42@onemanco.org"""
    clean = re.sub(r"[^a-zA-Z0-9]", "", account_name).lower()
    return f"{clean}@onemanco.org"


def generate_password() -> str:
    """Generate a strong password meeting Jagex requirements (12-16 chars)."""
    length = random.randint(12, 16)
    chars = [
        random.choice(string.ascii_uppercase),
        random.choice(string.ascii_lowercase),
        random.choice(string.digits),
        random.choice("!@#$%^&*"),
    ]
    remaining = length - len(chars)
    pool = string.ascii_letters + string.digits + "!@#$%^&*"
    chars += random.choices(pool, k=remaining)
    random.shuffle(chars)
    return "".join(chars)


def generate_random_dob() -> dict:
    """Generate random DOB (18-35 years old)."""
    year = random.randint(1991, 2008)
    month = random.randint(1, 12)
    day = random.randint(1, 28)
    return {"day": str(day), "month": str(month), "year": str(year)}
```

**Step 2: Verify import works**

Run: `cd scripts && python -c "from automation.helpers import generate_account_name, generate_password; print(generate_account_name(), generate_password())"`
Expected: something like `SwiftArcher42 kX3!mBpQ9rYz`

**Step 3: Commit**

```bash
git add scripts/automation/helpers.py
git commit -m "feat(scripts): add shared automation helpers"
```

---

### Task 4: Create imap_poller.py

**Files:**
- Create: `scripts/automation/imap_poller.py`

**Step 1: Write imap_poller.py**

Port the IMAP verification code polling logic. This is independent of the browser library.

```python
# scripts/automation/imap_poller.py
import re
import time
import email
import imaplib
from typing import Optional, Callable


def fetch_verification_code(
    imap_host: str,
    imap_user: str,
    imap_pass: str,
    target_email: str,
    timeout: int = 120,
    log_fn: Callable[[str], None] = print,
) -> Optional[str]:
    """Fetch the 6-digit Jagex verification code from IMAP.
    Keeps a single connection open across poll iterations."""
    log_fn(f"[INFO] Checking IMAP for verification code (target: {target_email})...")
    start_time = time.time()
    mail = None

    try:
        while time.time() - start_time < timeout:
            # Connect/reconnect only when needed
            if mail is None:
                try:
                    mail = imaplib.IMAP4_SSL(imap_host, 993)
                    mail.login(imap_user, imap_pass)
                    log_fn("[INFO] IMAP connected")
                except Exception as e:
                    log_fn(f"[WARNING] IMAP connect error: {e}")
                    mail = None
                    time.sleep(5)
                    continue

            try:
                mail.select("INBOX")
                _, messages = mail.search(None, '(FROM "jagex" UNSEEN)')
                if not messages[0]:
                    _, messages = mail.search(None, '(FROM "jagex.com")')

                email_ids = messages[0].split()
                for eid in reversed(email_ids[-10:]):
                    _, msg_data = mail.fetch(eid, "(RFC822)")
                    msg = email.message_from_bytes(msg_data[0][1])

                    to_header = msg.get("To", "").lower()
                    if (
                        target_email.lower() not in to_header
                        and target_email.split("@")[0] not in to_header
                    ):
                        continue

                    subject = msg.get("Subject", "")
                    log_fn(f"[INFO] Found Jagex email: {subject}")

                    body = ""
                    if msg.is_multipart():
                        for part in msg.walk():
                            ct = part.get_content_type()
                            if ct in ("text/html", "text/plain"):
                                payload = part.get_payload(decode=True)
                                if payload:
                                    body += payload.decode("utf-8", errors="ignore")
                    else:
                        payload = msg.get_payload(decode=True)
                        if payload:
                            body = payload.decode("utf-8", errors="ignore")

                    code_match = re.search(r"\b(\d{6})\b", body)
                    if code_match:
                        code = code_match.group(1)
                        log_fn(f"[INFO] Found verification code: {code}")
                        return code

            except Exception as e:
                log_fn(f"[WARNING] IMAP poll error: {e}")
                try:
                    mail.logout()
                except Exception:
                    pass
                mail = None
                time.sleep(5)
                continue

            log_fn(
                f"[INFO] No code yet, retrying in 5s... "
                f"({int(time.time() - start_time)}s elapsed)"
            )
            time.sleep(5)

    finally:
        if mail is not None:
            try:
                mail.logout()
            except Exception:
                pass

    log_fn("[WARNING] Timed out waiting for verification code")
    return None
```

**Step 2: Verify import works**

Run: `cd scripts && python -c "from automation.imap_poller import fetch_verification_code; print('OK')"`
Expected: `OK`

**Step 3: Commit**

```bash
git add scripts/automation/imap_poller.py
git commit -m "feat(scripts): add IMAP verification code poller"
```

---

## Phase 2: Browser Layer

### Task 5: Create browser.py

**Files:**
- Create: `scripts/automation/browser.py`

**Step 1: Write browser.py**

Central browser launch config — all stealth decisions live here.

```python
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

    browser = await pw.chromium.launch(
        channel="chrome",
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
```

**Step 2: Update requirements.txt**

```
# scripts/requirements.txt
patchright>=1.49.0
requests>=2.32.0
```

**Step 3: Verify import works (requires patchright installed)**

Run: `cd scripts && pip install patchright && patchright install chromium && python -c "from automation.browser import launch_browser; print('OK')"`
Expected: `OK` (after Chromium downloads)

**Step 4: Commit**

```bash
git add scripts/automation/browser.py scripts/requirements.txt
git commit -m "feat(scripts): add Patchright browser launch module"
```

---

## Phase 3: Commands

### Task 6: Create commands/validate.py

**Files:**
- Create: `scripts/automation/commands/__init__.py`
- Create: `scripts/automation/commands/validate.py`

**Step 1: Write validate.py**

Port the IP validation command to Patchright async API.

```python
# scripts/automation/commands/__init__.py
```
(empty file)

```python
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
```

**Step 2: Verify import works**

Run: `cd scripts && python -c "from automation.commands.validate import validate_proxy_ip; print('OK')"`
Expected: `OK`

**Step 3: Commit**

```bash
git add scripts/automation/commands/__init__.py scripts/automation/commands/validate.py
git commit -m "feat(scripts): add proxy validation command"
```

---

### Task 7: Create commands/create_account.py

**Files:**
- Create: `scripts/automation/commands/create_account.py`

**Step 1: Write create_account.py**

Port the 13-step account creation flow to Patchright. This is the largest file (~280 lines).

```python
# scripts/automation/commands/create_account.py
import sys
from typing import Optional, Callable

from ..models import AutomationResult, AutomationStatus
from ..proxy import preflight_proxy
from ..browser import launch_browser, close_browser
from ..helpers import (
    human_type, click_first_match, human_delay,
    extract_ip_from_response,
    generate_account_name, generate_email, generate_password, generate_random_dob,
)
from ..imap_poller import fetch_verification_code

IP_CHECK_URLS = [
    "https://api.ipify.org?format=json",
    "https://httpbin.org/ip",
    "https://api.myip.com",
]


async def _is_past_cloudflare(page, log_fn) -> bool:
    """Check if we've passed the Cloudflare challenge."""
    try:
        title = await page.title()
        if "just a moment" in title.lower():
            return False

        content = await page.content()
        content_lower = content.lower()

        cf_indicators = ["are you a robot", "verify you are human", "checking your browser"]
        if any(kw in content_lower for kw in cf_indicators):
            return False

        jagex_indicators = [
            "create an account", "registration", "log in",
            "jagex account", 'id="email"',
        ]
        return any(kw in content_lower for kw in jagex_indicators)
    except Exception:
        return False


async def _handle_turnstile(page, log_fn, max_attempts: int = 5) -> bool:
    """Attempt to pass Cloudflare Turnstile challenge."""
    for attempt in range(1, max_attempts + 1):
        log_fn(f"[INFO] Turnstile attempt {attempt}/{max_attempts}")

        if await _is_past_cloudflare(page, log_fn):
            log_fn("[INFO] Already past Cloudflare")
            return True

        human_delay(1.0, 2.0)

        # Try to find and click the Turnstile checkbox inside its iframe
        try:
            turnstile_frame = page.frame_locator(
                "iframe[src*='challenges.cloudflare.com']"
            )
            checkbox = turnstile_frame.locator("input[type='checkbox'], .cb-lb")
            await checkbox.click(timeout=5000)
            log_fn("[INFO] Clicked Turnstile checkbox")
        except Exception as e:
            log_fn(f"[WARNING] Turnstile click failed: {e}")
            # Fallback: try clicking body of iframe
            try:
                turnstile_frame = page.frame_locator(
                    "iframe[src*='challenges.cloudflare.com']"
                )
                await turnstile_frame.locator("body").click(timeout=3000)
                log_fn("[INFO] Clicked Turnstile iframe body")
            except Exception:
                pass

        # Wait for verification
        log_fn("[INFO] Waiting for Turnstile verification...")
        human_delay(5.0, 8.0)

        if await _is_past_cloudflare(page, log_fn):
            log_fn("[INFO] Turnstile solved!")
            return True

        # Retry: reload the page
        if attempt < max_attempts:
            log_fn("[INFO] Reloading page for retry...")
            try:
                await page.goto("https://account.jagex.com/", wait_until="domcontentloaded")
                human_delay(3.0, 5.0)
            except Exception:
                pass

    return False


async def create_account(
    proxy_url: Optional[str],
    expected_ip: str,
    headless: bool = False,
    debug: bool = False,
    imap_host: Optional[str] = None,
    imap_user: Optional[str] = None,
    imap_pass: Optional[str] = None,
    log_fn: Callable[[str], None] = print,
) -> AutomationResult:
    """Create a new Jagex account through the proxy."""
    log_fn("[INFO] ===== Account Creation =====")

    err, cleaned_proxy = preflight_proxy(proxy_url, expected_ip, log_fn)
    if err:
        return err

    account_name = generate_account_name()
    generated_email = generate_email(account_name)
    generated_password = generate_password()
    dob = generate_random_dob()
    log_fn(f"[INFO] Account: {account_name}, Email: {generated_email}")
    log_fn(f"[INFO] DOB: {dob['day']}/{dob['month']}/{dob['year']}")

    pw = browser = None
    try:
        pw, browser, context, page = await launch_browser(
            proxy_url=cleaned_proxy,
            headless=headless,
        )
        log_fn("[INFO] Browser started for account creation")

        # Step 1: Validate proxy IP
        log_fn("[INFO] Step 1: Validating proxy IP...")
        actual_ip = None
        for i, url in enumerate(IP_CHECK_URLS):
            try:
                await page.goto(url, wait_until="domcontentloaded")
                human_delay(1.0, 2.0)
                body = await page.text_content("body") or ""
                actual_ip = extract_ip_from_response(body)
                if actual_ip:
                    log_fn(f"[INFO] Got IP: {actual_ip}")
                    break
            except Exception as e:
                log_fn(f"[WARNING] IP check failed: {e}")

        if not actual_ip:
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message="Could not determine current IP",
                expected_ip=expected_ip,
            )

        if not ((expected_ip in actual_ip) or (actual_ip in expected_ip)):
            return AutomationResult(
                status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                message=f"IP mismatch: expected {expected_ip}, got {actual_ip}",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )
        log_fn(f"[INFO] Proxy IP validated: {actual_ip}")

        # Step 2: Navigate to Jagex
        log_fn("[INFO] Step 2: Navigating to account.jagex.com...")
        await page.goto("https://account.jagex.com/", wait_until="domcontentloaded")
        human_delay(2.0, 3.0)

        # Step 3: Handle Cloudflare Turnstile
        log_fn("[INFO] Step 3: Handling Cloudflare Turnstile...")
        if not await _handle_turnstile(page, log_fn):
            return AutomationResult(
                status=AutomationStatus.CAPTCHA_REQUIRED.value,
                message="Could not pass Cloudflare Turnstile after all attempts",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )

        # Step 4: Handle cookie consent
        log_fn("[INFO] Step 4: Handling cookie consent...")
        cookie_selectors = [
            "#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll",
            "button#CybotCookiebotDialogBodyButtonDecline",
            "//button[contains(text(), 'Use necessary cookies only')]",
            "//button[contains(text(), 'Allow all cookies')]",
        ]
        await click_first_match(page, cookie_selectors, timeout=3000, label="Cookie consent handled", log_fn=log_fn)
        human_delay(1.0, 2.0)

        # Step 5: Click 'Create an account'
        log_fn("[INFO] Step 5: Clicking 'Create an account'...")
        create_selectors = [
            "a[href*='registration']",
            "text=Create an account",
            "text=create an account",
            "a.create-account-link",
        ]
        created = await click_first_match(page, create_selectors, timeout=5000, label="Create account clicked", log_fn=log_fn)
        if created:
            human_delay(2.0, 3.0)
        else:
            log_fn("[WARNING] Could not find link, trying direct URL")
            await page.goto("https://account.jagex.com/en-GB/login/registration-start", wait_until="domcontentloaded")
            human_delay(2.0, 3.0)

        # Step 6: Fill email
        log_fn("[INFO] Step 6: Filling email...")
        email_selectors = [
            "input[name='email']", "input[type='email']",
            "input[placeholder*='email' i]", "#email",
        ]
        email_filled = False
        for sel in email_selectors:
            try:
                await page.wait_for_selector(sel, timeout=8000, state="visible")
                await human_type(page, sel, generated_email)
                log_fn(f"[INFO] Email filled with: {sel}")
                email_filled = True
                break
            except Exception:
                continue

        if not email_filled:
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message="Could not find or fill the email field",
                expected_ip=expected_ip, actual_ip=actual_ip,
            )

        # Step 7: Fill DOB
        log_fn("[INFO] Step 7: Filling DOB...")
        dob_fields = [
            ("input[placeholder='DD']", dob["day"]),
            ("input[placeholder='MM']", dob["month"]),
            ("input[placeholder='YYYY']", dob["year"]),
        ]
        for sel, value in dob_fields:
            try:
                await page.wait_for_selector(sel, timeout=5000, state="visible")
                await human_type(page, sel, value, min_delay=30, max_delay=100)
                log_fn(f"[INFO] DOB field '{sel}' filled with '{value}'")
            except Exception as e:
                log_fn(f"[WARNING] Could not fill DOB field {sel}: {e}")

        human_delay(0.5, 1.0)

        # Step 8: Accept terms
        log_fn("[INFO] Step 8: Accepting terms...")
        terms_selectors = [
            "input[type='checkbox']", "label[for*='terms']",
            "label[for*='agree']", "text=I agree",
        ]
        await click_first_match(page, terms_selectors, timeout=3000, label="Terms accepted", log_fn=log_fn)
        human_delay(0.5, 1.0)

        # Step 9: Click Continue
        log_fn("[INFO] Step 9: Clicking Continue...")
        continue_selectors = [
            "button[type='submit']", "text=Continue",
            "button.submit", "input[type='submit']",
        ]
        await click_first_match(page, continue_selectors, timeout=5000, label="Continue clicked", log_fn=log_fn)
        human_delay(3.0, 5.0)

        # Step 10: Email verification
        log_fn("[INFO] Step 10: Email verification...")
        if imap_host and imap_user and imap_pass:
            code = fetch_verification_code(
                imap_host, imap_user, imap_pass,
                generated_email, timeout=120, log_fn=log_fn,
            )
            if code:
                code_selectors = [
                    "input[name='code']", "input[type='text']",
                    "input[placeholder*='code' i]", "#code",
                ]
                for sel in code_selectors:
                    try:
                        await page.wait_for_selector(sel, timeout=10000, state="visible")
                        await human_type(page, sel, code, min_delay=50, max_delay=150)
                        log_fn(f"[INFO] Code entered with: {sel}")
                        human_delay(0.5, 1.0)
                        await click_first_match(page, [
                            "button[type='submit']", "text=Continue",
                            "text=Submit", "text=Verify",
                        ], timeout=5000, label="Verification submitted", log_fn=log_fn)
                        human_delay(3.0, 5.0)
                        break
                    except Exception:
                        continue
            else:
                log_fn("[WARNING] Could not fetch verification code")
        else:
            log_fn("[WARNING] IMAP not configured, skipping verification")

        # Step 11: Display name
        log_fn("[INFO] Step 11: Setting display name...")
        name_selectors = [
            "input[name='displayName']", "input[name='display_name']",
            "input[name='username']", "input[placeholder*='name' i]",
        ]
        for sel in name_selectors:
            try:
                await page.wait_for_selector(sel, timeout=10000, state="visible")
                await human_type(page, sel, account_name)
                log_fn(f"[INFO] Display name entered with: {sel}")
                human_delay(0.5, 1.0)
                await click_first_match(page, [
                    "button[type='submit']", "text=Continue",
                    "text=Set", "text=Next",
                ], timeout=5000, label="Display name submitted", log_fn=log_fn)
                human_delay(3.0, 5.0)
                break
            except Exception:
                continue

        # Step 12: Set password
        log_fn("[INFO] Step 12: Setting password...")
        pwd_selectors = [
            "input[name='password']", "input[type='password']", "#password",
        ]
        for sel in pwd_selectors:
            try:
                await page.wait_for_selector(sel, timeout=10000, state="visible")
                await human_type(page, sel, generated_password, min_delay=30, max_delay=100)
                log_fn(f"[INFO] Password entered with: {sel}")

                # Try confirm password
                confirm_selectors = [
                    "input[name='confirmPassword']", "input[name='confirm_password']",
                    "input[name='passwordConfirm']", "input[placeholder*='confirm' i]",
                ]
                for csec in confirm_selectors:
                    try:
                        await page.wait_for_selector(csec, timeout=5000, state="visible")
                        await human_type(page, csec, generated_password, min_delay=30, max_delay=100)
                        log_fn(f"[INFO] Confirm password entered with: {csec}")
                        break
                    except Exception:
                        continue

                human_delay(0.5, 1.0)
                await click_first_match(page, [
                    "button[type='submit']", "text=Continue",
                    "text=Set", "text=Submit",
                ], timeout=5000, label="Password submitted", log_fn=log_fn)
                human_delay(3.0, 5.0)
                break
            except Exception:
                continue

        # Step 13: Confirmation
        log_fn("[INFO] Step 13: Checking for confirmation...")
        human_delay(2.0, 3.0)
        confirmed = False
        try:
            content = (await page.content()).lower()
            success_indicators = [
                "congratulations", "account created", "welcome",
                "success", "your account", "account is ready",
            ]
            confirmed = any(kw in content for kw in success_indicators)
        except Exception:
            pass

        dob_str = f"{dob['day']}/{dob['month']}/{dob['year']}"
        log_fn("[INFO] Account creation flow completed")
        return AutomationResult(
            status=AutomationStatus.ACCOUNT_CREATED.value,
            message="Account creation completed",
            expected_ip=expected_ip,
            actual_ip=actual_ip,
            data={
                "email": generated_email,
                "password": generated_password,
                "accountName": account_name,
                "dob": dob_str,
                "confirmed": confirmed,
            },
        )

    except Exception as e:
        return AutomationResult(
            status=AutomationStatus.BROWSER_ERROR.value,
            message=f"Account creation failed: {type(e).__name__}: {e}",
            expected_ip=expected_ip,
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
```

**Step 2: Verify import works**

Run: `cd scripts && python -c "from automation.commands.create_account import create_account; print('OK')"`
Expected: `OK`

**Step 3: Commit**

```bash
git add scripts/automation/commands/create_account.py
git commit -m "feat(scripts): add account creation command with Patchright"
```

---

### Task 8: Create commands/session.py

**Files:**
- Create: `scripts/automation/commands/session.py`

**Step 1: Write session.py**

Port the browser session command — launches proxy browser, validates IP, navigates to Jagex, blocks until user closes.

```python
# scripts/automation/commands/session.py
import asyncio
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

    err, cleaned_proxy = preflight_proxy(proxy_url, expected_ip, log_fn)
    if err:
        return err

    pw = browser = None
    try:
        pw, browser, context, page = await launch_browser(
            proxy_url=cleaned_proxy,
            headless=False,  # Always headed for sessions
        )
        log_fn("[INFO] Browser started for session")

        # Validate proxy IP
        log_fn("[INFO] Validating proxy IP...")
        actual_ip = None
        for i, url in enumerate(IP_CHECK_URLS):
            try:
                await page.goto(url, wait_until="domcontentloaded")
                human_delay(0.5, 1.0)
                body = await page.text_content("body") or ""
                actual_ip = extract_ip_from_response(body)
                if actual_ip:
                    log_fn(f"[INFO] Got IP: {actual_ip}")
                    break
            except Exception as e:
                log_fn(f"[WARNING] IP check failed: {e}")

        if actual_ip:
            ip_matches = (expected_ip in actual_ip) or (actual_ip in expected_ip)
            if ip_matches:
                log_fn(f"[INFO] Proxy IP validated: {actual_ip}")
            else:
                log_fn(f"[WARNING] IP mismatch: expected {expected_ip}, got {actual_ip}")

        # Navigate to Jagex
        log_fn("[INFO] Navigating to account.jagex.com...")
        await page.goto("https://account.jagex.com/", wait_until="domcontentloaded")
        human_delay(2.0, 3.0)

        log_fn("[INFO] Browser is ready. Close the browser window when done.")

        # Block until browser is closed by user
        try:
            while True:
                await asyncio.sleep(2)
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
        return AutomationResult(
            status=AutomationStatus.BROWSER_ERROR.value,
            message=f"Session launch failed: {type(e).__name__}: {e}",
            expected_ip=expected_ip,
        )
    finally:
        if browser and pw:
            await close_browser(pw, browser)
```

**Step 2: Verify import works**

Run: `cd scripts && python -c "from automation.commands.session import launch_session; print('OK')"`
Expected: `OK`

**Step 3: Commit**

```bash
git add scripts/automation/commands/session.py
git commit -m "feat(scripts): add browser session command"
```

---

## Phase 4: Entry Point & Dart Integration

### Task 9: Rewrite account_automation.py entry point

**Files:**
- Rename: `scripts/account_automation.py` → `scripts/account_automation_legacy.py`
- Create: `scripts/account_automation.py`

**Step 1: Rename legacy script**

```bash
cd scripts && mv account_automation.py account_automation_legacy.py
```

**Step 2: Write new entry point**

Same CLI interface, same `=== RESULT ===` protocol. Bridges async with `asyncio.run()`.

```python
#!/usr/bin/env python
"""
Account Automation - Patchright Edition
========================================
Proxy validation, account creation, and browser sessions
using Patchright (patched Playwright) for stealth automation.

CLI interface is identical to the SeleniumBase version.
Results communicated via stdout JSON after === RESULT === marker.
"""
import sys
import json
import signal
import asyncio
import argparse

from automation.models import AutomationResult, AutomationStatus


def signal_handler(signum, frame):
    print("\n=== RESULT ===")
    print(json.dumps({"status": "unknown_error", "message": "Script terminated by signal"}))
    sys.exit(1)


signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# Verify patchright is installed
try:
    import patchright  # noqa: F401
except ImportError as e:
    print(f"[ERROR] Failed to import patchright: {e}")
    print("\n=== RESULT ===")
    print(json.dumps({
        "status": "browser_error",
        "message": f"Failed to import patchright: {e}. Please run: pip install patchright",
    }))
    sys.exit(1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Account automation with proxy validation")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_p = subparsers.add_parser("validate", help="Validate proxy IP address")
    validate_p.add_argument("proxy_url", help="Proxy URL (user:pass@host:port)")
    validate_p.add_argument("expected_ip", help="Expected IP address")
    validate_p.add_argument("--headless", action="store_true")
    validate_p.add_argument("--debug", action="store_true")

    create_p = subparsers.add_parser("create-account", help="Create a new Jagex account")
    create_p.add_argument("proxy_url", help="Proxy URL (user:pass@host:port)")
    create_p.add_argument("expected_ip", help="Expected IP address")
    create_p.add_argument("--headless", action="store_true")
    create_p.add_argument("--debug", action="store_true")
    create_p.add_argument("--imap-host", help="IMAP server hostname")
    create_p.add_argument("--imap-user", help="IMAP username/email")
    create_p.add_argument("--imap-pass", help="IMAP password")

    session_p = subparsers.add_parser("session", help="Open browser session with proxy")
    session_p.add_argument("proxy_url", help="Proxy URL (user:pass@host:port)")
    session_p.add_argument("expected_ip", help="Expected IP address")
    session_p.add_argument("--keep-open", action="store_true")
    session_p.add_argument("--debug", action="store_true")

    return parser


async def run(args) -> AutomationResult:
    if args.command == "validate":
        from automation.commands.validate import validate_proxy_ip
        return await validate_proxy_ip(
            proxy_url=args.proxy_url,
            expected_ip=args.expected_ip,
            headless=getattr(args, "headless", False),
            debug=getattr(args, "debug", False),
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
        )
    elif args.command == "session":
        from automation.commands.session import launch_session
        return await launch_session(
            proxy_url=args.proxy_url,
            expected_ip=args.expected_ip,
            keep_open=getattr(args, "keep_open", False),
            debug=getattr(args, "debug", False),
        )
    else:
        return AutomationResult(
            status=AutomationStatus.UNKNOWN_ERROR.value,
            message=f"Unknown command: {args.command}",
        )


def main():
    parser = build_parser()
    args = parser.parse_args()

    result = asyncio.run(run(args))

    print("\n=== RESULT ===", flush=True)
    print(result.to_json(), flush=True)

    success_statuses = [AutomationStatus.SUCCESS.value, AutomationStatus.ACCOUNT_CREATED.value]
    sys.exit(0 if result.status in success_statuses else 1)


if __name__ == "__main__":
    main()
```

**Step 3: Verify CLI works**

Run: `cd scripts && python account_automation.py --help`
Expected: Shows usage with validate, create-account, session subcommands

Run: `cd scripts && python account_automation.py validate --help`
Expected: Shows validate subcommand options

**Step 4: Commit**

```bash
git add scripts/account_automation_legacy.py scripts/account_automation.py
git commit -m "feat(scripts): rewrite entry point for Patchright"
```

---

### Task 10: Update PythonSetupService

**Files:**
- Modify: `lib/config/services/python_setup_service.dart`

**Step 1: Update installChromiumDriver**

Change from `sbase install chromedriver` to `patchright install chromium`:

Replace `installChromiumDriver()` method body:

```dart
Future<bool> installChromiumDriver() async {
  try {
    logger.i('Installing Chromium via patchright...');

    final result = await Process.run(
      'python',
      ['-m', 'patchright', 'install', 'chromium'],
      workingDirectory: _scriptsPath,
    );

    if (result.exitCode == 0) {
      logger.i('Patchright Chromium installed successfully');
      isChromiumInstalled.value = true;
      return await _verifyChromiumWorks();
    } else {
      logger.w('Patchright Chromium install returned: ${result.stderr}');
      return await _verifyChromiumWorks();
    }
  } catch (e) {
    logger.w('Error installing Patchright Chromium: $e');
    return false;
  }
}
```

**Step 2: Update _verifyChromiumWorks**

Change the verification script from SeleniumBase to Patchright:

```dart
Future<bool> _verifyChromiumWorks() async {
  try {
    logger.i('Opening browser to verify Patchright installation...');
    final result = await Process.run(
      'python',
      [
        '-c',
        '''
import asyncio
from patchright.async_api import async_playwright

async def verify():
    pw = await async_playwright().start()
    browser = await pw.chromium.launch(headless=True)
    page = await browser.new_page()
    await page.goto("about:blank")
    print("CHROMIUM_OK")
    await browser.close()
    await pw.stop()

asyncio.run(verify())
'''
      ],
      workingDirectory: _scriptsPath,
    ).timeout(const Duration(seconds: 60));

    final output = result.stdout.toString();
    if (output.contains('CHROMIUM_OK')) {
      logger.i('Patchright Chromium verification successful');
      isChromiumInstalled.value = true;
      return true;
    }
    logger.w('Chromium verification failed: $output');
    return false;
  } catch (e) {
    logger.w('Chromium verification error: $e');
    return false;
  }
}
```

**Step 3: Update checkDependenciesInstalled**

Change the import check from seleniumbase to patchright:

```dart
Future<bool> checkDependenciesInstalled() async {
  try {
    final result = await Process.run(
      'python',
      ['-c', 'import patchright; print("OK")'],
    );

    if (result.exitCode == 0 &&
        result.stdout.toString().trim().contains('OK')) {
      logger.i('Python dependencies already installed');
      isSetupComplete.value = true;
      return true;
    }
  } catch (e) {
    logger.w('Dependencies check failed: $e');
  }
  return false;
}
```

**Step 4: Verify the Dart file compiles**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter analyze lib/config/services/python_setup_service.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/config/services/python_setup_service.dart
git commit -m "feat: update PythonSetupService for Patchright"
```

---

## Phase 5: Integration Testing

### Task 11: End-to-end validate command test

**Step 1: Install Patchright**

Run: `cd scripts && pip install patchright && patchright install chromium`
Expected: Successful install + Chromium download

**Step 2: Test validate command with a known proxy**

Run (with a real proxy): `cd scripts && python account_automation.py validate "<proxy>" "<expected_ip>" --debug`
Expected: `=== RESULT ===` with either `success` (IP matches) or `proxy_validation_failed` (IP mismatch). No crashes.

**Step 3: Test validate command without proxy**

Run: `cd scripts && python account_automation.py validate "none" "0.0.0.0" --debug`
Expected: `=== RESULT ===` with result showing your actual IP (won't match 0.0.0.0, so `proxy_validation_failed`)

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix(scripts): resolve integration issues from validate testing"
```

---

### Task 12: End-to-end create-account test

**Step 1: Test account creation with proxy**

Run (with real proxy + IMAP): `cd scripts && python account_automation.py create-account "<proxy>" "<ip>" --debug --imap-host mail.privateemail.com --imap-user "<user>" --imap-pass "<pass>"`

Expected: Browser opens, navigates to Jagex, handles Cloudflare, fills form. Result JSON with `account_created` or `captcha_required`.

**Step 2: Test session command**

Run: `cd scripts && python account_automation.py session "<proxy>" "<ip>" --debug`
Expected: Browser opens, validates IP, navigates to Jagex, stays open until manually closed.

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix(scripts): resolve integration issues from account creation testing"
```

---

### Task 13: Test Dart integration

**Step 1: Run the Flutter app**

Run: `flutter run -d windows`

**Step 2: Test from the UI**

1. Go to Proxies tab, select a slot with a valid IP
2. Click "Validate IP" — should work through Patchright now
3. Try "Create Account" if Turnstile passes
4. Try "Launch Session"

**Step 3: Commit any final fixes**

```bash
git add -A
git commit -m "fix: resolve Dart-Python integration issues"
```

---

## Phase 6: Cleanup

### Task 14: Remove legacy script

**Step 1: Delete the legacy file**

```bash
rm scripts/account_automation_legacy.py
```

**Step 2: Verify everything still works**

Run: `cd scripts && python account_automation.py validate --help`
Expected: Shows help

**Step 3: Final commit**

```bash
git add scripts/account_automation_legacy.py
git commit -m "chore: remove legacy SeleniumBase automation script"
```
