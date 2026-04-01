# Critical Bugs Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 critical bugs found during the March 2026 codebase audit — JAR download data loss, missing DB transactions, PID tracking gaps, silently dropped scriptParams, and wrong-storage-layer reset.

**Architecture:** Each bug is an independent fix. All follow TDD — write a failing test first, then fix the production code. No architectural changes; these are surgical fixes to existing files.

**Tech Stack:** Flutter/Dart, Drift ORM, GetX, flutter_test, mockito

---

### Task 1: JAR Download — Atomic `.tmp` Rename

The JAR downloader writes directly to `microbot-shaded.jar`. If the download fails mid-stream, the catch block deletes the partial file and returns `existingPath` — but `existingPath` points to the same file that was just deleted. The caller gets a path to a non-existent file.

**Fix:** Download to `.tmp`, verify, then atomic rename. On failure, delete only the `.tmp` file and return the original intact JAR.

**Files:**
- Modify: `lib/config/services/bot_engine/microbot_jar_downloader.dart:74-109`
- Test: `test/config/services/bot_engine/microbot_jar_downloader_test.dart`

- [ ] **Step 1: Verify the fix manually (no unit test — ensureJar requires network I/O)**

`ensureJar()` depends on real HTTP calls to GitHub and `AppConfigService` state. Mocking these would require refactoring the class to accept injectable dependencies, which is out of scope for this bugfix. The fix is verified by code review: the `.tmp` download pattern is a well-known atomic-write idiom. No new test is added for this task — the existing static helper tests remain.

**Code review verification checklist:**
- Downloads go to `$jarPath.tmp`, never to `jarPath` directly
- `File(tmpPath).rename(jarPath)` is called only after successful stream completion
- Catch block deletes only `.tmp`, never touches the existing JAR
- Fallback returns `null` if `existingPath` file doesn't exist (instead of a dangling path)

- [ ] **Step 2: Fix the production code — atomic `.tmp` download**

In `lib/config/services/bot_engine/microbot_jar_downloader.dart`, replace the download block (lines 74-109):

```dart
    // Download to .tmp first for atomic rename — never corrupt the existing JAR
    final jarPath = p.join(microbotDir, 'microbot-shaded.jar');
    final tmpPath = '$jarPath.tmp';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      // Private repo assets require Bearer token + octet-stream accept
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/octet-stream');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'JAR download failed with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(tmpPath).openWrite();
      try {
        await for (final chunk in response) {
          file.add(chunk);
          downloadedBytes += chunk.length;
          onProgress?.call(downloadedBytes, totalBytes);
        }
      } finally {
        await file.close();
      }

      // Atomic rename: .tmp → final path (old JAR is overwritten)
      await File(tmpPath).rename(jarPath);
    } catch (e) {
      logger.e('Failed to download Microbot JAR: $e');
      // Clean up .tmp only — existing JAR is untouched
      final partial = File(tmpPath);
      if (partial.existsSync()) await partial.delete();
      // Return existing JAR if it still exists, otherwise null
      if (existingPath != null && File(existingPath).existsSync()) {
        return existingPath;
      }
      return null;
    } finally {
      client.close();
    }
```

Key changes:
- Downloads to `$jarPath.tmp` instead of `jarPath` directly
- Atomic `File.rename()` after successful download
- On failure, deletes only `.tmp`, existing JAR is never touched
- If `existingPath` file doesn't exist, returns `null` instead of a dangling path

- [ ] **Step 3: Run all JAR downloader tests (existing tests must still pass)**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/microbot_jar_downloader_test.dart -v`
Expected: All PASS

- [ ] **Step 4: Commit**

```
git add lib/config/services/bot_engine/microbot_jar_downloader.dart
git commit -m "fix(bot-engine): atomic .tmp download for JAR to prevent data loss on failure"
```

---

### Task 2: `updateAccount` — Transaction + Upsert Characters

`updateAccount` deletes all characters then re-inserts them without a transaction. A crash between DELETE and INSERT loses all characters. Also, the delete+re-insert destroys character IDs that the watchdog uses for process tracking.

**Fix:** Wrap in a `_db.transaction()`. Upsert characters (update existing by ID, insert new ones) instead of delete-all + re-insert.

**Files:**
- Modify: `lib/data/repositories/account_repository_impl.dart:84-110`
- Test: `test/data/repositories/account_repository_impl_test.dart`

- [ ] **Step 1: Write failing test — updateAccount preserves character IDs**

Add to `test/data/repositories/account_repository_impl_test.dart` inside the `'Characters'` group:

```dart
test('updateAccount preserves existing character IDs', () async {
  final id = await repo.insertAccount(
    _makeAccount(
      email: 'preserve@test.com',
      characters: [_makeCharacter(name: 'Keeper')],
    ),
  );

  final original = await repo.getAccountById(id);
  final originalCharId = original!.characters.first.id;
  expect(originalCharId, isNotNull);

  // Update account with same character (has the ID set)
  await repo.updateAccount(
    original.copyWith(
      characters: [original.characters.first.copyWith(name: 'Renamed')],
    ),
  );

  final updated = await repo.getAccountById(id);
  expect(updated!.characters.first.id, equals(originalCharId),
      reason: 'Character ID must be preserved across updates');
  expect(updated.characters.first.name, equals('Renamed'));
});
```

- [ ] **Step 2: Run test to verify it FAILS**

Run: `cd /mnt/c/Projects/command_center && flutter test test/data/repositories/account_repository_impl_test.dart --name "preserves existing character IDs" -v`
Expected: FAIL — current delete+re-insert generates a new ID

- [ ] **Step 3: Write failing test — updateAccount is transactional**

Add to the same group:

```dart
test('updateAccount adds new characters alongside existing ones', () async {
  final id = await repo.insertAccount(
    _makeAccount(
      email: 'addchar@test.com',
      characters: [_makeCharacter(name: 'Original')],
    ),
  );

  final original = await repo.getAccountById(id);
  final existingChar = original!.characters.first;

  // Update with existing + new character
  await repo.updateAccount(
    original.copyWith(
      characters: [
        existingChar, // keep existing
        _makeCharacter(name: 'NewChar'), // add new (no ID)
      ],
    ),
  );

  final updated = await repo.getAccountById(id);
  expect(updated!.characters.length, equals(2));
  expect(updated.characters.any((c) => c.name == 'Original'), isTrue);
  expect(updated.characters.any((c) => c.name == 'NewChar'), isTrue);
  // Existing character ID preserved
  expect(
    updated.characters.firstWhere((c) => c.name == 'Original').id,
    equals(existingChar.id),
  );
});
```

- [ ] **Step 4: Run test to verify it FAILS**

Run: `cd /mnt/c/Projects/command_center && flutter test test/data/repositories/account_repository_impl_test.dart --name "adds new characters alongside" -v`
Expected: FAIL

- [ ] **Step 5: Implement the fix — transaction + upsert**

Replace `updateAccount` in `lib/data/repositories/account_repository_impl.dart` (lines 84-110):

```dart
  @override
  Future<void> updateAccount(AccountEntity account) async {
    if (account.id == null) {
      throw ArgumentError('Cannot update account without an id');
    }

    await _db.transaction(() async {
      // Update account fields
      await (_db.update(_db.accountsTable)
            ..where((tbl) => tbl.id.equals(account.id!)))
          .write(
        AccountsTableCompanion(
          accountName: Value(account.accountName),
          birthday: Value(account.birthday),
          email: Value(account.email),
          password: Value(account.password),
          proxySlotId: Value(account.proxySlotId),
          lastUpdated: Value(DateTime.now()),
        ),
      );

      // Upsert characters: update existing (have ID), insert new (no ID)
      final incomingIds = account.characters
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toSet();

      // Delete characters that are no longer in the list
      final existingChars = await (_db.select(_db.charactersTable)
            ..where((tbl) => tbl.accountId.equals(account.id!)))
          .get();
      for (final existing in existingChars) {
        if (!incomingIds.contains(existing.id)) {
          await (_db.delete(_db.charactersTable)
                ..where((tbl) => tbl.id.equals(existing.id)))
              .go();
        }
      }

      // Update existing characters, insert new ones
      for (final character in account.characters) {
        if (character.id != null) {
          await (_db.update(_db.charactersTable)
                ..where((tbl) => tbl.id.equals(character.id!)))
              .write(CharactersTableCompanion(
            name: Value(character.name),
            banned: Value(character.banned),
            defaultScriptName: Value(character.defaultScriptName),
            actualSkillsJson:
                Value(jsonEncode(character.actualSkills.toJson())),
            targetSkillsJson:
                Value(jsonEncode(character.targetSkills.toJson())),
            lastUpdated: Value(DateTime.now()),
          ));
        } else {
          await _insertCharacter(
              character.copyWith(accountId: account.id));
        }
      }
    });
  }
```

- [ ] **Step 6: Run all account repository tests**

Run: `cd /mnt/c/Projects/command_center && flutter test test/data/repositories/account_repository_impl_test.dart -v`
Expected: All PASS (including existing "updateAccount replaces characters" test — it passes because the old character has no ID, so it's inserted as new, and the old one is deleted since it's not in the incoming list)

- [ ] **Step 7: Commit**

```
git add lib/data/repositories/account_repository_impl.dart test/data/repositories/account_repository_impl_test.dart
git commit -m "fix(data): wrap updateAccount in transaction + upsert characters to preserve IDs"
```

---

### Task 3: Recaptured PIDs — Register in Engine

When the watchdog recaptures running bot processes on startup, it builds `TrackedClient` objects but never registers the PIDs in `MicrobotEngine._activePids` or `_pidToCharacterId`. This means `stop()` can't find the characterId to clean up profile directories.

**Fix:** Add a `registerRecapturedPid` method to `BotEngine` and `MicrobotEngine`. Call it from `WatchdogHandlers.recaptureRunningClients`.

**Files:**
- Modify: `lib/config/services/bot_engine/bot_engine.dart`
- Modify: `lib/config/services/bot_engine/microbot_engine.dart`
- Modify: `lib/config/services/watchdog/watchdog_handlers.dart:194-208`
- Test: `test/config/services/bot_engine/microbot_engine_test.dart`

- [ ] **Step 1: Write failing test — registerRecapturedPid tracks PID**

Add to `test/config/services/bot_engine/microbot_engine_test.dart`:

```dart
test('registerRecapturedPid adds PID to activePids', () {
  final engine = _makeEngine();
  engine.registerRecapturedPid(pid: 1234, characterId: 42);
  expect(engine.activePids, contains(1234));
});
```

- [ ] **Step 2: Run test to verify it FAILS**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/microbot_engine_test.dart --name "registerRecapturedPid" -v`
Expected: FAIL — method does not exist

- [ ] **Step 3: Add `registerRecapturedPid` to BotEngine interface**

In `lib/config/services/bot_engine/bot_engine.dart`, add before the closing brace:

```dart
  /// Register an externally-discovered PID (e.g. recaptured on startup).
  /// Enables stop() to clean up profiles for processes the engine didn't launch.
  void registerRecapturedPid({required int pid, required int characterId});
```

- [ ] **Step 4: Implement in MicrobotEngine**

In `lib/config/services/bot_engine/microbot_engine.dart`, add after the `cleanStaleProfiles` method:

```dart
  @override
  void registerRecapturedPid({required int pid, required int characterId}) {
    _activePids.add(pid);
    _pidToCharacterId[pid] = characterId;
  }
```

- [ ] **Step 5: Run test to verify it PASSES**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/microbot_engine_test.dart -v`
Expected: All PASS

- [ ] **Step 6: Wire recapture to call registerRecapturedPid**

In `lib/config/services/watchdog/watchdog_handlers.dart`, inside `recaptureRunningClients`, add after line 207 (`recapturedCharacterIds.add(characterId);`):

```dart
        _botEngine.registerRecapturedPid(
          pid: process.processId,
          characterId: characterId,
        );
```

- [ ] **Step 7: Run all engine tests**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/ -v`
Expected: All PASS

- [ ] **Step 8: Commit**

```
git add lib/config/services/bot_engine/bot_engine.dart lib/config/services/bot_engine/microbot_engine.dart lib/config/services/watchdog/watchdog_handlers.dart test/config/services/bot_engine/microbot_engine_test.dart
git commit -m "fix(watchdog): register recaptured PIDs in engine for profile cleanup on stop"
```

---

### Task 4: `scriptParams` — Forward to Profile Writer and Engine Args

`LaunchConfig.scriptParams` is collected from the user in the launch dialog but never forwarded to `MicrobotProfileWriter.writeProfile()` or `MicrobotEngine.buildLaunchArgs()`. The bot starts without the user's script parameters.

**Fix:** Add `scriptParams` to `writeProfile()` so it's written to `commandcenter.properties`. Also pass it in `buildLaunchArgs` as `--script-params`.

**Files:**
- Modify: `lib/config/services/bot_engine/microbot_profile_writer.dart:13-36`
- Modify: `lib/config/services/bot_engine/microbot_engine.dart:41-47`
- Test: `test/config/services/bot_engine/microbot_profile_writer_test.dart`
- Test: `test/config/services/bot_engine/microbot_engine_test.dart`

- [ ] **Step 1: Write failing test — scriptParams written to properties file**

Add to `test/config/services/bot_engine/microbot_profile_writer_test.dart`:

```dart
test('writeProfile writes scriptParams to commandcenter.properties', () async {
  await writer.writeProfile(
    characterId: 10,
    email: 'sp@test.com',
    password: 'pass',
    world: 'auto',
    scriptName: 'Fisher',
    scriptParams: '1,2,3',
  );

  final settings = File(p.join(tempDir.path, 'bot-10', 'commandcenter.properties'));
  final content = settings.readAsStringSync();
  expect(content, contains('scriptParams=1,2,3'));
});
```

- [ ] **Step 2: Run test to verify it FAILS**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/microbot_profile_writer_test.dart --name "scriptParams" -v`
Expected: FAIL — `scriptParams` parameter does not exist on `writeProfile`

- [ ] **Step 3: Write failing test — buildLaunchArgs includes scriptParams**

Add to `test/config/services/bot_engine/microbot_engine_test.dart`:

```dart
test('buildLaunchArgs includes --script-params when scriptParams is non-empty', () {
  final engine = _makeEngine();
  final args = engine.buildLaunchArgs(
    characterId: 1,
    proxyUrl: null,
    config: const LaunchConfig(scriptName: 'Test', scriptParams: '1,2,3'),
  );
  expect(args, contains('--script-params=1,2,3'));
});

test('buildLaunchArgs omits --script-params when scriptParams is empty', () {
  final engine = _makeEngine();
  final args = engine.buildLaunchArgs(
    characterId: 1,
    proxyUrl: null,
    config: const LaunchConfig(scriptName: 'Test', scriptParams: ''),
  );
  expect(args.any((a) => a.startsWith('--script-params')), isFalse);
});
```

- [ ] **Step 4: Run test to verify it FAILS**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/microbot_engine_test.dart --name "script-params" -v`
Expected: FAIL

- [ ] **Step 5: Add `scriptParams` to `writeProfile` signature and body**

In `lib/config/services/bot_engine/microbot_profile_writer.dart`, modify `writeProfile`:

```dart
  Future<void> writeProfile({
    required int characterId,
    required String email,
    required String password,
    required String world,
    required String scriptName,
    String scriptParams = '',
  }) async {
    final dir = Directory(profilePath(characterId: characterId));
    await dir.create(recursive: true);

    final settings = StringBuffer();
    if (world != 'auto' && world.isNotEmpty) {
      settings.writeln('world=$world');
    }
    settings.writeln('script=$scriptName');
    if (scriptParams.isNotEmpty) {
      settings.writeln('scriptParams=$scriptParams');
    }
    await File(p.join(dir.path, 'commandcenter.properties'))
        .writeAsString(settings.toString());

    final credentials = StringBuffer();
    credentials.writeln('email=$email');
    credentials.writeln('password=$password');
    await File(p.join(dir.path, 'credentials.properties'))
        .writeAsString(credentials.toString());
  }
```

- [ ] **Step 6: Pass scriptParams from MicrobotEngine.launch()**

In `lib/config/services/bot_engine/microbot_engine.dart`, update the `_profileWriter.writeProfile` call (lines 41-47):

```dart
    await _profileWriter.writeProfile(
      characterId: characterId,
      email: email,
      password: password,
      world: config.world,
      scriptName: config.scriptName,
      scriptParams: config.scriptParams,
    );
```

- [ ] **Step 7: Add --script-params to buildLaunchArgs**

In `lib/config/services/bot_engine/microbot_engine.dart`, inside `buildLaunchArgs`, add after the `--safe-mode` line (line 131):

```dart
    if (config.scriptParams.isNotEmpty) {
      args.add('--script-params=${config.scriptParams}');
    }
```

- [ ] **Step 8: Run all profile writer and engine tests**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/bot_engine/ -v`
Expected: All PASS

- [ ] **Step 9: Commit**

```
git add lib/config/services/bot_engine/microbot_profile_writer.dart lib/config/services/bot_engine/microbot_engine.dart test/config/services/bot_engine/microbot_profile_writer_test.dart test/config/services/bot_engine/microbot_engine_test.dart
git commit -m "fix(bot-engine): forward scriptParams to profile writer and launch args"
```

---

### Task 5: `resetOnboarding` — Fix Wrong Storage Layer

`resetOnboarding()` calls `prefs.remove('webshare_api_key')` which targets SharedPreferences, but the Webshare API key is stored in SQLite via `AppConfigService`. The reset is a no-op for the API key.

**Fix:** Call `AppConfigService.clearWebshareApiKey()` instead. Also remove the SharedPreferences-based `webshare_api_key` removal since that key was never stored there.

**Files:**
- Modify: `lib/config/services/onboarding_service.dart:156-166`
- Test: (no existing test file — create one)
- Create: `test/config/services/onboarding_service_test.dart`

- [ ] **Step 1: Write failing test — resetOnboarding clears the correct storage**

Create `test/config/services/onboarding_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/onboarding_service.dart';

void main() {
  group('OnboardingService', () {
    test('resetOnboarding resets all observable flags to false', () async {
      final service = OnboardingService();

      // Manually set flags to true to simulate configured state
      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isTrue);

      await service.resetOnboarding();

      expect(service.isWebshareConfigured.value, isFalse);
      expect(service.isIpqsConfigured.value, isFalse);
      expect(service.isInitialSyncComplete.value, isFalse);
      expect(service.isOnboardingComplete, isFalse);
    });

    test('isOnboardingComplete requires all three flags', () {
      final service = OnboardingService();

      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isInitialSyncComplete.value = false;
      expect(service.isOnboardingComplete, isFalse);

      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it PASSES (baseline — observable flags do reset)**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/onboarding_service_test.dart -v`
Expected: PASS (the observable flags DO reset; the bug is that SharedPreferences gets wrong key removed instead of SQLite)

- [ ] **Step 3: Fix resetOnboarding — remove the wrong-layer SharedPreferences call**

In `lib/config/services/onboarding_service.dart`, replace `resetOnboarding()` (lines 156-166):

```dart
  /// Reset onboarding (for debugging or re-setup)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_webshareConfiguredKey);
    await prefs.remove(_ipqsConfiguredKey);
    await prefs.remove(_initialSyncCompleteKey);

    // Clear the actual API keys from their source-of-truth storage
    // Webshare key lives in SQLite via AppConfigService
    try {
      final appConfig = Get.find<AppConfigService>();
      await appConfig.clearWebshareApiKey();
    } catch (_) {
      // AppConfigService may not be registered in test/debug scenarios
    }

    // IPQS key lives in SQLite via IpqsService
    try {
      final ipqs = Get.find<IpqsService>();
      await ipqs.clearApiKey();
    } catch (_) {
      // IpqsService may not be registered in test/debug scenarios
    }

    isWebshareConfigured.value = false;
    isIpqsConfigured.value = false;
    isInitialSyncComplete.value = false;
  }
```

- [ ] **Step 4: Verify IpqsService.clearApiKey() already exists**

`IpqsService.clearApiKey()` already exists at line 70 of `lib/config/services/ipqs/ipqs_service.dart` — returns `Future<Result<void>>`. No changes needed to that file. The `await ipqs.clearApiKey()` call in `resetOnboarding` simply discards the `Result`, which is acceptable for a reset operation.

- [ ] **Step 5: Add the AppConfigService import to onboarding_service.dart**

In `lib/config/services/onboarding_service.dart`, add this import:

```dart
import 'package:command_center/config/services/app_config_service.dart';
```

(`IpqsService` and `Get` imports already exist.)

- [ ] **Step 6: Run onboarding tests**

Run: `cd /mnt/c/Projects/command_center && flutter test test/config/services/onboarding_service_test.dart -v`
Expected: All PASS

- [ ] **Step 7: Run full test suite to check for regressions**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All tests pass

- [ ] **Step 8: Commit**

```
git add lib/config/services/onboarding_service.dart test/config/services/onboarding_service_test.dart
git commit -m "fix(onboarding): resetOnboarding now clears API keys from SQLite, not SharedPreferences"
```

---

### Final: Run Full Test Suite

- [ ] **Step 1: Run all tests**

Run: `cd /mnt/c/Projects/command_center && flutter test`
Expected: All pass, no regressions

- [ ] **Step 2: Verify no analyzer warnings in changed files**

Run: `cd /mnt/c/Projects/command_center && dart analyze lib/config/services/bot_engine/ lib/data/repositories/account_repository_impl.dart lib/config/services/onboarding_service.dart lib/config/services/watchdog/watchdog_handlers.dart`
Expected: No issues found
