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
                    mail = imaplib.IMAP4_SSL(imap_host, 993, timeout=30)
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
                email_ids = messages[0].split()
                if not email_ids:
                    _, messages = mail.search(None, '(FROM "jagex.com" UNSEEN)')
                    email_ids = messages[0].split()
                for eid in reversed(email_ids[-10:]):
                    _, msg_data = mail.fetch(eid, "(RFC822)")
                    if not msg_data or not isinstance(msg_data[0], tuple):
                        continue
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

                    # Prefer code near verification keywords
                    code_match = re.search(
                        r'(?:code|verify|verification)[:\s]*(\d{6})', body, re.IGNORECASE
                    )
                    if not code_match:
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
