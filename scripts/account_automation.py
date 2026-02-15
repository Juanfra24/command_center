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

    def __init__(self, proxy_url: Optional[str] = None, headless: bool = False, slow_mode: bool = True, debug: bool = False):
        self.proxy_url_raw = proxy_url
        self.headless = headless
        self.slow_mode = slow_mode
        self.debug = debug
        self.sb = None

        self.debug_dir = os.path.join(os.getcwd(), "automation_debug")
        os.makedirs(self.debug_dir, exist_ok=True)

        ts = time.strftime("%Y%m%d_%H%M%S")
        self.profile_dir = os.path.join(self.debug_dir, "profiles", ts)
        os.makedirs(self.profile_dir, exist_ok=True)

    # ---------- logging ----------
    def _log(self, msg: str):
        print(msg)

    def _dbg(self, msg: str):
        if self.debug:
            print(msg)

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
        cleaned_proxy = self._clean_proxy_for_sbase(self.proxy_url_raw)

        self._log("[INFO] ===== Preflight =====")
        self._log(f"[INFO] Python: {sys.version.replace(os.linesep, ' ')}")
        self._log(f"[INFO] seleniumbase: {getattr(seleniumbase, '__version__', 'unknown')}")
        self._log(f"[INFO] Headless: {self.headless}")
        self._log(f"[INFO] Debug dir: {self.debug_dir}")
        self._log(f"[INFO] Profile dir: {self.profile_dir}")
        self._log(f"[INFO] Proxy raw (masked): {self._mask_proxy(self.proxy_url_raw)}")
        self._log(f"[INFO] Proxy cleaned for SB (masked): {self._mask_proxy(cleaned_proxy)}")

        if cleaned_proxy:
            fmt_err = self._validate_proxy_format_sbase(cleaned_proxy)
            if fmt_err:
                return AutomationResult(
                    status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                    message=fmt_err,
                    expected_ip=expected_ip,
                )

            hp = self._parse_host_port(cleaned_proxy)
            if hp:
                ok, msg = self._tcp_ping(hp[0], hp[1])
                self._log(f"[INFO] Proxy reachability {hp[0]}:{hp[1]}: {msg}")
                if not ok:
                    return AutomationResult(
                        status=AutomationStatus.PROXY_VALIDATION_FAILED.value,
                        message=f"Proxy not reachable: {hp[0]}:{hp[1]}. {msg}",
                        expected_ip=expected_ip,
                    )

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


def main():
    parser = argparse.ArgumentParser(description="Account automation with proxy validation")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate", help="Validate proxy IP address")
    validate_parser.add_argument("proxy_url", help="Proxy URL (host:port or user:pass@host:port)")
    validate_parser.add_argument("expected_ip", help="Expected IP address")
    validate_parser.add_argument("--headless", action="store_true", help="Run in headless mode")
    validate_parser.add_argument("--debug", action="store_true", help="Enable verbose debug logs")

    args = parser.parse_args()

    automation = AccountAutomation(
        proxy_url=args.proxy_url,
        headless=getattr(args, "headless", False),
        debug=getattr(args, "debug", False),
    )

    result = automation.validate_proxy_ip(args.expected_ip)

    print("\n=== RESULT ===")
    print(result.to_json())
    sys.exit(0 if result.status == AutomationStatus.SUCCESS.value else 1)

if __name__ == "__main__":
    main()
