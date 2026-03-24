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
    """Raise KeyboardInterrupt so asyncio.run() can cancel tasks and run finally blocks."""
    raise KeyboardInterrupt


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


def _get_proxy_url(args) -> str:
    """Resolve proxy URL from env var."""
    import os
    return os.environ.get("CC_PROXY_URL", "")


def _get_imap_creds(args) -> tuple:
    """Resolve IMAP user/pass from env vars (preferred) or CLI args (fallback)."""
    import os
    user = os.environ.get("CC_IMAP_USER") or getattr(args, "imap_user", None)
    passwd = os.environ.get("CC_IMAP_PASS") or getattr(args, "imap_pass", None)
    return user, passwd


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Account automation with proxy validation")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_p = subparsers.add_parser("validate", help="Validate proxy IP address")
    validate_p.add_argument("expected_ip", help="Expected IP address")
    validate_p.add_argument("--headless", action="store_true")
    validate_p.add_argument("--debug", action="store_true")

    create_p = subparsers.add_parser("create-account", help="Create a new Jagex account")
    create_p.add_argument("expected_ip", help="Expected IP address")
    create_p.add_argument("--headless", action="store_true")
    create_p.add_argument("--debug", action="store_true")
    create_p.add_argument("--imap-host", help="IMAP server hostname")
    create_p.add_argument("--imap-user", help="IMAP username/email (prefer CC_IMAP_USER env var)")
    create_p.add_argument("--imap-pass", help="IMAP password (prefer CC_IMAP_PASS env var)")

    session_p = subparsers.add_parser("session", help="Open browser session with proxy")
    session_p.add_argument("expected_ip", help="Expected IP address")
    session_p.add_argument("--keep-open", action="store_true")
    session_p.add_argument("--debug", action="store_true")

    return parser


def _log(msg: str):
    """Flushing log function passed to all commands."""
    print(msg, flush=True)


async def run(args) -> AutomationResult:
    proxy_url = _get_proxy_url(args)

    if args.command == "validate":
        from automation.commands.validate import validate_proxy_ip
        return await validate_proxy_ip(
            proxy_url=proxy_url,
            expected_ip=args.expected_ip,
            headless=getattr(args, "headless", False),
            debug=getattr(args, "debug", False),
            log_fn=_log,
        )
    elif args.command == "create-account":
        imap_user, imap_pass = _get_imap_creds(args)
        from automation.commands.create_account import create_account
        return await create_account(
            proxy_url=proxy_url,
            expected_ip=args.expected_ip,
            headless=getattr(args, "headless", False),
            debug=getattr(args, "debug", False),
            imap_host=getattr(args, "imap_host", None),
            imap_user=imap_user,
            imap_pass=imap_pass,
            log_fn=_log,
        )
    elif args.command == "session":
        from automation.commands.session import launch_session
        return await launch_session(
            proxy_url=proxy_url,
            expected_ip=args.expected_ip,
            keep_open=getattr(args, "keep_open", False),
            debug=getattr(args, "debug", False),
            log_fn=_log,
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
