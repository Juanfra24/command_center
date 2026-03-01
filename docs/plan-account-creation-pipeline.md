# Plan: Complete Account Creation Pipeline

## Context
The account creation automation currently handles steps 1-8 (IP validation → form submission). We need to complete steps 9-12 (email verification, account name, password, confirmation) and persist results to the database. The user recorded a video of the full manual flow and provided IMAP credentials for email verification. Names/emails must be randomized but coherent (gaming-style).

## Files to Modify

### 1. `scripts/account_automation.py` — Complete automation steps 9-12

**Add IMAP email verification:**
- New CLI args: `--imap-host`, `--imap-user`, `--imap-pass`
- New `_fetch_verification_code(imap_host, imap_user, imap_pass, target_email, timeout=120)` function
  - Connect via IMAP SSL (port 993)
  - Search for recent emails from Jagex containing the verification code
  - Parse HTML email body to extract 6-digit code
  - Retry with polling (every 5s) until timeout

**Add gaming-style name generation:**
- New `_generate_account_name()` function
  - Combines adjectives (Dark, Shadow, Iron, Swift, etc.) + nouns (Knight, Mage, Archer, etc.) + optional 2-3 digit number
  - Returns names like "SwiftArcher42", "DarkMage871"
- New `_generate_email(account_name)` function
  - Derives email from account name: e.g., `swiftarcher42@onemanco.org`
  - Lowercase, no special chars

**Add password generation:**
- New `_generate_password()` function
  - 12-16 chars, mix of upper/lower/digits/special chars
  - Meets Jagex password requirements

**Complete create_account() flow after form submission:**
- Step 9: Wait for email verification page, enter code from IMAP
- Step 10: Wait for "choose display name" page, enter generated account name
- Step 11: Wait for "set password" page, enter generated password (type twice)
- Step 12: Wait for confirmation/success page

**Expand result data:**
```python
AutomationResult(
    status="account_created",
    data={
        "email": email,
        "password": password,
        "accountName": account_name,
        "dob": dob_str,
        "confirmed": True
    }
)
```

### 2. `lib/config/services/app_config_service.dart` — IMAP credential storage

- Add constants: `imapHost`, `imapUser`, `imapPass`
- Seed defaults in `_seedDefaults()`:
  - `imap_host` → `mail.privateemail.com`
  - `imap_user` → `contact@onemanco.org`
  - `imap_pass` → `}7FWKb/*u/7Hj:z`
- Add getter methods: `getImapHost()`, `getImapUser()`, `getImapPass()`

### 3. `lib/config/services/automation_service.dart` — Pass IMAP creds & persist account

- Inject `AppConfigService` and `AccountRepository` via constructor/DI
- In `createAccount()`:
  - Fetch IMAP creds from AppConfigService
  - Pass as CLI args to Python: `--imap-host`, `--imap-user`, `--imap-pass`
  - Increase timeout from 5min to 10min (email verification takes time)
  - On success: create `AccountEntity` from result data and call `accountRepository.insertAccount()`
  - Return the created account info to the caller

### 4. `lib/feature/Status/controller/status_controller.dart` — Fix TODO mappings

- Fix `proxyAddress: '0.0.0.0'` TODO:
  - Look up the proxy slot by `account.proxySlotId` using ProxyController
  - Resolve to actual IP address or show 'No proxy' if null
- Fix `characters: []` TODO:
  - Map `AccountEntity.characters` → UI Character models
  - Handle SkillsEntity↔Skills key mismatch (lowercase→Capitalized)
- Add method to refresh accounts after creation

### 5. `lib/feature/Status/views/status_screen.dart` — Improve post-creation UX

- After successful account creation, show full details (name, email, password) in InfoBar
- Call controller refresh to update the account list immediately
- Show the newly created account in the list

## Implementation Order
1. `app_config_service.dart` — IMAP storage (foundation)
2. `account_automation.py` — Complete Python automation (core logic)
3. `automation_service.dart` — Wire IMAP creds + DB persistence
4. `status_controller.dart` — Fix TODO mappings
5. `status_screen.dart` — Improve UX

## Verification
1. Run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` if schema changes
2. Test Python script standalone: `python scripts/account_automation.py create --proxy user:pass@host:port --imap-host mail.privateemail.com --imap-user contact@onemanco.org --imap-pass "password"`
3. Test from Flutter UI: Create character dialog → select proxy → verify full flow completes
4. Check SQLite DB to confirm account + character rows are persisted
5. Verify account list refreshes and shows correct proxy address and character data
