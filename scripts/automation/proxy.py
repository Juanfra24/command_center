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
