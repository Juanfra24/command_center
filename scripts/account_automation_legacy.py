"""
Account Automation Module
========================
Webshare proxy validation with SeleniumBase (uc=True)

KEY CHANGE:
- Use SeleniumBase `proxy=` for authenticated proxies (user:pass@host:port)
- Do NOT use Chrome --proxy-server with credentials (can trigger ERR_NO_SUPPORTED_PROXIES)
- Keep CDP activation for uc mode
- Add verbose logging + unique profile dir
"""

import sys
import json
import time
import random
import signal
import argparse
import re
import socket
import os
import string
import imaplib
import email
from email.header import decode_header
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, asdict
from enum import Enum

def signal_handler(signum, frame):
    print("\n=== RESULT ===")
    print(json.dumps({"status": "unknown_error", "message": "Script terminated by signal"}))
    sys.exit(1)

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

try:
    from seleniumbase import SB
    import seleniumbase
except ImportError as e:
    print(f"[ERROR] Failed to import seleniumbase: {e}")
    print("\n=== RESULT ===")
    print(json.dumps({
        "status": "browser_error",
        "message": f"Failed to import seleniumbase: {e}. Please run: pip install seleniumbase"
    }))
    sys.exit(1)

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

class AccountAutomation:
    IP_CHECK_URLS = [
        "https://api.ipify.org?format=json",
        "https://httpbin.org/ip",
        "https://api.myip.com",
    ]

    def __init__(self, proxy_url: Optional[str] = None, headless: bool = False, slow_mode: bool = True, debug: bool = False,
                 imap_host: Optional[str] = None, imap_user: Optional[str] = None, imap_pass: Optional[str] = None):
        self.proxy_url_raw = proxy_url
        self.headless = headless
        self.slow_mode = slow_mode
        self.debug = debug
        self.sb = None
        self.imap_host = imap_host
        self.imap_user = imap_user
        self.imap_pass = imap_pass

        self.debug_dir = os.path.join(os.getcwd(), "automation_debug")
        os.makedirs(self.debug_dir, exist_ok=True)

        ts = time.strftime("%Y%m%d_%H%M%S")
        self.profile_dir = os.path.join(self.debug_dir, "profiles", ts)
        os.makedirs(self.profile_dir, exist_ok=True)

    # ---------- logging ----------
    def _log(self, msg: str):
        print(msg, flush=True)

    def _dbg(self, msg: str):
        if self.debug:
            print(msg, flush=True)

    def _mask_proxy(self, proxy: Optional[str]) -> str:
        if not proxy:
            return "None"
        s = proxy
        try:
            s = s.strip().strip("'\"")
            if "@" in s:
                creds, hostport = s.split("@", 1)
                user = creds.split(":", 1)[0]
                return f"{user}:***@{hostport}"
            return s
        except Exception:
            return s

    # ---------- proxy helpers ----------
    def _clean_proxy_for_sbase(self, proxy: Optional[str]) -> Optional[str]:
        """
        SeleniumBase proxy= expects:
          - host:port
          - user:pass@host:port
        WITHOUT scheme.
        """
        if not proxy or proxy.lower() == "none":
            return None
        p = proxy.strip().strip("'\"")
        # remove scheme if present
        p = p.replace("http://", "").replace("https://", "")
        return p

    def _validate_proxy_format_sbase(self, proxy: str) -> Optional[str]:
        if not proxy:
            return None
        # allow socks
        if proxy.startswith(("socks4://", "socks5://")):
            return None
        ok = re.fullmatch(r"([^:@\s]+):(\d+)|([^:@\s]+):([^@\s]+)@([^:@\s]+):(\d+)", proxy)
        if not ok:
            return f"Bad proxy format for SeleniumBase: {proxy}. Use host:port or user:pass@host:port"
        if proxy.count("@") > 1:
            return f"Proxy contains multiple '@': {proxy}. Password likely contains '@' — URL-encode it."
        return None

    def _tcp_ping(self, host: str, port: int, timeout: int = 6) -> (bool, str):
        try:
            sock = socket.create_connection((host, port), timeout=timeout)
            sock.close()
            return True, "TCP connect OK"
        except Exception as e:
            return False, f"TCP connect failed: {e}"

    def _parse_host_port(self, proxy: str) -> Optional[tuple]:
        """
        Extract host/port for TCP ping from either:
          host:port
          user:pass@host:port
        """
        if not proxy:
            return None
        try:
            target = proxy.split("@", 1)[-1]
            host, port_s = target.split(":", 1)
            return host, int(port_s)
        except Exception:
            return None

    # ---------- shared automation helpers ----------
    def _preflight_proxy(self, expected_ip: str) -> Optional[AutomationResult]:
        """Run proxy preflight checks (clean, validate format, TCP ping).
        Returns an error AutomationResult if checks fail, or None on success.
        Sets self._cleaned_proxy as a side-effect."""
        self._cleaned_proxy = self._clean_proxy_for_sbase(self.proxy_url_raw)

        self._log(f"[INFO] Proxy (masked): {self._mask_proxy(self._cleaned_proxy)}")
        self._log(f"[INFO] Expected IP: {expected_ip}")

        if self._cleaned_proxy:
            fmt_err = self._validate_proxy_format_sbase(self._cleaned_proxy)
            if fmt_err:
                return AutomationResult(
                    status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                    message=fmt_err,
                    expected_ip=expected_ip,
                )
            hp = self._parse_host_port(self._cleaned_proxy)
            if hp:
                ok, msg = self._tcp_ping(hp[0], hp[1])
                self._log(f"[INFO] Proxy reachability {hp[0]}:{hp[1]}: {msg}")
                if not ok:
                    return AutomationResult(
                        status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                        message=f"Proxy not reachable: {hp[0]}:{hp[1]}. {msg}",
                        expected_ip=expected_ip,
                    )
        return None

    def _click_first_match(self, sb, selectors: List[str], timeout: int = 5, label: str = "") -> bool:
        """Try clicking each selector in order; return True on first success."""
        for sel in selectors:
            try:
                if sel.startswith("//"):
                    sb.click_xpath(sel, timeout=timeout)
                else:
                    sb.click(sel, timeout=timeout)
                if label:
                    self._log(f"[INFO] {label} with: {sel}")
                return True
            except Exception:
                continue
        return False

    def _human_type(self, sb, selector: str, text: str, min_delay: float = 0.03, max_delay: float = 0.12):
        """Type text character-by-character with human-like delays."""
        for char in text:
            sb.add_text(selector, char)
            time.sleep(random.uniform(min_delay, max_delay))

    # ---------- browser helpers ----------
    def _get_chromium_args_list(self) -> List[str]:
        return [
            "--window-size=1920,1080",
            "--disable-dev-shm-usage",
            "--no-sandbox",
            "--disable-webrtc",
            "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
            "--disable-features=IsolateOrigins,site-per-process",
            f"--user-data-dir={self.profile_dir}",
        ]

    def _human_delay(self, min_sec: float = 0.5, max_sec: float = 2.0):
        if self.slow_mode:
            time.sleep(random.uniform(min_sec, max_sec))

    def _extract_ip_from_response(self, text: str) -> Optional[str]:
        try:
            data = json.loads(text)
            for key in ["ip", "origin", "query"]:
                if key in data:
                    val = data[key]
                    if isinstance(val, str):
                        return val.split(",")[0].strip()
        except Exception:
            pass
        match = re.search(r"\d{1,3}(?:\.\d{1,3}){3}", text)
        if match:
            return match.group()
        return None

    def _read_jsonish_body(self, sb) -> str:
        for sel in ("pre", "body"):
            try:
                txt = sb.get_text(sel).strip()
                if txt:
                    return txt
            except Exception:
                continue
        try:
            return sb.get_page_source()
        except Exception:
            return ""

    # ---------- main ----------
    def validate_proxy_ip(self, expected_ip: str) -> AutomationResult:
        self._log("[INFO] ===== Preflight =====")
        self._log(f"[INFO] Python: {sys.version.replace(os.linesep, ' ')}")
        self._log(f"[INFO] seleniumbase: {getattr(seleniumbase, '__version__', 'unknown')}")
        self._log(f"[INFO] Headless: {self.headless}")
        self._log(f"[INFO] Debug dir: {self.debug_dir}")
        self._log(f"[INFO] Profile dir: {self.profile_dir}")

        preflight_err = self._preflight_proxy(expected_ip)
        if preflight_err:
            return preflight_err
        cleaned_proxy = self._cleaned_proxy

        chromium_args = self._get_chromium_args_list()
        self._dbg("[DEBUG] Chromium args:\n  " + "\n  ".join(chromium_args))

        try:
            with SB(
                uc=True,
                proxy=cleaned_proxy,               # ✅ auth handled by SeleniumBase
                headless=self.headless,
                page_load_strategy="eager",
                chromium_arg=",".join(chromium_args),
                incognito=True,
            ) as sb:
                self.sb = sb
                self._log("[INFO] Browser started successfully")

                # For uc=True, CDP helps stability
                try:
                    sb.activate_cdp_mode(self.IP_CHECK_URLS[0])
                except Exception as e:
                    self._dbg(f"[DEBUG] CDP activation failed (not fatal): {e}")

                actual_ip = None
                last_error = None

                for i, url in enumerate(self.IP_CHECK_URLS):
                    try:
                        self._log(f"[INFO] IP check {i+1}/{len(self.IP_CHECK_URLS)}: {url}")
                        sb.open(url)
                        self._human_delay(0.3, 0.8)

                        body = self._read_jsonish_body(sb)
                        self._dbg(f"[DEBUG] Body first 200: {body[:200]!r}")

                        actual_ip = self._extract_ip_from_response(body)
                        if actual_ip:
                            self._log(f"[INFO] Got IP: {actual_ip}")
                            break
                    except Exception as e:
                        last_error = f"{type(e).__name__}: {e}"
                        self._log(f"[WARNING] IP check failed: {last_error}")

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
            err = f"{type(e).__name__}: {e}"
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message=f"Browser startup failed: {err}",
                expected_ip=expected_ip,
            )

    # ---------- IMAP email verification ----------
    def _fetch_verification_code(self, imap_host: str, imap_user: str, imap_pass: str,
                                  target_email: str, timeout: int = 120) -> Optional[str]:
        """Fetch the 6-digit verification code from Jagex email via IMAP.
        Keeps a single IMAP connection open across poll iterations to avoid
        repeated TLS handshakes + auth cycles."""
        self._log(f"[INFO] Checking IMAP for verification code (target: {target_email})...")
        start_time = time.time()
        mail = None

        try:
            while time.time() - start_time < timeout:
                # Connect/reconnect only when needed
                if mail is None:
                    try:
                        mail = imaplib.IMAP4_SSL(imap_host, 993)
                        mail.login(imap_user, imap_pass)
                        self._dbg("[DEBUG] IMAP connected")
                    except Exception as e:
                        self._log(f"[WARNING] IMAP connect error: {e}")
                        mail = None
                        time.sleep(5)
                        continue

                try:
                    mail.select("INBOX")

                    # Search for recent emails from Jagex
                    _, messages = mail.search(None, '(FROM "jagex" UNSEEN)')
                    if not messages[0]:
                        _, messages = mail.search(None, '(FROM "jagex.com")')

                    email_ids = messages[0].split()
                    for eid in reversed(email_ids[-10:]):
                        _, msg_data = mail.fetch(eid, "(RFC822)")
                        msg = email.message_from_bytes(msg_data[0][1])

                        to_header = msg.get("To", "").lower()
                        subject = msg.get("Subject", "")
                        if target_email.lower() not in to_header and target_email.split("@")[0] not in to_header:
                            continue

                        self._log(f"[INFO] Found Jagex email: {subject}")

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

                        code_match = re.search(r'\b(\d{6})\b', body)
                        if code_match:
                            code = code_match.group(1)
                            self._log(f"[INFO] Found verification code: {code}")
                            return code

                except Exception as e:
                    self._log(f"[WARNING] IMAP poll error: {e}")
                    # Connection likely stale, force reconnect next iteration
                    try:
                        mail.logout()
                    except Exception:
                        pass
                    mail = None
                    time.sleep(5)
                    continue

                self._log(f"[INFO] No code yet, retrying in 5s... ({int(time.time() - start_time)}s elapsed)")
                time.sleep(5)

        finally:
            if mail is not None:
                try:
                    mail.logout()
                except Exception:
                    pass

        self._log("[WARNING] Timed out waiting for verification code")
        return None

    # ---------- name & password generation ----------
    def _generate_account_name(self) -> str:
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

    def _generate_email(self, account_name: str) -> str:
        """Derive email from account name: e.g., swiftarcher42@onemanco.org"""
        clean = re.sub(r'[^a-zA-Z0-9]', '', account_name).lower()
        return f"{clean}@onemanco.org"

    def _generate_password(self) -> str:
        """Generate a strong password meeting Jagex requirements (12-16 chars)."""
        length = random.randint(12, 16)
        # Ensure at least one of each required type
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
        return ''.join(chars)

    def _generate_random_dob(self) -> dict:
        """Generate a random date of birth (18-35 years old)"""
        # Pick a year between 1991 and 2008 (18-35 years old from 2026)
        year = random.randint(1991, 2008)
        month = random.randint(1, 12)
        # Keep day safe for all months
        day = random.randint(1, 28)
        return {"day": str(day), "month": str(month), "year": str(year)}

    # ---------- captcha helpers ----------
    def _is_past_cloudflare(self, sb) -> bool:
        """Check if we've passed the Cloudflare challenge and reached the actual Jagex page."""
        try:
            # Quick check: CF challenge has title "Just a moment..."
            title = sb.get_title().lower()
            if 'just a moment' in title:
                self._dbg(f"[DEBUG] Still on CF challenge (title: {title})")
                return False

            page_source = sb.get_page_source().lower()
            # The CF challenge page shows "Are you a robot?" / "Verify you are human"
            cf_indicators = ['are you a robot', 'verify you are human', 'checking your browser']
            if any(kw in page_source for kw in cf_indicators):
                self._dbg("[DEBUG] Still on CF challenge (page content)")
                return False

            # The actual Jagex page will have login/registration content
            jagex_indicators = [
                'create an account',
                'registration',
                'log in',
                'jagex account',
                'id="email"',
            ]
            passed = any(kw in page_source for kw in jagex_indicators)
            if passed:
                self._dbg("[DEBUG] Jagex page content detected - past CF")
            return passed
        except Exception as e:
            self._dbg(f"[DEBUG] _is_past_cloudflare error: {e}")
            return False

    def _bring_browser_to_front(self, sb):
        """Bring the Chrome browser window to the foreground on Windows.
        This is critical when running as a subprocess — PyAutoGUI clicks
        at screen coordinates, so Chrome MUST be the active window."""
        try:
            # SeleniumBase has a built-in method
            sb.bring_to_front()
            self._dbg("[DEBUG] bring_to_front() called")
            time.sleep(0.5)
        except Exception as e:
            self._dbg(f"[DEBUG] bring_to_front() failed: {e}")
            # Fallback: use Windows API directly via ctypes
            try:
                import ctypes
                # Find the Chrome window handle using its title
                hwnd = ctypes.windll.user32.FindWindowW(None, sb.get_title())
                if hwnd:
                    ctypes.windll.user32.SetForegroundWindow(hwnd)
                    ctypes.windll.user32.BringWindowToTop(hwnd)
                    self._dbg(f"[DEBUG] Windows API SetForegroundWindow hwnd={hwnd}")
                    time.sleep(0.5)
                else:
                    self._dbg("[DEBUG] Could not find Chrome window handle")
            except Exception as e2:
                self._dbg(f"[DEBUG] Windows API fallback failed: {e2}")

    # ---------- account creation ----------
    def create_account(self, expected_ip: str) -> AutomationResult:
        """Navigate to Jagex account creation and register a new account.

        Steps:
        1. Validate proxy IP (using regular open, NOT CDP mode)
        2. Navigate to https://account.jagex.com/ with UC reconnect
        3. Wait for and handle Cloudflare Turnstile captcha
        4. Handle cookie consent popup
        5. Click 'Create an account'
        6. Fill in random email @onemanco.org
        7. Fill in random date of birth
        8. Accept terms and conditions
        9. Click Continue
        """
        self._log("[INFO] ===== Account Creation Preflight =====")

        preflight_err = self._preflight_proxy(expected_ip)
        if preflight_err:
            return preflight_err
        cleaned_proxy = self._cleaned_proxy

        chromium_args = self._get_chromium_args_list()
        account_name = self._generate_account_name()
        generated_email = self._generate_email(account_name)
        generated_password = self._generate_password()
        dob = self._generate_random_dob()
        self._log(f"[INFO] Generated account name: {account_name}")
        self._log(f"[INFO] Generated email: {generated_email}")
        self._log(f"[INFO] Generated DOB: {dob['day']}/{dob['month']}/{dob['year']}")

        try:
            with SB(
                uc=True,
                proxy=cleaned_proxy,
                headless=self.headless,
                page_load_strategy="eager",
                chromium_arg=",".join(chromium_args),
                incognito=True,
            ) as sb:
                self.sb = sb
                self._log("[INFO] Browser started for account creation")

                # --- Step 1: Validate proxy IP ---
                # IMPORTANT: Do NOT use activate_cdp_mode() here.
                # CDP mode conflicts with uc_gui_click_captcha() which uses
                # GUI-level automation. Use regular sb.open() for IP checks.
                self._log("[INFO] Step 1: Validating proxy IP...")
                actual_ip = None
                for i, url in enumerate(self.IP_CHECK_URLS):
                    try:
                        self._log(f"[INFO] IP check {i+1}/{len(self.IP_CHECK_URLS)}: {url}")
                        sb.open(url)
                        self._human_delay(1.0, 2.0)
                        body = self._read_jsonish_body(sb)
                        actual_ip = self._extract_ip_from_response(body)
                        if actual_ip:
                            self._log(f"[INFO] Got IP: {actual_ip}")
                            break
                    except Exception as e:
                        self._log(f"[WARNING] IP check failed: {e}")

                if not actual_ip:
                    return AutomationResult(
                        status=AutomationStatus.BROWSER_ERROR.value,
                        message="Could not determine current IP for validation",
                        expected_ip=expected_ip,
                    )

                ip_matches = (expected_ip in actual_ip) or (actual_ip in expected_ip)
                if not ip_matches:
                    return AutomationResult(
                        status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                        message=f"IP mismatch: expected {expected_ip}, got {actual_ip}",
                        expected_ip=expected_ip,
                        actual_ip=actual_ip,
                    )
                self._log(f"[INFO] Proxy IP validated: {actual_ip}")

                # --- Step 2: Navigate to Jagex account page ---
                # uc_open_with_reconnect disconnects the driver before loading
                # (so Cloudflare can't detect automation), waits reconnect_time
                # seconds for the page + captcha to fully render, then reconnects.
                self._log("[INFO] Step 2: Navigating to account.jagex.com...")
                sb.uc_open_with_reconnect("https://account.jagex.com/", reconnect_time=14)
                self._human_delay(2.0, 3.0)

                # --- Step 3: Handle Cloudflare captcha ---
                # The CF challenge page shows "Are you a robot?" with a
                # "Verify you are human" checkbox. uc_gui_click_captcha()
                # uses PyAutoGUI to click at screen coordinates, so Chrome
                # MUST be the foreground window.
                self._log("[INFO] Step 3: Handling Cloudflare captcha...")
                captcha_passed = False
                max_captcha_attempts = 5

                for attempt in range(1, max_captcha_attempts + 1):
                    self._log(f"[INFO] Captcha attempt {attempt}/{max_captcha_attempts}")

                    # Check if we're already past Cloudflare
                    if self._is_past_cloudflare(sb):
                        self._log("[INFO] Already past Cloudflare")
                        captcha_passed = True
                        break

                    # Bring Chrome to foreground before GUI click
                    self._log("[INFO] Bringing browser to foreground...")
                    self._bring_browser_to_front(sb)

                    # Give a moment for the captcha widget to fully render
                    self._human_delay(1.0, 2.0)

                    # Try clicking the captcha
                    try:
                        self._log("[INFO] Clicking captcha with uc_gui_click_captcha()...")
                        sb.uc_gui_click_captcha()
                        self._log("[INFO] Captcha click executed")
                    except Exception as e:
                        self._log(f"[WARNING] uc_gui_click_captcha failed: {type(e).__name__}: {e}")
                        # Fallback: try uc_gui_handle_captcha which is more robust
                        try:
                            self._log("[INFO] Trying uc_gui_handle_captcha() fallback...")
                            sb.uc_gui_handle_captcha()
                            self._log("[INFO] uc_gui_handle_captcha executed")
                        except Exception as e2:
                            self._log(f"[WARNING] uc_gui_handle_captcha also failed: {type(e2).__name__}: {e2}")

                    # Wait for CF to verify (the spinner animation)
                    self._log("[INFO] Waiting for captcha verification...")
                    self._human_delay(5.0, 8.0)

                    # Check if we passed
                    if self._is_past_cloudflare(sb):
                        self._log("[INFO] Captcha solved successfully!")
                        captcha_passed = True
                        break

                    self._log("[INFO] Still on challenge page, retrying...")

                    # On retries, reload the page with reconnect
                    if attempt < max_captcha_attempts:
                        self._log("[INFO] Reloading with uc_open_with_reconnect...")
                        try:
                            sb.uc_open_with_reconnect(
                                "https://account.jagex.com/",
                                reconnect_time=14
                            )
                            self._human_delay(3.0, 5.0)
                        except Exception as e:
                            self._dbg(f"[DEBUG] Reconnect error: {e}")

                if not captcha_passed:
                    return AutomationResult(
                        status=AutomationStatus.CAPTCHA_REQUIRED.value,
                        message="Could not pass Cloudflare captcha after all attempts",
                        expected_ip=expected_ip,
                        actual_ip=actual_ip,
                    )

                # --- Step 4: Handle cookie consent popup ---
                self._log("[INFO] Step 4: Handling cookie consent...")
                cookie_handled = False
                cookie_selectors = [
                    "#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll",
                    "button#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll",
                    "#CybotCookiebotDialogBodyButtonDecline",
                    "button#CybotCookiebotDialogBodyButtonDecline",
                    "a#CybotCookiebotDialogBodyButtonDecline",
                    "//button[contains(text(), 'Use necessary cookies only')]",
                    "//button[contains(text(), 'Allow all cookies')]",
                    "//button[contains(text(), 'necessary')]",
                    "//a[contains(text(), 'necessary')]",
                ]
                cookie_handled = self._click_first_match(sb, cookie_selectors, timeout=3, label="Cookie consent handled")
                if cookie_handled:
                    self._human_delay(1.0, 2.0)

                if not cookie_handled:
                    self._log("[INFO] No cookie popup found or already dismissed")

                self._human_delay(1.0, 2.0)

                # --- Step 5: Click 'Create an account' link ---
                self._log("[INFO] Step 5: Clicking 'Create an account'...")
                create_selectors = [
                    "a[href*='registration']",
                    "//a[contains(text(), 'Create an account')]",
                    "//a[contains(text(), 'Create a')]",
                    "//a[contains(text(), 'create an account')]",
                    "a.create-account-link",
                    "//a[contains(@href, 'registration')]",
                ]
                create_account_clicked = self._click_first_match(sb, create_selectors, timeout=5, label="Clicked create account")
                if create_account_clicked:
                    self._human_delay(2.0, 3.0)

                if not create_account_clicked:
                    self._log("[WARNING] Could not find 'Create an account' link, trying direct URL")
                    sb.open("https://account.jagex.com/en-GB/login/registration-start")
                    self._human_delay(2.0, 3.0)

                # --- Step 6: Fill in email ---
                self._log("[INFO] Step 6: Filling in email...")
                email_selectors = [
                    "input[name='email']",
                    "input[type='email']",
                    "input[placeholder*='email' i]",
                    "input[placeholder*='Email']",
                    "#email",
                ]
                email_filled = False
                for sel in email_selectors:
                    try:
                        sb.wait_for_element_visible(sel, timeout=8)
                        sb.click(sel)
                        self._human_delay(0.3, 0.6)
                        self._human_type(sb, sel, generated_email)
                        self._log(f"[INFO] Email filled with selector: {sel}")
                        email_filled = True
                        break
                    except Exception:
                        continue

                if not email_filled:
                    return AutomationResult(
                        status=AutomationStatus.BROWSER_ERROR.value,
                        message="Could not find or fill the email field",
                        expected_ip=expected_ip,
                        actual_ip=actual_ip,
                    )

                self._human_delay(0.5, 1.0)

                # --- Step 7: Fill in date of birth ---
                self._log("[INFO] Step 7: Filling in date of birth...")
                dob_fields = [
                    ("input[placeholder='DD']", dob["day"]),
                    ("input[placeholder='MM']", dob["month"]),
                    ("input[placeholder='YYYY']", dob["year"]),
                ]
                dob_filled = True
                for sel, value in dob_fields:
                    try:
                        sb.wait_for_element_visible(sel, timeout=5)
                        sb.click(sel)
                        self._human_delay(0.2, 0.4)
                        self._human_type(sb, sel, value, min_delay=0.03, max_delay=0.1)
                        self._log(f"[INFO] DOB field '{sel}' filled with '{value}'")
                    except Exception as e:
                        self._log(f"[WARNING] Could not fill DOB field {sel}: {e}")
                        dob_filled = False

                if not dob_filled:
                    self._log("[WARNING] Some DOB fields could not be filled")

                self._human_delay(0.5, 1.0)

                # --- Step 8: Accept terms and conditions ---
                self._log("[INFO] Step 8: Accepting terms and conditions...")
                terms_selectors = [
                    "input[type='checkbox']",
                    "label[for*='terms']",
                    "label[for*='agree']",
                    "//label[contains(text(), 'I agree')]",
                    "//span[contains(text(), 'I agree')]",
                    ".checkbox",
                ]
                terms_accepted = self._click_first_match(sb, terms_selectors, timeout=3, label="Terms accepted")

                if not terms_accepted:
                    self._log("[WARNING] Could not find terms checkbox")

                self._human_delay(0.5, 1.0)

                # --- Step 9: Click Continue ---
                self._log("[INFO] Step 9: Clicking Continue...")
                continue_selectors = [
                    "button[type='submit']",
                    "//button[contains(text(), 'Continue')]",
                    "//button[contains(text(), 'continue')]",
                    "button.submit",
                    "input[type='submit']",
                ]
                continue_clicked = self._click_first_match(sb, continue_selectors, timeout=5, label="Continue clicked")

                if not continue_clicked:
                    self._log("[WARNING] Could not click Continue button")

                self._human_delay(3.0, 5.0)

                # --- Step 10: Email verification ---
                self._log("[INFO] Step 10: Email verification...")
                if self.imap_host and self.imap_user and self.imap_pass:
                    verification_code = self._fetch_verification_code(
                        self.imap_host, self.imap_user, self.imap_pass,
                        generated_email, timeout=120
                    )
                    if verification_code:
                        # Enter the verification code
                        code_selectors = [
                            "input[name='code']",
                            "input[type='text']",
                            "input[placeholder*='code' i]",
                            "input[placeholder*='Code']",
                            "input[aria-label*='code' i]",
                            "#code",
                        ]
                        code_entered = False
                        for sel in code_selectors:
                            try:
                                sb.wait_for_element_visible(sel, timeout=10)
                                sb.click(sel)
                                self._human_delay(0.3, 0.6)
                                self._human_type(sb, sel, verification_code, min_delay=0.05, max_delay=0.15)
                                self._log(f"[INFO] Verification code entered with selector: {sel}")
                                code_entered = True
                                break
                            except Exception:
                                continue

                        if not code_entered:
                            self._log("[WARNING] Could not find verification code input")
                        else:
                            self._human_delay(0.5, 1.0)
                            # Submit verification code
                            self._click_first_match(sb, [
                                "button[type='submit']", "//button[contains(text(), 'Continue')]",
                                "//button[contains(text(), 'Submit')]", "//button[contains(text(), 'Verify')]",
                            ], timeout=5, label="Verification submitted")
                            self._human_delay(3.0, 5.0)
                    else:
                        self._log("[WARNING] Could not fetch verification code from email")
                else:
                    self._log("[WARNING] IMAP credentials not provided, skipping email verification")

                # --- Step 11: Choose display name ---
                self._log("[INFO] Step 11: Setting display name...")
                name_selectors = [
                    "input[name='displayName']",
                    "input[name='display_name']",
                    "input[name='username']",
                    "input[placeholder*='name' i]",
                    "input[placeholder*='display' i]",
                    "input[type='text']",
                ]
                name_entered = False
                for sel in name_selectors:
                    try:
                        sb.wait_for_element_visible(sel, timeout=10)
                        sb.click(sel)
                        self._human_delay(0.3, 0.6)
                        self._human_type(sb, sel, account_name)
                        self._log(f"[INFO] Display name entered with selector: {sel}")
                        name_entered = True
                        break
                    except Exception:
                        continue

                if name_entered:
                    self._human_delay(0.5, 1.0)
                    # Submit display name
                    self._click_first_match(sb, [
                        "button[type='submit']", "//button[contains(text(), 'Continue')]",
                        "//button[contains(text(), 'Set')]", "//button[contains(text(), 'Next')]",
                    ], timeout=5, label="Display name submitted")
                    self._human_delay(3.0, 5.0)
                else:
                    self._log("[WARNING] Could not find display name input")

                # --- Step 12: Set password ---
                self._log("[INFO] Step 12: Setting password...")
                password_selectors = [
                    "input[name='password']",
                    "input[type='password']",
                    "#password",
                ]
                password_entered = False
                for sel in password_selectors:
                    try:
                        # There may be two password fields (password + confirm)
                        elements = sb.find_elements(sel)
                        if elements:
                            # First password field
                            sb.wait_for_element_visible(sel, timeout=10)
                            sb.click(sel)
                            self._human_delay(0.3, 0.6)
                            self._human_type(sb, sel, generated_password, min_delay=0.03, max_delay=0.1)
                            self._log(f"[INFO] Password entered with selector: {sel}")
                            password_entered = True

                            # Try confirm password field
                            confirm_selectors = [
                                "input[name='confirmPassword']",
                                "input[name='confirm_password']",
                                "input[name='passwordConfirm']",
                                "input[placeholder*='confirm' i]",
                                "input[placeholder*='Confirm' i]",
                            ]
                            for csec in confirm_selectors:
                                try:
                                    sb.wait_for_element_visible(csec, timeout=5)
                                    sb.click(csec)
                                    self._human_delay(0.3, 0.6)
                                    self._human_type(sb, csec, generated_password, min_delay=0.03, max_delay=0.1)
                                    self._log(f"[INFO] Confirm password entered with: {csec}")
                                    break
                                except Exception:
                                    continue

                            # If there are exactly 2 password fields and no confirm field found
                            if len(elements) >= 2:
                                try:
                                    second = elements[1]
                                    second.click()
                                    self._human_delay(0.3, 0.6)
                                    for char in generated_password:
                                        second.send_keys(char)
                                        time.sleep(random.uniform(0.03, 0.1))
                                    self._log("[INFO] Confirm password entered via second element")
                                except Exception as e:
                                    self._dbg(f"[DEBUG] Second password field: {e}")
                            break
                    except Exception:
                        continue

                if password_entered:
                    self._human_delay(0.5, 1.0)
                    # Submit password
                    self._click_first_match(sb, [
                        "button[type='submit']", "//button[contains(text(), 'Continue')]",
                        "//button[contains(text(), 'Set')]", "//button[contains(text(), 'Submit')]",
                    ], timeout=5, label="Password submitted")
                    self._human_delay(3.0, 5.0)
                else:
                    self._log("[WARNING] Could not find password input")

                # --- Step 13: Confirmation ---
                self._log("[INFO] Step 13: Checking for confirmation...")
                self._human_delay(2.0, 3.0)

                # Check page for success indicators
                try:
                    page_source = sb.get_page_source().lower()
                    success_indicators = ['congratulations', 'account created', 'welcome', 'success',
                                          'your account', 'account is ready']
                    confirmed = any(kw in page_source for kw in success_indicators)
                except Exception:
                    confirmed = False

                dob_str = f"{dob['day']}/{dob['month']}/{dob['year']}"
                self._log("[INFO] Account creation flow completed")
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
            err = f"{type(e).__name__}: {e}"
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message=f"Account creation failed: {err}",
                expected_ip=expected_ip,
            )

    # ---------- browser session ----------
    def launch_session(self, expected_ip: str, keep_open: bool = False) -> AutomationResult:
        """Launch a browser session with the proxy for manual use.
        Validates the proxy IP, navigates to account.jagex.com,
        then keeps Chrome open for the user by blocking until they close it."""
        self._log("[INFO] ===== Browser Session =====")

        preflight_err = self._preflight_proxy(expected_ip)
        if preflight_err:
            return preflight_err
        cleaned_proxy = self._cleaned_proxy

        chromium_args = self._get_chromium_args_list()

        try:
            # Use SB() because it handles proxy auth (user:pass) via a
            # Chrome extension. Driver() does NOT handle auth and shows
            # a "Sign in" prompt instead.
            # We use the context manager but block inside it so Chrome
            # stays alive until the user closes the browser window.
            with SB(
                uc=True,
                proxy=cleaned_proxy,
                headless=False,
                page_load_strategy="eager",
                chromium_arg=",".join(chromium_args),
                incognito=True,
            ) as sb:
                self.sb = sb
                self._log("[INFO] Browser started for session")

                # Validate proxy IP
                self._log("[INFO] Validating proxy IP...")
                actual_ip = None
                for i, url in enumerate(self.IP_CHECK_URLS):
                    try:
                        sb.open(url)
                        self._human_delay(0.5, 1.0)
                        body = self._read_jsonish_body(sb)
                        actual_ip = self._extract_ip_from_response(body)
                        if actual_ip:
                            self._log(f"[INFO] Got IP: {actual_ip}")
                            break
                    except Exception as e:
                        self._log(f"[WARNING] IP check failed: {e}")

                if actual_ip:
                    ip_matches = (expected_ip in actual_ip) or (actual_ip in expected_ip)
                    if ip_matches:
                        self._log(f"[INFO] Proxy IP validated: {actual_ip}")
                    else:
                        self._log(f"[WARNING] IP mismatch: expected {expected_ip}, got {actual_ip}")

                # Navigate to Jagex
                self._log("[INFO] Navigating to account.jagex.com...")
                sb.uc_open_with_reconnect("https://account.jagex.com/", reconnect_time=14)
                self._human_delay(2.0, 3.0)

                self._log("[INFO] Browser is ready. Close the browser window when done.")

                # Block here — keep the SB context alive so Chrome stays open.
                # Poll until the user closes the browser window.
                try:
                    while True:
                        time.sleep(2)
                        try:
                            sb.get_title()
                        except Exception:
                            self._log("[INFO] Browser closed by user")
                            break
                except KeyboardInterrupt:
                    self._log("[INFO] Session ended by signal")

                return AutomationResult(
                    status=AutomationStatus.SUCCESS.value,
                    message="Browser session ended",
                    expected_ip=expected_ip,
                    actual_ip=actual_ip,
                )

        except Exception as e:
            err = f"{type(e).__name__}: {e}"
            return AutomationResult(
                status=AutomationStatus.BROWSER_ERROR.value,
                message=f"Session launch failed: {err}",
                expected_ip=expected_ip,
            )


def main():
    parser = argparse.ArgumentParser(description="Account automation with proxy validation")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate", help="Validate proxy IP address")
    validate_parser.add_argument("proxy_url", help="Proxy URL (host:port or user:pass@host:port)")
    validate_parser.add_argument("expected_ip", help="Expected IP address")
    validate_parser.add_argument("--headless", action="store_true", help="Run in headless mode")
    validate_parser.add_argument("--debug", action="store_true", help="Enable verbose debug logs")

    create_parser = subparsers.add_parser("create-account", help="Create a new Jagex account")
    create_parser.add_argument("proxy_url", help="Proxy URL (host:port or user:pass@host:port)")
    create_parser.add_argument("expected_ip", help="Expected IP address")
    create_parser.add_argument("--headless", action="store_true", help="Run in headless mode")
    create_parser.add_argument("--debug", action="store_true", help="Enable verbose debug logs")
    create_parser.add_argument("--imap-host", help="IMAP server hostname")
    create_parser.add_argument("--imap-user", help="IMAP username/email")
    create_parser.add_argument("--imap-pass", help="IMAP password")

    session_parser = subparsers.add_parser("session", help="Open a browser session with proxy")
    session_parser.add_argument("proxy_url", help="Proxy URL (host:port or user:pass@host:port)")
    session_parser.add_argument("expected_ip", help="Expected IP address")
    session_parser.add_argument("--keep-open", action="store_true", help="Keep browser open after validation")
    session_parser.add_argument("--debug", action="store_true", help="Enable verbose debug logs")

    args = parser.parse_args()

    automation = AccountAutomation(
        proxy_url=args.proxy_url,
        headless=getattr(args, "headless", False),
        debug=getattr(args, "debug", False),
        imap_host=getattr(args, "imap_host", None),
        imap_user=getattr(args, "imap_user", None),
        imap_pass=getattr(args, "imap_pass", None),
    )

    if args.command == "validate":
        result = automation.validate_proxy_ip(args.expected_ip)
    elif args.command == "create-account":
        result = automation.create_account(args.expected_ip)
    elif args.command == "session":
        result = automation.launch_session(args.expected_ip, keep_open=getattr(args, "keep_open", False))
    else:
        result = AutomationResult(
            status=AutomationStatus.UNKNOWN_ERROR.value,
            message=f"Unknown command: {args.command}",
        )

    print("\n=== RESULT ===", flush=True)
    print(result.to_json(), flush=True)
    success_statuses = [AutomationStatus.SUCCESS.value, AutomationStatus.ACCOUNT_CREATED.value]
    sys.exit(0 if result.status in success_statuses else 1)

if __name__ == "__main__":
    main()
