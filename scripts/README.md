# Python Automation Scripts

Browser automation for proxy validation, Jagex account creation, and interactive sessions using [Patchright](https://github.com/AidenPearce369/patchright) (a patched Playwright fork with stealth capabilities).

## Prerequisites

- **Python 3.8+** with pip
- Internet connection (for browser download on first run)

## Dependency Setup

Install all required packages:

```bash
cd scripts
pip install -r requirements.txt
```

This installs:

| Package | Version | Purpose |
|---------|---------|---------|
| `patchright` | >=1.49.0 | Stealth Chromium automation (patched Playwright) |
| `requests` | >=2.32.0 | HTTP client for IP validation requests |

After installing patchright, download the Chromium browser binary:

```bash
python -m patchright install chromium
```

## Entry Point

All commands go through `account_automation.py`:

```bash
python account_automation.py <command> [options]
```

## Commands

### `validate` -- Validate a Proxy IP

Opens a browser through the proxy and verifies the exit IP matches the expected address.

```bash
python account_automation.py validate <proxy_url> <expected_ip> [--headless] [--debug]
```

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `proxy_url` | Yes | Proxy URL in `username:password@host:port` format |
| `expected_ip` | Yes | The IP address the proxy should resolve to |
| `--headless` | No | Run browser without visible window |
| `--debug` | No | Enable verbose debug logging |

**Example:**

```bash
python account_automation.py validate "user123:pass456@p.webshare.io:80" "203.0.113.42" --headless
```

### `create-account` -- Create a Jagex Account

Automates the Jagex account creation flow through the proxy.

```bash
python account_automation.py create-account <proxy_url> <expected_ip> [options]
```

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `proxy_url` | Yes | Proxy URL in `username:password@host:port` format |
| `expected_ip` | Yes | Expected proxy exit IP |
| `--headless` | No | Run browser without visible window |
| `--debug` | No | Enable verbose debug logging |
| `--imap-host` | No | IMAP server hostname for email verification |
| `--imap-user` | No | IMAP username/email |
| `--imap-pass` | No | IMAP password |

**Example:**

```bash
python account_automation.py create-account \
  "user123:pass456@p.webshare.io:80" \
  "203.0.113.42" \
  --headless \
  --imap-host "imap.example.com" \
  --imap-user "bot@example.com" \
  --imap-pass "imappass"
```

### `session` -- Open an Interactive Browser Session

Launches a browser with the proxy configured for manual interaction.

```bash
python account_automation.py session <proxy_url> <expected_ip> [--keep-open] [--debug]
```

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `proxy_url` | Yes | Proxy URL in `username:password@host:port` format |
| `expected_ip` | Yes | Expected proxy exit IP |
| `--keep-open` | No | Keep the browser open after the script finishes |
| `--debug` | No | Enable verbose debug logging |

**Example:**

```bash
python account_automation.py session "user123:pass456@p.webshare.io:80" "203.0.113.42" --keep-open
```

## Proxy Format

All commands expect proxies in this format:

```
username:password@host:port
```

For Webshare proxies, the typical format is:

```
username:password@p.webshare.io:80
```

Do **not** include a protocol prefix (`http://`, `socks5://`).

## Output Format

All commands print structured JSON results to stdout after a marker line. The Flutter app parses this to determine success or failure.

**Marker:**

```
=== RESULT ===
```

**JSON fields:**

| Field | Type | Always Present | Description |
|-------|------|----------------|-------------|
| `status` | string | Yes | Status code (see below) |
| `message` | string | Yes | Human-readable description |
| `expected_ip` | string | No | The IP the proxy should have |
| `actual_ip` | string | No | The IP the browser actually resolved to |
| `data` | object | No | Extra data (e.g., account details on creation) |

**Status codes:**

| Status | Meaning |
|--------|---------|
| `success` | Operation completed successfully |
| `account_created` | Account was created (includes account data) |
| `proxy_validation_failed` | Proxy IP did not match expected IP |
| `browser_error` | Browser failed to launch or crashed |
| `timeout` | Operation exceeded time limit |
| `captcha_required` | CAPTCHA was encountered and could not be solved |
| `unknown_error` | Unexpected failure |

**Example successful validation output:**

```
=== RESULT ===
{
  "status": "success",
  "message": "Proxy IP validated successfully",
  "expected_ip": "203.0.113.42",
  "actual_ip": "203.0.113.42"
}
```

**Example account creation output:**

```
=== RESULT ===
{
  "status": "account_created",
  "message": "Account created successfully",
  "expected_ip": "203.0.113.42",
  "actual_ip": "203.0.113.42",
  "data": {
    "accountName": "player123",
    "email": "bot@example.com",
    "password": "generatedPass"
  }
}
```

## Debugging Tips

### Common Errors

**`Failed to import patchright`**
Patchright is not installed. Run:
```bash
pip install patchright
python -m patchright install chromium
```

**`proxy_validation_failed`**
The browser's detected IP did not match `expected_ip`. Possible causes:
- Proxy credentials are incorrect
- Proxy slot IP was recently rotated
- The proxy service is temporarily down

**`browser_error`**
The Chromium browser could not start. Check:
- Patchright browser binary is installed (`python -m patchright install chromium`)
- No other process is locking the browser profile directory
- Sufficient disk space and memory

**`timeout`**
The operation took too long. Retry with `--debug` to see where it stalled. Possible causes:
- Slow proxy connection
- Target website is unresponsive
- CAPTCHA was encountered

### Manual Testing

1. **Test proxy connectivity first:**
   ```bash
   python account_automation.py validate "user:pass@host:port" "1.2.3.4" --debug
   ```

2. **Run with visible browser for debugging:**
   Omit `--headless` to watch the automation in real-time.

3. **Check raw output:**
   Look for the `=== RESULT ===` line in stdout. Everything after that line is the JSON result. Log lines printed before the marker are informational and can be ignored by parsers.

4. **Signal handling:**
   The script handles `SIGTERM` and `SIGINT` gracefully, printing an `unknown_error` result before exiting.

## Project Structure

```
scripts/
├── account_automation.py          # CLI entry point
├── requirements.txt               # Python dependencies
├── automation/
│   ├── __init__.py
│   ├── browser.py                 # Stealth browser launch/close (Patchright)
│   ├── models.py                  # AutomationResult / AutomationStatus
│   ├── proxy.py                   # Proxy URL parsing helpers
│   ├── helpers.py                 # Shared utilities
│   ├── imap_poller.py             # IMAP email polling for verification
│   └── commands/
│       ├── __init__.py
│       ├── validate.py            # validate subcommand
│       ├── create_account.py      # create-account subcommand
│       └── session.py             # session subcommand
├── openChrome.py                  # Standalone Chrome launcher
└── test_captcha.py                # Captcha testing script
```
