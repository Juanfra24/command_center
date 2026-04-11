# scripts/automation/imap_poller.py
import re
import time
import email
import imaplib
from typing import Optional, Callable


def _extract_code(subject: str, body: str) -> Optional[str]:
    """Extract verification code from email subject or body.
    Jagex codes are typically 5 alphanumeric characters in the subject line
    (e.g., '8UJSN is your Jagex verification code')."""
    # 1. Check subject first — most reliable, no HTML noise
    subject_match = re.search(
        r'\b([A-Z0-9]{5,6})\b\s+is\s+your\s+.*verification',
        subject, re.IGNORECASE,
    )
    if subject_match:
        return subject_match.group(1)

    # 2. Generic subject pattern: code-like token at the start
    subject_match = re.search(r'^([A-Z0-9]{5,6})\b', subject.strip())
    if subject_match:
        return subject_match.group(1)

    # 3. Body: look for code near verification keywords (alphanumeric 5-6 chars)
    body_match = re.search(
        r'(?:code|verify|verification)[:\s]*([A-Z0-9]{5,6})\b',
        body, re.IGNORECASE,
    )
    if body_match:
        return body_match.group(1)

    # 4. Body: look for 6-digit numeric code near keywords
    body_match = re.search(
        r'(?:code|verify|verification)[:\s]*(\d{6})', body, re.IGNORECASE,
    )
    if body_match:
        return body_match.group(1)

    # 5. Fallback: any standalone 5-6 alphanumeric token in body
    body_match = re.search(r'\b([A-Z0-9]{5,6})\b', body)
    if body_match:
        return body_match.group(1)

    return None


def fetch_verification_code(
    imap_host: str,
    imap_user: str,
    imap_pass: str,
    target_email: str,
    timeout: int = 120,
    log_fn: Callable[[str], None] = print,
) -> Optional[str]:
    """Fetch the Jagex verification code from IMAP.
    Keeps a single connection open across poll iterations."""
    log_fn(f"[INFO] Checking IMAP for verification code (target: {target_email})...")
    start_time = time.time()
    mail = None

    try:
        while time.time() - start_time < timeout:
            # Keep blocking IMAP calls bounded by the remaining deadline so a
            # stuck fetch can't run tens of seconds past `timeout` and delay
            # SIGTERM-triggered cancellation on the parent process.
            remaining = max(1, int(timeout - (time.time() - start_time)))
            socket_timeout = min(30, remaining)
            # Connect/reconnect only when needed
            if mail is None:
                try:
                    mail = imaplib.IMAP4_SSL(imap_host, 993)
                    mail.socket().settimeout(socket_timeout)
                    mail.login(imap_user, imap_pass)
                    log_fn("[INFO] IMAP connected")
                except Exception as e:
                    log_fn(f"[WARNING] IMAP connect error: {e}")
                    mail = None
                    time.sleep(min(5, remaining))
                    continue
            else:
                try:
                    mail.socket().settimeout(socket_timeout)
                except Exception:
                    pass

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
                            if ct == "text/plain":
                                payload = part.get_payload(decode=True)
                                if payload:
                                    body += payload.decode("utf-8", errors="ignore")
                        # Fall back to HTML if no plain text
                        if not body:
                            for part in msg.walk():
                                ct = part.get_content_type()
                                if ct == "text/html":
                                    payload = part.get_payload(decode=True)
                                    if payload:
                                        raw = payload.decode("utf-8", errors="ignore")
                                        body += re.sub(r'<[^>]+>', ' ', raw)
                    else:
                        payload = msg.get_payload(decode=True)
                        if payload:
                            body = payload.decode("utf-8", errors="ignore")

                    code = _extract_code(subject, body)
                    if code:
                        log_fn(f"[INFO] Found verification code: {code}")
                        return code

            except Exception as e:
                log_fn(f"[WARNING] IMAP poll error: {e}")
                try:
                    mail.logout()
                except Exception:
                    pass
                mail = None
                time.sleep(min(5, max(0, int(timeout - (time.time() - start_time)))))
                continue

            remaining_after = int(timeout - (time.time() - start_time))
            if remaining_after <= 0:
                break
            log_fn(
                f"[INFO] No code yet, retrying in 5s... "
                f"({int(time.time() - start_time)}s elapsed)"
            )
            time.sleep(min(5, remaining_after))

    finally:
        if mail is not None:
            try:
                mail.logout()
            except Exception:
                pass

    log_fn("[WARNING] Timed out waiting for verification code")
    return None
