# Jagex Account Login Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate Jagex account (OAuth) login so bots launch, acquire their own Jagex session token, and log in without manual intervention.

**Architecture:** Each bot process gets an isolated `jagex.userhome` JVM flag pointing to its own profile subdirectory (`bot-<id>/jagex/`). A new `JagexTokenService` seeds `credentials.properties` there before every launch — using a stored OAuth refresh token for instant HTTP-only renewal, falling back to a Patchright browser flow (with IMAP verification) for first-time auth or when the refresh token expires. `AutoLoginPlugin` is fixed to actually press Enter after injecting credentials.

**Tech Stack:** Java (RuneLite plugin), Python + Patchright, Dart + GetX + Drift ORM, `http` ^1.2.0 (already in pubspec)

---

## File Map

| Action | Path |
|--------|------|
| Modify | `Microbot_Frieren/runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/AutoLoginPlugin.java` |
| Modify | `lib/data/database/tables/accounts_table.dart` |
| Modify | `lib/domain/entities/account.dart` |
| Modify | `lib/domain/repositories/account_repository.dart` |
| Modify | `lib/data/database/app_database.dart` |
| Modify | `lib/data/repositories/account_repository_impl.dart` |
| Create | `scripts/automation/commands/jagex_auth.py` |
| Modify | `scripts/account_automation.py` |
| Create | `lib/config/services/jagex/jagex_token_service.dart` |
| Modify | `lib/config/services/bot_engine/microbot_engine.dart` |
| Modify | `lib/config/services/automation/automation_service.dart` |
| Modify | `lib/core/resource/dependency_injection.dart` |
| Modify (test) | `test/config/services/bot_engine/microbot_engine_test.dart` |
| Create (test) | `test/config/services/jagex/jagex_token_service_test.dart` |

---

## Task 1: AutoLoginPlugin — Add Enter Press

**Repo:** `Microbot_Frieren`

**Files:**
- Modify: `runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/AutoLoginPlugin.java`

- [ ] **Step 1: Compile the current code to confirm it passes before changes**

```bash
cd C:\Users\Juanfra\projects\Microbot_Frieren
./gradlew :client:compileJava --no-daemon -q
```
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 2: Replace the full `AutoLoginPlugin.java` with the fixed version**

```java
package net.runelite.client.plugins.microbot.commandcenter;

import lombok.extern.slf4j.Slf4j;
import net.runelite.api.Client;
import net.runelite.api.GameState;
import net.runelite.api.events.GameStateChanged;
import net.runelite.client.eventbus.Subscribe;
import net.runelite.client.plugins.Plugin;
import net.runelite.client.plugins.PluginDescriptor;
import net.runelite.client.plugins.microbot.util.keyboard.Rs2Keyboard;
import net.runelite.client.plugins.microbot.util.security.LoginManager;

import javax.inject.Inject;
import java.awt.event.KeyEvent;
import java.io.FileInputStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@PluginDescriptor(
    name = "CC Auto Login",
    description = "Auto-login from Command Center profile credentials",
    enabledByDefault = false
)
@Slf4j
public class AutoLoginPlugin extends Plugin {
    @Inject
    private Client client;

    private String email;
    private String password;
    private String world;
    private boolean loginAttempted;
    private ScheduledExecutorService executor;

    @Override
    protected void startUp() {
        loginAttempted = false;
        executor = Executors.newSingleThreadScheduledExecutor();

        String profileDir = System.getProperty("cc-profile-dir");
        if (profileDir == null || profileDir.isEmpty()) {
            log.warn("No --cc-profile-dir set, AutoLogin disabled");
            return;
        }

        Path profilePath = Paths.get(profileDir);

        try (var fis = new FileInputStream(profilePath.resolve("credentials.properties").toFile())) {
            Properties creds = new Properties();
            creds.load(fis);
            email = creds.getProperty("email");
            password = creds.getProperty("password");
        } catch (Exception e) {
            log.error("Failed to read credentials.properties: {}", e.getMessage());
        }

        try (var fis = new FileInputStream(profilePath.resolve("commandcenter.properties").toFile())) {
            Properties config = new Properties();
            config.load(fis);
            world = config.getProperty("world");
        } catch (Exception e) {
            log.debug("No commandcenter.properties or no world set");
        }
    }

    @Subscribe
    public void onGameStateChanged(GameStateChanged event) {
        if (event.getGameState() != GameState.LOGIN_SCREEN) return;
        if (loginAttempted) return;
        if (email == null || password == null) return;

        loginAttempted = true;

        if (world != null && !world.isEmpty() && !"auto".equals(world)) {
            try {
                int worldNum = Integer.parseInt(world);
                LoginManager.setWorld(worldNum);
            } catch (NumberFormatException e) {
                log.warn("Invalid world number: {}", world);
            }
        }

        client.setUsername(email);
        client.setPassword(password);

        String prefix = email.length() >= 3 ? email.substring(0, 3) : email;
        log.info("AutoLogin: credentials injected for {}***, submitting in 600ms", prefix);

        executor.schedule(() -> {
            Rs2Keyboard.keyPress(KeyEvent.VK_ENTER);
            log.info("AutoLogin: Enter pressed");
        }, 600, TimeUnit.MILLISECONDS);
    }

    @Override
    protected void shutDown() {
        if (executor != null) {
            executor.shutdownNow();
            executor = null;
        }
        email = null;
        password = null;
        world = null;
    }
}
```

- [ ] **Step 3: Compile to verify no errors**

```bash
cd C:\Users\Juanfra\projects\Microbot_Frieren
./gradlew :client:compileJava --no-daemon -q
```
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: Commit**

```bash
cd C:\Users\Juanfra\projects\Microbot_Frieren
git add runelite-client/src/main/java/net/runelite/client/plugins/microbot/commandcenter/AutoLoginPlugin.java
git commit -m "fix(AutoLoginPlugin): press Enter 600ms after credential injection

Bot was getting stuck on login screen because credentials were injected
but the login form was never submitted. Added ScheduledExecutorService
to delay-press VK_ENTER after setUsername/setPassword. Covers both
Jagex accounts (triggers OAuth exchange with pre-seeded token) and
legacy accounts (submits username/password form).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: DB Schema v8 — Jagex Token Columns

**Repo:** `command_center`

**Files:**
- Modify: `lib/data/database/tables/accounts_table.dart`
- Modify: `lib/domain/entities/account.dart`
- Modify: `lib/domain/repositories/account_repository.dart`
- Modify: `lib/data/database/app_database.dart`
- Modify: `lib/data/repositories/account_repository_impl.dart`
- Test: existing `test/data/repositories/account_repository_test.dart` (if it exists) or create assertions inline

- [ ] **Step 1: Write failing test for the new `updateJagexToken` method**

**Create** `test/data/repositories/account_repository_test.dart` — this file does not exist yet. Contents:

```dart
// In an existing group or new group:
test('updateJagexToken stores refresh token, character id and display name', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final repo = AccountRepositoryImpl(db);

  final accountId = await repo.insertAccount(AccountEntity(
    accountName: 'TestBot',
    birthday: '01-01-2000',
    email: 'test@example.com',
    password: 'pass',
    characters: const [],
  ));

  await repo.updateJagexToken(
    accountId: accountId,
    refreshToken: 'rt_abc123',
    characterId: 'char_456',
    displayName: 'TestBotName',
  );

  final updated = await repo.getAccountById(accountId);
  expect(updated!.jagexRefreshToken, 'rt_abc123');
  expect(updated.jagexCharacterId, 'char_456');
  expect(updated.jagexDisplayName, 'TestBotName');

  await db.close();
});
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
cd C:\Users\Juanfra\projects\command_center
flutter test test/data/repositories/account_repository_test.dart -v
```
Expected: compile error — `updateJagexToken` not defined.

- [ ] **Step 3: Add 3 nullable columns to `accounts_table.dart`**

In `lib/data/database/tables/accounts_table.dart`, add after `lastUpdated`:

```dart
  /// OAuth refresh token for Jagex account (long-lived, weeks/months)
  TextColumn get jagexRefreshToken => text().nullable()();

  /// Jagex account character ID from game-session API
  TextColumn get jagexCharacterId => text().nullable()();

  /// Jagex display name from game-session API
  TextColumn get jagexDisplayName => text().nullable()();
```

- [ ] **Step 4: Add 3 optional fields to `lib/domain/entities/account.dart`**

Replace the entire file:

```dart
import 'package:equatable/equatable.dart';

import 'character.dart';

/// Domain entity for a Jagex account
class AccountEntity extends Equatable {
  final int? id;
  final String accountName;
  final String birthday;
  final String email;
  final String password;
  final int? proxySlotId;
  final List<CharacterEntity> characters;
  final DateTime? createdAt;
  final DateTime? lastUpdated;
  final String? jagexRefreshToken;
  final String? jagexCharacterId;
  final String? jagexDisplayName;

  const AccountEntity({
    this.id,
    required this.accountName,
    required this.birthday,
    required this.email,
    required this.password,
    this.proxySlotId,
    required this.characters,
    this.createdAt,
    this.lastUpdated,
    this.jagexRefreshToken,
    this.jagexCharacterId,
    this.jagexDisplayName,
  });

  factory AccountEntity.empty() {
    return const AccountEntity(
      id: null,
      accountName: 'Default Name',
      birthday: '01-01-2000',
      email: 'default@example.com',
      password: 'defaultPassword123',
      proxySlotId: null,
      characters: [],
    );
  }

  String get proxyAddress => '';

  AccountEntity copyWith({
    int? id,
    String? accountName,
    String? birthday,
    String? email,
    String? password,
    int? proxySlotId,
    List<CharacterEntity>? characters,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? jagexRefreshToken,
    String? jagexCharacterId,
    String? jagexDisplayName,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      birthday: birthday ?? this.birthday,
      email: email ?? this.email,
      password: password ?? this.password,
      proxySlotId: proxySlotId ?? this.proxySlotId,
      characters: characters ?? this.characters,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      jagexRefreshToken: jagexRefreshToken ?? this.jagexRefreshToken,
      jagexCharacterId: jagexCharacterId ?? this.jagexCharacterId,
      jagexDisplayName: jagexDisplayName ?? this.jagexDisplayName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountName,
        birthday,
        email,
        password,
        proxySlotId,
        characters,
        createdAt,
        lastUpdated,
        jagexRefreshToken,
        jagexCharacterId,
        jagexDisplayName,
      ];
}
```

- [ ] **Step 5: Add `updateJagexToken` to the repository interface**

In `lib/domain/repositories/account_repository.dart`, add after `updateCharacterDefaultScript`:

```dart
  /// Store Jagex OAuth token data for an account
  Future<void> updateJagexToken({
    required int accountId,
    required String refreshToken,
    required String characterId,
    required String displayName,
  });
```

- [ ] **Step 6: Add migration v8 to `app_database.dart`**

Change `schemaVersion` from `7` to `8`:
```dart
  @override
  int get schemaVersion => 8;
```

Add inside `onUpgrade`, after the `from < 7` block:
```dart
        if (from < 8) {
          await _addColumnIfMissing('accounts_table', 'jagex_refresh_token');
          await _addColumnIfMissing('accounts_table', 'jagex_character_id');
          await _addColumnIfMissing('accounts_table', 'jagex_display_name');
        }
```

- [ ] **Step 7: Update `_mapAccountRow` and add `updateJagexToken` in `account_repository_impl.dart`**

In `_mapAccountRow`, replace the return statement:
```dart
  AccountEntity _mapAccountRow(
    AccountsTableData row,
    List<CharacterEntity> characters,
  ) {
    return AccountEntity(
      id: row.id,
      accountName: row.accountName,
      birthday: row.birthday,
      email: row.email,
      password: row.password,
      proxySlotId: row.proxySlotId,
      characters: characters,
      createdAt: row.createdAt,
      lastUpdated: row.lastUpdated,
      jagexRefreshToken: row.jagexRefreshToken,
      jagexCharacterId: row.jagexCharacterId,
      jagexDisplayName: row.jagexDisplayName,
    );
  }
```

Add `updateJagexToken` implementation before the mapping helpers comment:
```dart
  @override
  Future<void> updateJagexToken({
    required int accountId,
    required String refreshToken,
    required String characterId,
    required String displayName,
  }) async {
    await (_db.update(_db.accountsTable)
          ..where((tbl) => tbl.id.equals(accountId)))
        .write(AccountsTableCompanion(
      jagexRefreshToken: Value(refreshToken),
      jagexCharacterId: Value(characterId),
      jagexDisplayName: Value(displayName),
      lastUpdated: Value(DateTime.now()),
    ));
  }
```

- [ ] **Step 8: Run code generation**

```bash
cd C:\Users\Juanfra\projects\command_center
dart run build_runner build --delete-conflicting-outputs
```
Expected: exits with no errors, regenerates `app_database.g.dart`.

- [ ] **Step 9: Run the failing test — it should now pass**

```bash
flutter test test/data/repositories/account_repository_test.dart -v
```
Expected: all tests pass including the new `updateJagexToken` test.

- [ ] **Step 10: Run full test suite to catch regressions**

```bash
flutter test
```
Expected: all 315+ tests pass.

- [ ] **Step 11: Commit**

```bash
git add lib/data/database/tables/accounts_table.dart \
        lib/domain/entities/account.dart \
        lib/domain/repositories/account_repository.dart \
        lib/data/database/app_database.dart \
        lib/data/repositories/account_repository_impl.dart \
        lib/data/database/app_database.g.dart \
        test/data/repositories/account_repository_test.dart
git commit -m "feat(db): migration v8 — add Jagex OAuth token columns to accounts

Adds jagex_refresh_token, jagex_character_id, jagex_display_name to
accounts_table. These columns store the Jagex OAuth credentials needed
to seed per-instance credentials.properties before each bot launch.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Python jagex-auth Command

**Repo:** `command_center`

**Files:**
- Create: `scripts/automation/commands/jagex_auth.py`
- Modify: `scripts/account_automation.py`

The `jagex-auth` command automates the Jagex OAuth browser flow and writes the game session credentials to the bot's profile directory. The password is received via the `CC_ACCOUNT_PASS` environment variable (never via argv).

**OAuth flow summary:**
1. Patchright opens `https://account.jagex.com` login page
2. Fills email + password
3. If Jagex sends email verification → IMAP poller reads code and submits it
4. Intercepts the token endpoint response (`https://account.jagex.com/oauth2/token`) to capture `refresh_token` and `id_token`
5. POSTs `id_token` to `https://auth.jagex.com/game-session/v1/sessions` → gets `sessionId`
6. GETs `https://auth.jagex.com/game-session/v1/accounts` (Bearer: `sessionId`) → gets `accountId` + `displayName`
7. Writes `<profile_dir>/credentials.properties` (Jagex format)
8. Returns JSON: `{ "status": "success", "refresh_token": "...", "character_id": "...", "display_name": "..." }`

- [ ] **Step 1: Create `scripts/automation/commands/jagex_auth.py`**

Fixes applied vs. initial draft (all confirmed against actual source signatures):
- `launch_browser` returns `(pw, browser, context, page)` 4-tuple — unpack correctly; no `log_fn` param
- `close_browser(pw, browser)` takes 2 args
- `fetch_verification_code` has required `target_email` param and uses `timeout=` (not `timeout_seconds=`)
- `AutomationStatus` members must use `.value` (str) since `AutomationResult.status` is `str`
- `human_type` already calls `page.click()` internally — no separate click needed before it
- Use `click_first_match` helper instead of manual locator loops

```python
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
    # launch_browser returns (pw, browser, context, page) — must unpack all 4
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

        # Fill email — human_type already clicks the field internally
        log_fn("[jagex-auth] Entering email...")
        email_selector = 'input[type="email"], input[name="email"], input[id*="email"]'
        await page.wait_for_selector(email_selector, timeout=15000)
        await human_type(page, email_selector, email)
        await human_delay(0.5, 1.0)

        # Click Next / Continue (Jagex login is a two-step form)
        await click_first_match(page, _SUBMIT_SELECTORS, label="Submit email", log_fn=log_fn)
        await human_delay(1.0, 2.0)

        # Fill password — human_type already clicks the field internally
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
                                target_email=email,   # required param
                                timeout=120,           # correct param name
                                log_fn=log_fn,
                            ),
                        )
                        if code:
                            log_fn(f"[jagex-auth] Verification code received: {code[:3]}***")
                            # human_type clicks the field internally
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
        # close_browser takes (pw, browser) — both required
        if browser and pw:
            await close_browser(pw, browser)
```

- [ ] **Step 2: Register the `jagex-auth` subcommand in `scripts/account_automation.py`**

In `build_parser()`, add after the `session_p` block (before the final `return parser`):

```python
    jagex_auth_p = subparsers.add_parser("jagex-auth", help="Acquire Jagex OAuth token and write credentials.properties")
    jagex_auth_p.add_argument("--email", required=True, help="Jagex account email")
    jagex_auth_p.add_argument("--profile-dir", required=True, help="Path to write credentials.properties")
    jagex_auth_p.add_argument("--imap-host", help="IMAP server hostname")
    jagex_auth_p.add_argument("--debug", action="store_true")
```

In `run()`, add after the `elif args.command == "session":` block:

```python
    elif args.command == "jagex-auth":
        password = os.environ.get("CC_ACCOUNT_PASS", "")
        imap_user, imap_pass = _get_imap_creds(args)
        from automation.commands.jagex_auth import jagex_auth
        return await jagex_auth(
            email=args.email,
            password=password,
            profile_dir=args.profile_dir,
            imap_host=getattr(args, "imap_host", None),
            imap_user=imap_user,
            imap_pass=imap_pass,
            debug=getattr(args, "debug", False),
            log_fn=_log,
        )
```

Add `import os` at module top level in `account_automation.py` (before `def signal_handler`). Currently `os` is only imported inside individual function bodies, so the new `jagex-auth` branch in `run()` would get a `NameError` without a module-level import.

- [ ] **Step 3: Verify Python syntax is clean**

```bash
cd C:\Users\Juanfra\projects\command_center\scripts
python -m py_compile automation/commands/jagex_auth.py && echo "OK"
python -m py_compile account_automation.py && echo "OK"
```
Expected: `OK` for both.

- [ ] **Step 4: Commit**

```bash
cd C:\Users\Juanfra\projects\command_center
git add scripts/automation/commands/jagex_auth.py scripts/account_automation.py
git commit -m "feat(scripts): add jagex-auth command for OAuth token acquisition

Uses Patchright to automate the Jagex accounts.jagex.com login flow.
Intercepts the OAuth token endpoint response to capture id_token and
refresh_token. Calls game-session API to get sessionId + accountId.
Writes JX_* credentials.properties to the bot's jagex/ profile dir.
Supports IMAP email verification for 2FA.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: JagexTokenService

**Repo:** `command_center`

**Files:**
- Create: `lib/config/services/jagex/jagex_token_service.dart`
- Create: `test/config/services/jagex/jagex_token_service_test.dart`

The service is the single point responsible for: checking whether a token is stored, refreshing it via HTTP (fast path), falling back to Python automation for first-time auth, and writing the Jagex credentials file to `<profileDir>/jagex/credentials.properties`.

Token refresh endpoint: `POST https://account.jagex.com/oauth2/token`
Game session endpoint: `POST https://auth.jagex.com/game-session/v1/sessions`
Accounts endpoint: `GET https://auth.jagex.com/game-session/v1/accounts`

- [ ] **Step 1: Write the failing tests first**

Create `test/config/services/jagex/jagex_token_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('jagex_token_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('JagexTokenService._writeCredentialsFile', () {
    test('writes correct JX_* format to jagex/credentials.properties', () async {
      await JagexTokenService.writeCredentialsFile(
        profileDir: tempDir.path,
        sessionId: 'sess_abc',
        characterId: 'char_123',
        displayName: 'BotFrieren',
      );

      final file = File(p.join(tempDir.path, 'jagex', 'credentials.properties'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('JX_CHARACTER_ID=char_123'));
      expect(content, contains('JX_SESSION_ID=sess_abc'));
      expect(content, contains('JX_DISPLAY_NAME=BotFrieren'));
      expect(content, contains('JX_REFRESH_TOKEN='));
      expect(content, contains('JX_ACCESS_TOKEN='));
    });

    test('creates jagex/ subdirectory if it does not exist', () async {
      final subDir = p.join(tempDir.path, 'bot-99');
      await JagexTokenService.writeCredentialsFile(
        profileDir: subDir,
        sessionId: 's',
        characterId: 'c',
        displayName: 'd',
      );
      expect(Directory(p.join(subDir, 'jagex')).existsSync(), isTrue);
    });
  });

  group('JagexTokenService.jagexHomeDir', () {
    test('returns profileDir/jagex', () {
      expect(
        JagexTokenService.jagexHomeDir('/profiles/bot-42'),
        p.join('/profiles/bot-42', 'jagex'),
      );
    });
  });
}
```

- [ ] **Step 2: Run the failing test**

```bash
cd C:\Users\Juanfra\projects\command_center
flutter test test/config/services/jagex/jagex_token_service_test.dart -v
```
Expected: compile error — `JagexTokenService` not found.

- [ ] **Step 3: Create `lib/config/services/jagex/jagex_token_service.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:command_center/config/services/automation/python_runner.dart';
import 'package:command_center/config/services/automation/result_parser.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Manages Jagex OAuth token lifecycle for bot accounts.
///
/// Before each bot launch, [seedToken] is called to ensure a fresh
/// game session token is written to `<profileDir>/jagex/credentials.properties`.
/// Fast path: HTTP refresh using the stored refresh token (seconds).
/// Slow path: Patchright browser flow via Python, used on first auth or
/// when the refresh token has expired (weeks/months).
class JagexTokenService {
  final DatabaseService _db;
  final PythonRunner _pythonRunner;

  static const _tokenUrl = 'https://account.jagex.com/oauth2/token';
  static const _sessionUrl = 'https://auth.jagex.com/game-session/v1/sessions';
  static const _accountsUrl = 'https://auth.jagex.com/game-session/v1/accounts';
  static const _clientId = 'com_jagex_auth_desktop_launcher';

  JagexTokenService({
    required DatabaseService db,
    required PythonRunner pythonRunner,
  })  : _db = db,
        _pythonRunner = pythonRunner;

  /// Returns the jagex home dir path for a given profile dir.
  /// This is what gets passed as `-Djagex.userhome` to the JVM.
  static String jagexHomeDir(String profileDir) => p.join(profileDir, 'jagex');

  /// Write the game client credentials file at `<profileDir>/jagex/credentials.properties`.
  /// Static so it can be tested independently.
  static Future<void> writeCredentialsFile({
    required String profileDir,
    required String sessionId,
    required String characterId,
    required String displayName,
  }) async {
    final jagexDir = Directory(jagexHomeDir(profileDir));
    await jagexDir.create(recursive: true);

    final content = [
      '#Do not share this file with anyone',
      'JX_CHARACTER_ID=$characterId',
      'JX_SESSION_ID=$sessionId',
      'JX_REFRESH_TOKEN=',
      'JX_DISPLAY_NAME=$displayName',
      'JX_ACCESS_TOKEN=',
      '',
    ].join('\n');

    await File(p.join(jagexDir.path, 'credentials.properties'))
        .writeAsString(content);
  }

  /// Seed the Jagex credentials file before launching a bot.
  /// Tries HTTP refresh first; falls back to full Patchright browser auth.
  Future<void> seedToken({
    required int accountId,
    required String email,
    required String password,
    required String profileDir,
    String? imapHost,
    String? imapUser,
    String? imapPass,
  }) async {
    final account = await _db.accountRepository.getAccountById(accountId);
    if (account == null) throw Exception('Account $accountId not found');

    if (account.jagexRefreshToken != null) {
      try {
        logger.i('[JagexToken] Refreshing token via HTTP for account $accountId');
        final idToken = await _httpRefreshIdToken(account.jagexRefreshToken!);
        final session = await _getGameSession(idToken);
        await writeCredentialsFile(
          profileDir: profileDir,
          sessionId: session.$1,
          characterId: account.jagexCharacterId ?? session.$2,
          displayName: account.jagexDisplayName ?? session.$3,
        );
        logger.i('[JagexToken] Token seeded via HTTP refresh');
        return;
      } catch (e) {
        logger.w('[JagexToken] HTTP refresh failed ($e), falling back to browser auth');
      }
    }

    logger.i('[JagexToken] Running browser auth for account $accountId');
    await _acquireViaAutomation(
      accountId: accountId,
      email: email,
      password: password,
      profileDir: profileDir,
      imapHost: imapHost,
      imapUser: imapUser,
      imapPass: imapPass,
    );
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<String> _httpRefreshIdToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Token refresh HTTP ${response.statusCode}: ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = json['id_token'] as String?;
    if (idToken == null) throw Exception('id_token missing from refresh response');
    return idToken;
  }

  /// Returns (sessionId, characterId, displayName).
  Future<(String, String, String)> _getGameSession(String idToken) async {
    final sessionResp = await http.post(
      Uri.parse(_sessionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (sessionResp.statusCode != 200) {
      throw Exception('Session API HTTP ${sessionResp.statusCode}');
    }
    final sessionId =
        (jsonDecode(sessionResp.body) as Map<String, dynamic>)['sessionId'] as String;

    final accountsResp = await http.get(
      Uri.parse(_accountsUrl),
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (accountsResp.statusCode != 200) {
      throw Exception('Accounts API HTTP ${accountsResp.statusCode}');
    }
    final accounts = jsonDecode(accountsResp.body) as List;
    if (accounts.isEmpty) throw Exception('No accounts in game-session response');

    final first = accounts.first as Map<String, dynamic>;
    return (
      sessionId,
      first['accountId'] as String,
      first['displayName'] as String,
    );
  }

  Future<void> _acquireViaAutomation({
    required int accountId,
    required String email,
    required String password,
    required String profileDir,
    String? imapHost,
    String? imapUser,
    String? imapPass,
  }) async {
    final args = [
      _pythonRunner.scriptFile,
      'jagex-auth',
      '--email', email,
      '--profile-dir', jagexHomeDir(profileDir),
      if (imapHost != null) ...['--imap-host', imapHost],
    ];
    _pythonRunner.logCommand(args);

    final env = <String, String>{
      'CC_ACCOUNT_PASS': password,
      if (imapUser != null) 'CC_IMAP_USER': imapUser,
      if (imapPass != null) 'CC_IMAP_PASS': imapPass,
    };

    final raw = await _pythonRunner.run(
      args,
      workingDirectory: _pythonRunner.scriptsPath,
      timeout: const Duration(minutes: 5),
      environment: env,
    );

    final result = ResultParser.processScriptOutput(
      exitCode: raw.exitCode,
      stdout: raw.stdout,
      stderr: raw.stderr,
      onLog: (msg) => logger.i('[JagexToken] $msg'),
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception('jagex-auth automation failed: ${result.message}');
    }

    final refreshToken = result.data!['refresh_token'] as String?;
    final characterId = result.data!['character_id'] as String?;
    final displayName = result.data!['display_name'] as String?;

    if (refreshToken == null || characterId == null || displayName == null) {
      throw Exception('jagex-auth returned incomplete data: ${result.data}');
    }

    await _db.accountRepository.updateJagexToken(
      accountId: accountId,
      refreshToken: refreshToken,
      characterId: characterId,
      displayName: displayName,
    );

    logger.i('[JagexToken] Token stored in DB and credentials file written');
  }
}
```

- [ ] **Step 4: Run the tests — they should now pass**

```bash
flutter test test/config/services/jagex/jagex_token_service_test.dart -v
```
Expected: all 3 tests pass.

- [ ] **Step 5: Run full suite**

```bash
flutter test
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/config/services/jagex/jagex_token_service.dart \
        test/config/services/jagex/jagex_token_service_test.dart
git commit -m "feat(jagex): add JagexTokenService for OAuth token lifecycle

Handles fast-path HTTP refresh (using stored refresh_token) and
slow-path Patchright browser auth (first-time or expired token).
Writes JX_* credentials.properties to bot-<id>/jagex/ before launch.
Stores refresh_token + character_id + display_name in the DB.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: MicrobotEngine — jagex.userhome Flag + Token Seeding

**Repo:** `command_center`

**Files:**
- Modify: `lib/config/services/bot_engine/microbot_engine.dart`
- Modify: `test/config/services/bot_engine/microbot_engine_test.dart`

Two changes:
1. Add `-Djagex.userhome=<profileDir>/jagex` to `buildLaunchArgs` so each bot process reads its own Jagex credentials.
2. Call `JagexTokenService.seedToken()` in `launch()` before writing the profile, so the credentials file is always fresh.

- [ ] **Step 1: Add the failing test for `jagex.userhome`**

In `test/config/services/bot_engine/microbot_engine_test.dart`, add inside the `MicrobotEngine` group:

```dart
    test('buildLaunchArgs includes -Djagex.userhome pointing to profileDir/jagex', () {
      final engine = _makeEngine(profilesBasePath: '/profiles');
      final args = engine.buildLaunchArgs(
        characterId: 42,
        proxyUrl: null,
        config: const LaunchConfig(scriptName: 'Test'),
      );
      expect(args, contains('-Djagex.userhome=/profiles/bot-42/jagex'));
    });
```

- [ ] **Step 2: Run the failing test**

```bash
flutter test test/config/services/bot_engine/microbot_engine_test.dart -v
```
Expected: `Expected: contains '-Djagex.userhome=/profiles/bot-42/jagex'` FAIL.

- [ ] **Step 3: Update `MicrobotEngine` constructor and `buildLaunchArgs`**

In `lib/config/services/bot_engine/microbot_engine.dart`:

Add `JagexTokenService` import at the top:
```dart
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
```

Add `_jagexTokenService` field and update constructor:
```dart
  final JagexTokenService _jagexTokenService;

  MicrobotEngine({
    required this.javaPath,
    required this.jarPath,
    required String profilesBasePath,
    required NativeCommandsService nativeCommands,
    required JagexTokenService jagexTokenService,
    required this.onLog,
    this.onOutdated,
  })  : _profileWriter =
            MicrobotProfileWriter(profilesBasePath: profilesBasePath),
        _nativeCommands = nativeCommands,
        _jagexTokenService = jagexTokenService;
```

In `buildLaunchArgs`, add after the `--cc-profile-dir` line:
```dart
    args.add('-Djagex.userhome=${p.join(profileDir, 'jagex')}');
```

In `launch()`, call `seedToken` before `writeProfile`:
```dart
    await _jagexTokenService.seedToken(
      accountId: characterId, // NOTE: accountId not available here — see Step 4
      email: email,
      password: password,
      profileDir: _profileWriter.profilePath(characterId: characterId),
    );
    await _profileWriter.writeProfile(...);
```

**Important:** `launch()` receives `email` and `password` but not `accountId`. The `accountId` is needed for DB lookup. Update the `BotEngine` interface and `launch()` signature to include `accountId`.

- [ ] **Step 4: Add `accountId` to `BotEngine.launch()` signature**

In `lib/config/services/bot_engine/bot_engine.dart`, update the `launch` method signature:
```dart
  Future<LaunchResult> launch({
    required int characterId,
    required int accountId,        // ADD THIS
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  });
```

In `lib/config/services/bot_engine/microbot_engine.dart`, update `launch()`:
```dart
  @override
  Future<LaunchResult> launch({
    required int characterId,
    required int accountId,        // ADD THIS
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  }) async {
    await _jagexTokenService.seedToken(
      accountId: accountId,
      email: email,
      password: password,
      profileDir: _profileWriter.profilePath(characterId: characterId),
    );
    await _profileWriter.writeProfile(
      characterId: characterId,
      email: email,
      password: password,
      world: config.world,
      scriptName: config.scriptName,
      scriptParams: config.scriptParams,
    );
    // ... rest of method unchanged ...
```

- [ ] **Step 5: Update all callers of `launch()` to pass `accountId`**

Search for all calls to `_botEngine.launch(` or `botEngine.launch(`:

```bash
grep -rn "\.launch(" lib/ --include="*.dart" | grep -v "// " | grep -v test
```

Update each call site to add `accountId:`. Known call sites:
- `lib/config/services/watchdog/watchdog_handlers.dart` line ~113: `_botEngine.launch(characterId: ..., characterName: ...` — add `accountId: client.accountId,`
- `lib/feature/Status/controller/status_controller.dart` — add `accountId: account.id!,`

- [ ] **Step 6: Update the mock in `microbot_engine_test.dart`**

The test uses `_makeEngine()` factory. Update it to pass a stub `JagexTokenService`. The file already imports `package:mocktail/mocktail.dart` — add the new mock class alongside the existing `_MockNativeCommands`:

```dart
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
// (mocktail/mocktail.dart is already imported in this test file)

class _MockJagexTokenService extends Mock implements JagexTokenService {}

MicrobotEngine _makeEngine({
  String jarPath = '/app/microbot-shaded.jar',
  String profilesBasePath = '/profiles',
}) {
  return MicrobotEngine(
    javaPath: '/java/bin/java.exe',
    jarPath: jarPath,
    profilesBasePath: profilesBasePath,
    nativeCommands: _MockNativeCommands(),
    jagexTokenService: _MockJagexTokenService(),
    onLog: (_) {},
  );
}
```

- [ ] **Step 7: Run all bot engine tests**

```bash
flutter test test/config/services/bot_engine/ -v
```
Expected: all tests pass including the new `jagex.userhome` test.

- [ ] **Step 8: Run full suite**

```bash
flutter test
```
Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/config/services/bot_engine/microbot_engine.dart \
        lib/config/services/bot_engine/bot_engine.dart \
        lib/config/services/watchdog/watchdog_handlers.dart \
        lib/feature/Status/controller/status_controller.dart \
        test/config/services/bot_engine/microbot_engine_test.dart
git commit -m "feat(engine): add jagex.userhome JVM flag and pre-launch token seeding

Each bot process now gets -Djagex.userhome=<profileDir>/jagex so the
game client reads its own isolated Jagex credentials. JagexTokenService
is called before each launch to ensure a fresh game session token is
written. Adds accountId to launch() signature so the service can look
up stored OAuth tokens in the DB.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: AutomationService — Store Token After Account Creation

**Repo:** `command_center`

**Files:**
- Modify: `lib/config/services/automation/automation_service.dart`

After an account is created via Patchright, immediately call `jagex-auth` to acquire and store the OAuth token so the first launch never needs to do a slow browser auth.

- [ ] **Step 1: Inject `JagexTokenService` into `AutomationService`**

`AutomationService` is a `GetxService`. In `createAccount`'s `body` lambda, after `_persistAccount` succeeds, add token acquisition. Use `Get.find<JagexTokenService>()` — no constructor change needed since it's lazy-loaded from DI.

- [ ] **Step 2: Update `_persistAccount` to return the inserted account ID**

In `automation_service.dart`, change `_persistAccount` return type from `Future<void>` to `Future<int?>`:

```dart
  Future<int?> _persistAccount(
      Map<String, dynamic> data, ProxySlotEntity slot) async {
    try {
      final db = Get.find<DatabaseService>();
      final accountName = data['accountName'] ?? '';
      final account = AccountEntity(
        accountName: accountName,
        email: data['email'] ?? '',
        password: data['password'] ?? '',
        birthday: data['dob'] ?? '',
        proxySlotId: slot.id,
        characters: accountName.isNotEmpty
            ? [
                CharacterEntity(
                  accountId: 0,
                  name: accountName,
                  banned: false,
                  actualSkills: SkillsEntity.empty(),
                  targetSkills: SkillsEntity.empty(),
                ),
              ]
            : const [],
      );
      final id = await db.accountRepository.insertAccount(account);
      _log('Account persisted to database with ID: $id');
      return id;
    } catch (e) {
      _log('Warning: Failed to persist account to database: $e');
      return null;
    }
  }
```

- [ ] **Step 3: Add token acquisition call in `createAccount`**

Replace the existing call in `createAccount`'s `body` lambda:

```dart
          if (result.isAccountCreated && result.data != null) {
            _log('Account email: ${result.data!['email'] ?? 'N/A'}');
            final accountId = await _persistAccount(result.data!, slot);

            // Acquire and store Jagex OAuth token immediately so first
            // launch uses HTTP refresh instead of slow browser auth.
            if (accountId != null) {
              try {
                final tokenService = Get.find<JagexTokenService>();
                final imapHost = await Get.find<ImapConfigService>().getHost();
                final imapUser = await Get.find<ImapConfigService>().getUser();
                final imapPass = await Get.find<ImapConfigService>().getPass();
                // Use a temp dir — seedToken writes to profileDir/jagex/
                // We only need the DB write here; the real dir is created at launch.
                final tempProfileDir = Directory.systemTemp.createTempSync('jagex_auth_').path;
                try {
                  await tokenService.seedToken(
                    accountId: accountId,
                    email: result.data!['email'] ?? '',
                    password: result.data!['password'] ?? '',
                    profileDir: tempProfileDir,
                    imapHost: imapHost,
                    imapUser: imapUser,
                    imapPass: imapPass,
                  );
                  _log('Jagex token acquired and stored for account $accountId');
                } finally {
                  Directory(tempProfileDir).deleteSync(recursive: true);
                }
              } catch (e) {
                _log('Warning: Failed to acquire Jagex token: $e (will retry at first launch)');
              }
            }
          }
```

Add the import at the top of `automation_service.dart`:
```dart
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
```

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/automation/automation_service.dart
git commit -m "feat(automation): acquire Jagex token immediately after account creation

After a new account is persisted, calls JagexTokenService.seedToken() to
run the Patchright OAuth flow and store the refresh_token in the DB.
This ensures the first bot launch uses the fast HTTP refresh path instead
of triggering a full browser session, reducing launch latency.
Failures are non-fatal — the token is acquired at launch as fallback.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: DI — Register JagexTokenService

**Repo:** `command_center`

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart`

`JagexTokenService` depends on `DatabaseService` (Phase 2) and needs a `PythonRunner`. It must be registered after `DatabaseService` is ready.

- [ ] **Step 1: Add import to `dependency_injection.dart`**

```dart
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
import 'package:command_center/config/services/automation/python_runner.dart';
```

- [ ] **Step 2: Register in `initializeAsyncServices()`**

Add after `NotificationService` registration (step 8), before `MicrobotSetupService` (step 9):

```dart
    Get.lazyPut<JagexTokenService>(
      () => JagexTokenService(
        db: Get.find<DatabaseService>(),
        pythonRunner: PythonRunner(onLog: (msg) => logger.i('[JagexToken] $msg')),
      ),
      fenix: true,
    );
```

- [ ] **Step 3: Update `MicrobotEngine` construction in Phase 3**

Find where `MicrobotEngine` is constructed (in `initializePostSetup()` or wherever `BotEngine` is instantiated), and add `jagexTokenService: Get.find<JagexTokenService>()`:

```dart
    final engine = MicrobotEngine(
      javaPath: javaPath,
      jarPath: jarPath,
      profilesBasePath: profilesBasePath,
      nativeCommands: Get.find<NativeCommandsService>(),
      jagexTokenService: Get.find<JagexTokenService>(),
      onLog: (msg) => logger.i(msg),
      onOutdated: () { /* ... existing handler ... */ },
    );
```

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```
Expected: all tests pass.

- [ ] **Step 5: Build to verify no compile errors**

```bash
flutter build windows --debug 2>&1 | tail -20
```
Expected: `Building Windows application...` completes without errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/resource/dependency_injection.dart
git commit -m "feat(di): register JagexTokenService in Phase 2 async init

JagexTokenService registered as lazy fenix after DatabaseService is
available. MicrobotEngine construction updated to receive the service
via DI.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

### Spec Coverage Check

| Requirement | Covered by |
|------------|-----------|
| Bot stuck at login — no Enter press | Task 1 (AutoLoginPlugin) |
| Jagex OAuth — credential file format | Task 3 (jagex_auth.py) + Task 4 (writeCredentialsFile) |
| Per-instance token isolation (no shared ~/.runelite) | Task 5 (-Djagex.userhome flag) |
| Token storage in DB (refresh_token, character_id, display_name) | Task 2 (DB migration) |
| Fast HTTP refresh path for every launch | Task 4 (JagexTokenService._httpRefreshIdToken) |
| Slow browser auth for first-time / expired tokens | Task 3 (jagex_auth.py) + Task 4 (_acquireViaAutomation) |
| IMAP email verification support | Task 3 (jagex_auth.py) |
| Token acquired on account creation | Task 6 (AutomationService) |
| DI wiring | Task 7 |

### Placeholder Scan

No TBD, TODO, "implement later", or "similar to" references found.

### Signature Verification (confirmed against actual source)

| Call site | Actual signature | Plan uses |
|-----------|-----------------|-----------|
| `launch_browser(...)` | `(proxy_url, headless) → (pw, browser, context, page)` | ✓ 4-tuple unpack, no `log_fn` |
| `close_browser(...)` | `(pw: Playwright, browser: Browser)` | ✓ both args |
| `fetch_verification_code(...)` | `(imap_host, imap_user, imap_pass, target_email, timeout=120, log_fn)` | ✓ `target_email=email`, `timeout=120` |
| `human_type(...)` | `(page, selector, text)` — already calls `page.click()` | ✓ no pre-click |
| `AutomationResult(status=...)` | `status: str` | ✓ `.value` used on all enum members |
| `PythonRunner.run(...)` | returns `({exitCode, stdout, stderr})` | ✓ |
| `AutomationResult.isSuccess` | getter exists | ✓ |
| `PythonRunner.logCommand()` | exists | ✓ |

### Type Consistency

- `JagexTokenService.seedToken()` signature is used identically in Task 4 (definition), Task 5 (MicrobotEngine calls it), and Task 6 (AutomationService calls it).
- `AccountRepository.updateJagexToken()` signature defined in Task 2 (interface + implementation) and called in Task 4 (`_acquireViaAutomation`).
- `launch()` now includes `accountId: int` — Task 5 adds it to the interface and updates all 2 call sites (watchdog_handlers + status_controller).
- `_persistAccount` changed to return `Future<int?>` in Task 6 only — confirm no other callers exist: `grep -n "_persistAccount" lib/config/services/automation/automation_service.dart` (should show only 1 call site in `createAccount`).
