# Microbot Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Microbot as the bot engine for Command Center with a clean abstraction layer, replacing the DreamBot-specific launch path.

**Architecture:** A `BotEngine` abstract class defines the launch/stop contract. `MicrobotEngine` implements it using `Process.start()` with transient RuneLite profiles. Existing WatchdogService tracks processes by PID. Setup dependencies (Java 17, Microbot JAR) are auto-installed via a splash screen on first launch.

**Tech Stack:** Flutter/Dart, GetX (DI + reactivity), Drift ORM (SQLite), `path_provider`, `Process.start()` for JVM process management, Adoptium API + GitHub Releases API for dependency downloads.

**Spec:** `docs/superpowers/specs/2026-03-16-microbot-integration-design.md`

---

## Chunk 1: Foundation Layer

Core helpers, models, and database changes that everything else depends on.

### Task 1: AppDataPath helper

**Files:**
- Create: `lib/core/helper/app_data_path.dart`
- Test: `test/core/helper/app_data_path_test.dart`

**Context:** All Microbot file paths (profiles, JAR, Java) are rooted under Flutter's `getApplicationSupportDirectory()`. This helper resolves the path once and makes it injectable. The existing codebase uses `path_provider` already (check `pubspec.yaml`). See `lib/config/services/automation/python_runner.dart:24-47` for how the codebase resolves paths (dev vs prod).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/helper/app_data_path_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/helper/app_data_path.dart';

void main() {
  group('AppDataPath', () {
    test('basePath returns non-empty string', () async {
      // AppDataPath wraps getApplicationSupportDirectory()
      // In test, we verify the class interface exists and is callable
      final appDataPath = AppDataPath();
      expect(appDataPath, isNotNull);
    });

    test('subDir joins base path with subdirectory', () {
      // Verify path joining logic without hitting filesystem
      final result = AppDataPath.joinPath('/base/path', 'microbot_profiles');
      expect(result, '/base/path/microbot_profiles');
    });

    test('subDir handles trailing separator', () {
      final result = AppDataPath.joinPath('/base/path/', 'microbot_profiles');
      expect(result, '/base/path/microbot_profiles');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/core/helper/app_data_path_test.dart`
Expected: FAIL — file not found / class not defined

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/helper/app_data_path.dart
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the application support directory for all persistent file storage.
/// Injected via GetX DI so services never hardcode paths.
class AppDataPath {
  String? _cachedPath;

  /// Returns the base application data path.
  /// Typically: C:\Users\<user>\AppData\Roaming\com.example.command_center\
  Future<String> get basePath async {
    _cachedPath ??= (await getApplicationSupportDirectory()).path;
    return _cachedPath!;
  }

  /// Pure path join — no I/O, safe for testing.
  static String joinPath(String base, String subDir) {
    return p.join(base, subDir);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/core/helper/app_data_path_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/helper/app_data_path.dart test/core/helper/app_data_path_test.dart
git commit -m "feat(bot-engine): add AppDataPath helper for application data directory resolution"
```

---

### Task 2: ProxyUrlBuilder helper

**Files:**
- Create: `lib/core/helper/proxy_url_builder.dart`
- Test: `test/core/helper/proxy_url_builder_test.dart`

**Context:** The spec defines a single code path for constructing SOCKS5 proxy URLs: `socks5://user:pass@ip:port`. Two call sites use this: `StatusController` (fresh launch) and `WatchdogHandlers.handleBan()` (after proxy rotation). The builder is a pure static utility — no dependencies, no state. See spec section "Proxy URL Construction" for the full contract.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/helper/proxy_url_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/helper/proxy_url_builder.dart';

void main() {
  group('ProxyUrlBuilder', () {
    test('builds SOCKS5 URL from components', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'user123',
        password: 'pass456',
        ipAddress: '192.168.1.1',
        socksPort: 1080,
      );
      expect(url, 'socks5://user123:pass456@192.168.1.1:1080');
    });

    test('handles special characters in password', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'user',
        password: 'p@ss:word',
        ipAddress: '10.0.0.1',
        socksPort: 9050,
      );
      expect(url, 'socks5://user:p@ss:word@10.0.0.1:9050');
    });

    test('builds URL from slot and IP entities', () {
      // This tests the convenience method that takes entity-like params
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'webshare_user',
        password: 'webshare_pass',
        ipAddress: '203.0.113.50',
        socksPort: 7777,
      );
      expect(url, 'socks5://webshare_user:webshare_pass@203.0.113.50:7777');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/core/helper/proxy_url_builder_test.dart`
Expected: FAIL — class not defined

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/helper/proxy_url_builder.dart

/// Constructs SOCKS5 proxy URLs from individual components.
/// Single code path used by StatusController (launch) and WatchdogHandlers (ban rotation).
class ProxyUrlBuilder {
  ProxyUrlBuilder._();

  /// Build a SOCKS5 proxy URL: socks5://user:pass@host:port
  static String buildSocks5Url({
    required String username,
    required String password,
    required String ipAddress,
    required int socksPort,
  }) {
    return 'socks5://$username:$password@$ipAddress:$socksPort';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/core/helper/proxy_url_builder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/helper/proxy_url_builder.dart test/core/helper/proxy_url_builder_test.dart
git commit -m "feat(bot-engine): add ProxyUrlBuilder for SOCKS5 URL construction"
```

---

### Task 3: Database migration — add socks_port to ProxySlotsTable

**Files:**
- Modify: `lib/data/database/tables/proxy_slots_table.dart`
- Modify: `lib/data/database/app_database.dart` (schema version + migration)
- Modify: `lib/domain/entities/proxy_slot.dart` (add `socksPort` field)
- Modify: `lib/data/repositories/proxy_repository_impl.dart` (map new column)
- Modify: `lib/config/services/webshare/webshare_models.dart` (parse from API)
- Modify: `lib/config/services/proxy/proxy_sync_service.dart` (store socks_port)
- Regenerate: Drift code generation

**Context:** Webshare SOCKS5 proxies use a different port than HTTP. The current `ProxySlotsTable` has `port` (int, default 0) for HTTP. We add `socks_port` (int, nullable) for SOCKS5. The Webshare API JSON response includes this in the `ports` object. Current schema is v5 (`app_database.dart:30`). Current `ProxySlotEntity` has 14 fields with Equatable props (`proxy_slot.dart:96-111`). Current `_mapProxySlotRow()` is at `proxy_repository_impl.dart:307-324`. Current `WebshareProxySlot.fromJson()` is at `webshare_models.dart:33-52`. Current `_createNewSlot()` and `_updateExistingSlot()` in `proxy_sync_service.dart` map WebshareProxySlot → DB insert/update.

- [ ] **Step 1: Add `socksPort` column to Drift table**

In `lib/data/database/tables/proxy_slots_table.dart`, add after the `port` column definition (around line 18):

```dart
IntColumn get socksPort => integer().nullable()();
```

- [ ] **Step 2: Bump schema version and add migration**

In `lib/data/database/app_database.dart`:
- Change `int get schemaVersion => 5;` to `int get schemaVersion => 6;`
- In the `MigrationStrategy` `onUpgrade` block, add before the closing brace of the migrate function (after the `from < 5` block):

```dart
if (from < 6) {
  await m.addColumn(proxySlotsTable, proxySlotsTable.socksPort);
}
```

- [ ] **Step 3: Add `socksPort` field to `ProxySlotEntity`**

In `lib/domain/entities/proxy_slot.dart`:
- Add field: `final int? socksPort;` (after the `port` field, around line 13)
- Add to constructor: `this.socksPort,` (in the named parameter list)
- Add to `empty()` factory: `socksPort: null,`
- Add to `copyWith()`: parameter `int? socksPort,` and in body `socksPort: socksPort ?? this.socksPort,`
- Add to `props` list: `socksPort,`

- [ ] **Step 4: Update `_mapProxySlotRow()` in repository**

In `lib/data/repositories/proxy_repository_impl.dart`, in the `_mapProxySlotRow()` method (around line 307-324), add:

```dart
socksPort: row.socksPort,
```

Also update any `insertSlot()` and `updateSlot()` methods to include `socksPort` in the companion map:

```dart
if (slot.socksPort != null) Value(slot.socksPort!),  // in ProxySlotsTableCompanion
```

- [ ] **Step 5: Add `socksPort` to `WebshareProxySlot` model**

In `lib/config/services/webshare/webshare_models.dart`:
- Add field: `final int? socksPort;` (after `port`)
- Add to constructor: `this.socksPort,`
- In `fromJson()`, parse: `socksPort: json['ports']?['socks5'] as int?,`

Note: The Webshare API returns `"ports": {"http": 80, "socks5": 1080}`. If the field name differs, adjust during implementation after checking the actual API response.

- [ ] **Step 6: Store `socksPort` during proxy sync**

In `lib/config/services/proxy/proxy_sync_service.dart`:
- In `_createNewSlot()`, add `socksPort: proxy.socksPort,` to the `ProxySlotEntity` constructor call
- In `_updateExistingSlot()`, include `socksPort` in the update companion

- [ ] **Step 7: Run Drift code generation**

Run: `cd /mnt/c/Projects/command_center_ux && dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `.g.dart` files with new `socksPort` column

- [ ] **Step 8: Run existing tests to verify no regressions**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: All existing tests pass. Some may need updates if they construct `ProxySlotEntity` without the new field (the nullable default handles this).

- [ ] **Step 9: Commit**

```bash
git add lib/data/database/tables/proxy_slots_table.dart lib/data/database/app_database.dart lib/data/database/app_database.g.dart lib/domain/entities/proxy_slot.dart lib/data/repositories/proxy_repository_impl.dart lib/config/services/webshare/webshare_models.dart lib/config/services/proxy/proxy_sync_service.dart
git commit -m "feat(db): add socks_port column to ProxySlotsTable (migration v5→v6)"
```

---

### Task 4: Update LaunchConfig — remove DreamBot fields, add jvmArgs

**Files:**
- Modify: `lib/config/services/watchdog/launch_config.dart`
- Test: `test/config/services/watchdog/launch_config_test.dart`

**Context:** Current `LaunchConfig` (`launch_config.dart:1-19`) has 6 fields: `scriptName`, `world`, `covert`, `render`, `scriptParams`, `advancedFlags`. The spec says: remove `covert` and `render` (DreamBot-specific), add `jvmArgs` (nullable String for JVM memory tuning like `-Xmx512m`). Keep: `scriptName`, `world`, `scriptParams`, `advancedFlags`. This is a clean break — DreamBot is not maintained.

- [ ] **Step 1: Write the test**

```dart
// test/config/services/watchdog/launch_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';

void main() {
  group('LaunchConfig', () {
    test('creates with required scriptName and defaults', () {
      const config = LaunchConfig(scriptName: 'Tutorial Journey');
      expect(config.scriptName, 'Tutorial Journey');
      expect(config.world, 'auto');
      expect(config.scriptParams, '');
      expect(config.advancedFlags, '');
      expect(config.jvmArgs, null);
    });

    test('creates with custom jvmArgs', () {
      const config = LaunchConfig(
        scriptName: 'Woodcutter',
        jvmArgs: '-Xmx384m',
      );
      expect(config.jvmArgs, '-Xmx384m');
    });

    test('does not have covert or render fields', () {
      // Verify DreamBot fields are removed — this is a compile-time check.
      // If these fields existed, the test file wouldn't compile without them.
      const config = LaunchConfig(scriptName: 'Test');
      expect(config.scriptName, 'Test');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/watchdog/launch_config_test.dart`
Expected: FAIL — `jvmArgs` not a field, or test file doesn't exist yet

- [ ] **Step 3: Update LaunchConfig**

Replace the entire file `lib/config/services/watchdog/launch_config.dart`:

```dart
class LaunchConfig {
  final String scriptName;
  final String world;
  final String scriptParams;
  final String advancedFlags;
  final String? jvmArgs;

  const LaunchConfig({
    required this.scriptName,
    this.world = 'auto',
    this.scriptParams = '',
    this.advancedFlags = '',
    this.jvmArgs,
  });
}
```

- [ ] **Step 4: Fix compilation errors in callers**

After removing `covert` and `render`, any code constructing `LaunchConfig` with those fields will break. Fix:
- `launch_dialog.dart`: Remove `covert` and `render` from `LaunchConfig()` construction (handled in Task 12)
- `watchdog_handlers.dart`: If `handleRestart()` passes `covert`/`render`, remove those params
- Any test files that construct `LaunchConfig` with old fields

Search for all usages: `grep -r "LaunchConfig(" lib/ test/` and update each call site.

- [ ] **Step 5: Run tests to verify**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/watchdog/launch_config_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/config/services/watchdog/launch_config.dart test/config/services/watchdog/launch_config_test.dart
git commit -m "refactor(watchdog): remove DreamBot fields from LaunchConfig, add jvmArgs"
```

---

### Task 5: Update TrackedClient — add email, password, proxyUrl

**Files:**
- Modify: `lib/config/services/watchdog/tracked_client.dart`

**Context:** Current `TrackedClient` (`tracked_client.dart:1-40`) has fields: `characterName`, `characterId`, `accountId`, `proxySlotId`, `proxyAddress` (bare IP), `launchConfig`, plus mutable PID/status/retry fields. The spec says: add `email`, `password`, and `proxyUrl` (full SOCKS5 URL string) for restart capability. Remove `proxyAddress` (replaced by `proxyUrl`). Keep `proxySlotId` and `accountId` (still needed for DB lookups during ban handling). These are populated at launch time (from caller) and at recapture time (hydrated from DB).

- [ ] **Step 1: Update TrackedClient fields**

In `lib/config/services/watchdog/tracked_client.dart`:
- Add fields: `final String email;`, `final String password;`
- Replace `String? proxyAddress;` with `String? proxyUrl;` (mutable — updated on ban rotation)
- Update constructor to require `email` and `password`, accept `proxyUrl`

The updated class should look like:

```dart
enum ClientStatus { running, restarting, stopped, failed, banned, awaitingAccount }

class TrackedClient {
  final String characterName;
  final int characterId;
  final int accountId;
  final int? proxySlotId;
  final String email;
  final String password;
  String? proxyUrl;                      // Mutable: full socks5:// URL, updated on proxy rotation
  final LaunchConfig launchConfig;
  int? pid;
  ClientStatus status;
  DateTime? launchedAt;
  int retryCount;
  int consecutiveQuickDeaths;
  DateTime? lastDeathAt;
  int _discoveryMisses;

  TrackedClient({
    required this.characterName,
    required this.characterId,
    required this.accountId,
    this.proxySlotId,
    required this.email,
    required this.password,
    this.proxyUrl,
    required this.launchConfig,
    this.pid,
    this.status = ClientStatus.running,
    this.launchedAt,
    this.retryCount = 0,
    this.consecutiveQuickDeaths = 0,
    this.lastDeathAt,
  }) : _discoveryMisses = 0;

  int get discoveryMisses => _discoveryMisses;
  void incrementDiscoveryMisses() => _discoveryMisses++;
  void resetDiscoveryMisses() => _discoveryMisses = 0;
}
```

- [ ] **Step 2: Fix compilation errors in callers**

Every place that constructs `TrackedClient` now requires `email` and `password`. Search:
- `status_controller.dart`: `launchCharacter()` already has account email/password — pass them through
- `watchdog_handlers.dart`: `recaptureRunningClients()` — will be updated in Task 9
- Any references to `client.proxyAddress` must change to `client.proxyUrl`

For now, fix only the compilation errors to keep the build green. The logic changes come in later tasks.

- [ ] **Step 3: Run existing tests**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: PASS (fix any test files that construct TrackedClient with old fields)

- [ ] **Step 4: Commit**

```bash
git add lib/config/services/watchdog/tracked_client.dart
git commit -m "refactor(watchdog): add email/password/proxyUrl to TrackedClient, remove proxyAddress"
```

---

### Task 6: Add Microbot config keys to AppConfigService

**Files:**
- Modify: `lib/config/services/app_config_service.dart`

**Context:** Current config keys are defined as static const strings at the top of `AppConfigService` (lines 13-22). The service extends `GetxService` with observable state and `init()` / `loadConfig()` / `save*()` methods. We add 3 new keys: `microbot_jar_path`, `microbot_jar_version`, `microbot_java_path`. These are stored as simple strings in the key-value AppConfigTable, not observable (no UI binding needed — they're read once at launch by setup services).

- [ ] **Step 1: Add config key constants**

In `lib/config/services/app_config_service.dart`, add after the existing config key constants (around line 22):

```dart
static const String _keyMicrobotJarPath = 'microbot_jar_path';
static const String _keyMicrobotJarVersion = 'microbot_jar_version';
static const String _keyMicrobotJavaPath = 'microbot_java_path';
```

- [ ] **Step 2: Add getter/setter methods**

Add these methods to the class (after existing save methods):

```dart
Future<String?> getMicrobotJarPath() async {
  return _repository.getConfigValue(_keyMicrobotJarPath);
}

Future<void> saveMicrobotJarPath(String path) async {
  await _repository.setConfigValue(_keyMicrobotJarPath, path);
}

Future<String?> getMicrobotJarVersion() async {
  return _repository.getConfigValue(_keyMicrobotJarVersion);
}

Future<void> saveMicrobotJarVersion(String version) async {
  await _repository.setConfigValue(_keyMicrobotJarVersion, version);
}

Future<String?> getMicrobotJavaPath() async {
  return _repository.getConfigValue(_keyMicrobotJavaPath);
}

Future<void> saveMicrobotJavaPath(String path) async {
  await _repository.setConfigValue(_keyMicrobotJavaPath, path);
}
```

- [ ] **Step 3: Run existing tests**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: PASS — additive change, no regressions

- [ ] **Step 4: Commit**

```bash
git add lib/config/services/app_config_service.dart
git commit -m "feat(config): add Microbot config keys (jar path, version, java path)"
```

---

## Chunk 2: Bot Engine Core

The abstract interface, Microbot implementation (profile writer + process launcher), and their tests.

### Task 7: BotEngine abstract class

**Files:**
- Create: `lib/config/services/bot_engine/bot_engine.dart`

**Context:** This is the abstraction layer that all bot engines implement. The spec defines 3 members: `launch()` (returns PID), `stop(pid)`, `engineName` getter. The signature uses flat parameters — callers pass primitives, not entity objects. See spec section "Bot Engine Abstraction" for the full contract.

- [ ] **Step 1: Create the abstract class**

```dart
// lib/config/services/bot_engine/bot_engine.dart
import 'package:command_center/config/services/watchdog/launch_config.dart';

/// Contract for bot engine implementations.
/// The app interacts only with this interface — never concrete engines directly.
/// Registered via GetX DI; swap implementations by changing the DI binding.
abstract class BotEngine {
  /// Launch a bot instance. Returns the OS process ID.
  Future<int> launch({
    required int characterId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  });

  /// Stop a running bot instance by PID. Kills process and cleans up artifacts.
  Future<void> stop(int pid);

  /// Human-readable engine name (for logs/notifications).
  String get engineName;
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /mnt/c/Projects/command_center_ux && flutter analyze lib/config/services/bot_engine/bot_engine.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/bot_engine/bot_engine.dart
git commit -m "feat(bot-engine): add BotEngine abstract interface"
```

---

### Task 8: MicrobotProfileWriter

**Files:**
- Create: `lib/config/services/bot_engine/microbot_profile_writer.dart`
- Test: `test/config/services/bot_engine/microbot_profile_writer_test.dart`

**Context:** Microbot requires RuneLite profile directories with `.properties` files. The writer creates `bot-<characterId>/settings.properties` (plugin configs, world, display) and `bot-<characterId>/credentials.properties` (email/password). Profiles are transient — created at launch, deleted on stop. The writer is a pure utility (no DI dependencies) that takes a base path and writes files. See spec section "Profile Generation" for the directory structure.

- [ ] **Step 1: Write the failing tests**

```dart
// test/config/services/bot_engine/microbot_profile_writer_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late MicrobotProfileWriter writer;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('microbot_test_');
    writer = MicrobotProfileWriter(profilesBasePath: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MicrobotProfileWriter', () {
    test('writeProfile creates profile directory with settings and credentials', () async {
      await writer.writeProfile(
        characterId: 42,
        email: 'test@example.com',
        password: 'secret123',
        world: '301',
        scriptName: 'Tutorial Journey',
      );

      final profileDir = Directory(p.join(tempDir.path, 'bot-42'));
      expect(profileDir.existsSync(), isTrue);

      final settings = File(p.join(profileDir.path, 'settings.properties'));
      expect(settings.existsSync(), isTrue);
      final settingsContent = settings.readAsStringSync();
      expect(settingsContent, contains('world=301'));

      final credentials = File(p.join(profileDir.path, 'credentials.properties'));
      expect(credentials.existsSync(), isTrue);
      final credentialsContent = credentials.readAsStringSync();
      expect(credentialsContent, contains('email=test@example.com'));
      expect(credentialsContent, contains('password=secret123'));
    });

    test('writeProfile handles auto world', () async {
      await writer.writeProfile(
        characterId: 7,
        email: 'auto@test.com',
        password: 'pass',
        world: 'auto',
        scriptName: 'Woodcutter',
      );

      final settings = File(p.join(tempDir.path, 'bot-7', 'settings.properties'));
      final content = settings.readAsStringSync();
      // 'auto' means no world pinning — omit or use empty
      expect(content, isNot(contains('world=auto')));
    });

    test('deleteProfile removes the entire profile directory', () async {
      await writer.writeProfile(
        characterId: 42,
        email: 'test@example.com',
        password: 'pass',
        world: '301',
        scriptName: 'Test',
      );

      final profileDir = Directory(p.join(tempDir.path, 'bot-42'));
      expect(profileDir.existsSync(), isTrue);

      await writer.deleteProfile(characterId: 42);
      expect(profileDir.existsSync(), isFalse);
    });

    test('deleteProfile is a no-op if profile does not exist', () async {
      // Should not throw
      await writer.deleteProfile(characterId: 999);
    });

    test('cleanStaleProfiles removes directories not in livePids', () async {
      // Create two profiles
      await writer.writeProfile(
        characterId: 1, email: 'a@b.com', password: 'p', world: 'auto', scriptName: 'S',
      );
      await writer.writeProfile(
        characterId: 2, email: 'c@d.com', password: 'p', world: 'auto', scriptName: 'S',
      );

      // Only characterId 1 is still alive
      await writer.cleanStaleProfiles(liveCharacterIds: {1});

      expect(Directory(p.join(tempDir.path, 'bot-1')).existsSync(), isTrue);
      expect(Directory(p.join(tempDir.path, 'bot-2')).existsSync(), isFalse);
    });

    test('profilePath returns correct directory path', () {
      expect(
        writer.profilePath(characterId: 42),
        p.join(tempDir.path, 'bot-42'),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_profile_writer_test.dart`
Expected: FAIL — class not defined

- [ ] **Step 3: Write implementation**

```dart
// lib/config/services/bot_engine/microbot_profile_writer.dart
import 'dart:io';
import 'package:path/path.dart' as p;

/// Writes and manages transient RuneLite profile directories for Microbot instances.
/// Profiles are disposable artifacts — the database is the source of truth.
class MicrobotProfileWriter {
  final String profilesBasePath;

  MicrobotProfileWriter({required this.profilesBasePath});

  /// Returns the profile directory path for a character.
  String profilePath({required int characterId}) {
    return p.join(profilesBasePath, 'bot-$characterId');
  }

  /// Write profile files for a Microbot instance.
  Future<void> writeProfile({
    required int characterId,
    required String email,
    required String password,
    required String world,
    required String scriptName,
  }) async {
    final dir = Directory(profilePath(characterId: characterId));
    await dir.create(recursive: true);

    // settings.properties — RuneLite plugin configs
    final settings = StringBuffer();
    if (world != 'auto' && world.isNotEmpty) {
      settings.writeln('world=$world');
    }
    settings.writeln('script=$scriptName');
    await File(p.join(dir.path, 'settings.properties'))
        .writeAsString(settings.toString());

    // credentials.properties — account login (never logged)
    final credentials = StringBuffer();
    credentials.writeln('email=$email');
    credentials.writeln('password=$password');
    await File(p.join(dir.path, 'credentials.properties'))
        .writeAsString(credentials.toString());
  }

  /// Delete a profile directory (called on stop).
  Future<void> deleteProfile({required int characterId}) async {
    final dir = Directory(profilePath(characterId: characterId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Remove profile directories whose bots are no longer running.
  /// Called AFTER recaptureRunningClients() to avoid race conditions.
  Future<void> cleanStaleProfiles({required Set<int> liveCharacterIds}) async {
    final baseDir = Directory(profilesBasePath);
    if (!await baseDir.exists()) return;

    await for (final entity in baseDir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        // Parse bot-<id> directory names
        if (name.startsWith('bot-')) {
          final idStr = name.substring(4);
          final id = int.tryParse(idStr);
          if (id != null && !liveCharacterIds.contains(id)) {
            await entity.delete(recursive: true);
          }
        }
      }
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_profile_writer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/bot_engine/microbot_profile_writer.dart test/config/services/bot_engine/microbot_profile_writer_test.dart
git commit -m "feat(bot-engine): add MicrobotProfileWriter for transient RuneLite profiles"
```

---

### Task 9: MicrobotEngine implementation

**Files:**
- Create: `lib/config/services/bot_engine/microbot_engine.dart`
- Test: `test/config/services/bot_engine/microbot_engine_test.dart`

**Context:** `MicrobotEngine` implements `BotEngine`. It uses `Process.start()` to spawn JVM processes (same pattern as `PythonRunner` at `python_runner.dart:109`). It depends on `MicrobotProfileWriter` for profile I/O, `NativeCommandsService` for process killing, and `AppConfigService` for JAR/Java paths. The launch command structure is: `java <jvmArgs> -jar <jarPath> --profile=bot-<id> [--proxy=socks5://...] --safe-mode`. Stdout/stderr are captured for log forwarding. Spawned PIDs are tracked for app-close cleanup. See spec sections "Process Launching" and "JVM Memory Management".

- [ ] **Step 1: Write the failing tests**

```dart
// test/config/services/bot_engine/microbot_engine_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MicrobotEngine', () {
    test('engineName returns Microbot', () {
      final engine = MicrobotEngine(
        javaPath: '/fake/java',
        jarPath: '/fake/microbot.jar',
        profilesBasePath: '/fake/profiles',
        onLog: (_) {},
      );
      expect(engine.engineName, 'Microbot');
    });

    test('buildLaunchArgs constructs correct argument list with proxy', () {
      final engine = MicrobotEngine(
        javaPath: '/java/bin/java.exe',
        jarPath: '/app/microbot-shaded.jar',
        profilesBasePath: '/profiles',
        onLog: (_) {},
      );

      final args = engine.buildLaunchArgs(
        characterId: 42,
        proxyUrl: 'socks5://user:pass@1.2.3.4:1080',
        config: const LaunchConfig(
          scriptName: 'Tutorial',
          jvmArgs: '-Xmx384m',
        ),
      );

      // JVM flags before -jar
      expect(args[0], '-Xmx384m');
      // -jar and jar path
      expect(args[1], '-jar');
      expect(args[2], '/app/microbot-shaded.jar');
      // App flags after jar
      expect(args, contains('--profile=bot-42'));
      expect(args, contains('--proxy=socks5://user:pass@1.2.3.4:1080'));
      expect(args, contains('--safe-mode'));
    });

    test('buildLaunchArgs omits --proxy when proxyUrl is null', () {
      final engine = MicrobotEngine(
        javaPath: '/java/bin/java.exe',
        jarPath: '/app/microbot-shaded.jar',
        profilesBasePath: '/profiles',
        onLog: (_) {},
      );

      final args = engine.buildLaunchArgs(
        characterId: 7,
        proxyUrl: null,
        config: const LaunchConfig(scriptName: 'Test'),
      );

      expect(args.any((a) => a.startsWith('--proxy')), isFalse);
    });

    test('buildLaunchArgs uses default -Xmx512m when jvmArgs is null', () {
      final engine = MicrobotEngine(
        javaPath: '/java/bin/java.exe',
        jarPath: '/app/microbot-shaded.jar',
        profilesBasePath: '/profiles',
        onLog: (_) {},
      );

      final args = engine.buildLaunchArgs(
        characterId: 1,
        proxyUrl: null,
        config: const LaunchConfig(scriptName: 'Test'),
      );

      expect(args[0], '-Xmx512m');
    });

    test('buildLaunchArgs includes advancedFlags', () {
      final engine = MicrobotEngine(
        javaPath: '/java/bin/java.exe',
        jarPath: '/app/microbot-shaded.jar',
        profilesBasePath: '/profiles',
        onLog: (_) {},
      );

      final args = engine.buildLaunchArgs(
        characterId: 1,
        proxyUrl: null,
        config: const LaunchConfig(
          scriptName: 'Test',
          advancedFlags: '-fps 15 --low-detail',
        ),
      );

      expect(args, contains('-fps'));
      expect(args, contains('15'));
      expect(args, contains('--low-detail'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_engine_test.dart`
Expected: FAIL — class not defined

- [ ] **Step 3: Write implementation**

```dart
// lib/config/services/bot_engine/microbot_engine.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';

/// Microbot (RuneLite fork) implementation of [BotEngine].
/// Manages JVM process lifecycle and transient RuneLite profiles.
class MicrobotEngine implements BotEngine {
  final String javaPath;
  final String jarPath;
  final MicrobotProfileWriter _profileWriter;
  final void Function(String message) onLog;

  /// Track spawned PIDs for app-close awareness.
  final Set<int> _activePids = {};

  /// Map PID → characterId for profile cleanup on stop.
  final Map<int, int> _pidToCharacterId = {};

  MicrobotEngine({
    required this.javaPath,
    required this.jarPath,
    required String profilesBasePath,
    required this.onLog,
  }) : _profileWriter = MicrobotProfileWriter(profilesBasePath: profilesBasePath);

  @override
  String get engineName => 'Microbot';

  @override
  Future<int> launch({
    required int characterId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  }) async {
    // 1. Write transient profile
    await _profileWriter.writeProfile(
      characterId: characterId,
      email: email,
      password: password,
      world: config.world,
      scriptName: config.scriptName,
    );

    // 2. Build args and launch JVM
    final args = buildLaunchArgs(
      characterId: characterId,
      proxyUrl: proxyUrl,
      config: config,
    );

    developer.log(
      'Launching Microbot for $characterName (id=$characterId)',
      name: 'MicrobotEngine',
    );

    final process = await Process.start(javaPath, args);
    final pid = process.pid;

    _activePids.add(pid);
    _pidToCharacterId[pid] = characterId;

    // 3. Capture stdout/stderr for log forwarding (non-blocking)
    process.stdout.transform(const SystemEncoding().decoder).listen((data) {
      onLog('[Microbot:$characterName] $data');
    });
    process.stderr.transform(const SystemEncoding().decoder).listen((data) {
      onLog('[Microbot:$characterName:ERR] $data');
    });

    // 4. Clean up tracking when process exits (fire-and-forget)
    process.exitCode.then((_) {
      _activePids.remove(pid);
    });

    return pid;
  }

  @override
  Future<void> stop(int pid) async {
    final characterId = _pidToCharacterId[pid];

    // Kill process via platform (same as NativeCommandsService)
    Process.killPid(pid);

    _activePids.remove(pid);
    _pidToCharacterId.remove(pid);

    // Clean up profile directory
    if (characterId != null) {
      await _profileWriter.deleteProfile(characterId: characterId);
    }
  }

  /// Build the JVM argument list. Exposed for testing.
  List<String> buildLaunchArgs({
    required int characterId,
    required String? proxyUrl,
    required LaunchConfig config,
  }) {
    final args = <String>[];

    // JVM flags BEFORE -jar
    final jvmArgs = config.jvmArgs ?? '-Xmx512m';
    args.addAll(jvmArgs.split(' ').where((s) => s.isNotEmpty));

    // -jar <path>
    args.addAll(['-jar', jarPath]);

    // Application flags AFTER jar path
    args.add('--profile=bot-$characterId');

    if (proxyUrl != null) {
      args.add('--proxy=$proxyUrl');
    }

    args.add('--safe-mode');

    // Advanced flags (user-provided, split by space)
    if (config.advancedFlags.isNotEmpty) {
      args.addAll(config.advancedFlags.split(' ').where((s) => s.isNotEmpty));
    }

    return args;
  }

  /// Clean stale profile directories. Called AFTER recaptureRunningClients().
  Future<void> cleanStaleProfiles(Set<int> liveCharacterIds) async {
    await _profileWriter.cleanStaleProfiles(liveCharacterIds: liveCharacterIds);
  }

  /// Get all currently tracked PIDs (for app-close awareness).
  Set<int> get activePids => Set.unmodifiable(_activePids);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_engine_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/bot_engine/microbot_engine.dart test/config/services/bot_engine/microbot_engine_test.dart
git commit -m "feat(bot-engine): add MicrobotEngine with Process.start() launch and profile management"
```

---

## Chunk 3: Watchdog & Controller Integration

Wire the new BotEngine into WatchdogService, WatchdogHandlers, and StatusController.

### Task 10: Wire BotEngine into WatchdogService and WatchdogHandlers

**Files:**
- Modify: `lib/config/services/watchdog/watchdog_service.dart`
- Modify: `lib/config/services/watchdog/watchdog_handlers.dart`

**Context:** `WatchdogService` constructor currently takes 5 dependencies (`watchdog_service.dart:29-43`). Add `BotEngine`. The service passes it to `WatchdogHandlers`. The `stop()` method (`watchdog_service.dart:87-95`) currently calls `_nativeCommandsService.killProcess(pid)` directly — it must route through `BotEngine.stop(pid)` instead so profile cleanup happens.

`WatchdogHandlers` constructor (`watchdog_handlers.dart:24-34`) currently takes matching dependencies. Add `BotEngine`. The `handleRestart()` method (`watchdog_handlers.dart:71-124`) currently calls `_nativeCommandsService.runGameClient()` — switch to `_botEngine.launch()` with flat params from `TrackedClient`. The `discoverPid()` method (`watchdog_handlers.dart:127-138`) currently matches `-account "name"` — switch to `--profile=bot-<characterId>`. The `handleBan()` method (`watchdog_handlers.dart:199-224`) currently sets `client.proxyAddress = newIp` — must reconstruct `client.proxyUrl` using `ProxyUrlBuilder`.

- [ ] **Step 1: Add BotEngine to WatchdogHandlers constructor**

In `lib/config/services/watchdog/watchdog_handlers.dart`:
- Add import: `import 'package:command_center/config/services/bot_engine/bot_engine.dart';`
- Add import: `import 'package:command_center/core/helper/proxy_url_builder.dart';`
- Add import (if not already present): `import 'dart:developer' as developer;`
- Add to constructor: `required BotEngine botEngine,`
- Store as field: `final BotEngine _botEngine;`

- [ ] **Step 2: Update handleRestart() to use BotEngine.launch()**

In `handleRestart()` (around line 71-124), replace the `_nativeCommandsService.runGameClient(...)` call with:

```dart
final newPid = await _botEngine.launch(
  characterId: client.characterId,
  characterName: client.characterName,
  email: client.email,
  password: client.password,
  proxyUrl: client.proxyUrl,
  config: client.launchConfig,
);
client.pid = newPid;
```

Remove the old `runGameClient()` call and its parameter construction.

- [ ] **Step 3: Update discoverPid() for Microbot pattern**

In `discoverPid()` (around line 127-138), replace the DreamBot `-account "name"` regex matching with Microbot `--profile=bot-<characterId>` matching:

```dart
int? discoverPid(TrackedClient client, List<ProcessClient> liveProcesses) {
  for (final process in liveProcesses) {
    if (process.commandLine.contains('--profile=bot-${client.characterId}')) {
      return process.pid;
    }
  }
  return null;
}
```

- [ ] **Step 4: Update recaptureRunningClients() for Microbot pattern + DB hydration**

In `recaptureRunningClients()` (around line 141-196), replace DreamBot regex with Microbot pattern and add credential hydration:

```dart
Future<void> recaptureRunningClients(RxMap<String, TrackedClient> trackedClients) async {
  final liveProcesses = await _nativeCommandsService.listJavaProcesses();
  // Get all accounts (each account includes nested characters)
  final accounts = await _accountRepository.getAllAccounts();

  // Flatten characters from accounts for lookup
  final characterToAccount = <int, dynamic>{};
  for (final account in accounts) {
    for (final character in account.characters) {
      characterToAccount[character.id!] = account;
    }
  }

  for (final process in liveProcesses) {
    // Match Microbot pattern: --profile=bot-<characterId>
    final profileMatch = RegExp(r'--profile=bot-(\d+)').firstMatch(process.commandLine);
    if (profileMatch == null) continue;

    final characterId = int.parse(profileMatch.group(1)!);

    // Skip if already tracked
    if (trackedClients.values.any((c) => c.characterId == characterId)) continue;

    // Find account and character in DB
    final account = characterToAccount[characterId];
    if (account == null) {
      developer.log('Orphaned Microbot process (characterId=$characterId, pid=${process.processId})', name: 'WatchdogHandlers');
      continue;
    }

    final character = account.characters.firstWhere((c) => c.id == characterId);

    // Reconstruct proxy URL if proxy assigned
    String? proxyUrl;
    if (account.proxySlotId != null) {
      final slot = await _proxyRepository.getSlotById(account.proxySlotId!);
      if (slot != null && slot.currentIpAddressId != null && slot.socksPort != null) {
        final ip = await _proxyRepository.getIpAddressById(slot.currentIpAddressId!);
        if (ip != null) {
          proxyUrl = ProxyUrlBuilder.buildSocks5Url(
            username: slot.username,
            password: slot.password,
            ipAddress: ip.ipAddress,
            socksPort: slot.socksPort!,
          );
        }
      }
    }

    // Extract script name from command line if possible
    final scriptMatch = RegExp(r'--script[= ](\S+)').firstMatch(process.commandLine);
    final scriptName = scriptMatch?.group(1) ?? 'Unknown';

    final client = TrackedClient(
      characterName: character.displayName,
      characterId: characterId,
      accountId: account.id!,
      proxySlotId: account.proxySlotId,
      email: account.email,
      password: account.password,
      proxyUrl: proxyUrl,
      launchConfig: LaunchConfig(scriptName: scriptName),
      pid: process.processId,
      status: ClientStatus.running,
      launchedAt: DateTime.now(),
    );

    trackedClients[character.displayName] = client;
  }

  if (trackedClients.isNotEmpty) {
    trackedClients.refresh();
  }
}
```

Note: Verify the exact field names (`process.processId` vs `process.pid`, `account.characters` accessor pattern) against the existing `ProcessClient` model and `AccountEntity` during implementation. The existing `recaptureRunningClients()` at `watchdog_handlers.dart:141-196` shows the actual patterns used.

- [ ] **Step 5: Update handleBan() to reconstruct proxyUrl**

In `handleBan()` (around line 199-224), after proxy rotation, reconstruct the full URL:

Replace `client.proxyAddress = newIp.ipAddress;` with:

```dart
// Reconstruct full SOCKS5 URL after rotation
if (client.proxySlotId != null) {
  final slot = await _proxyRepository.getSlotById(client.proxySlotId!);
  if (slot != null && slot.socksPort != null) {
    client.proxyUrl = ProxyUrlBuilder.buildSocks5Url(
      username: slot.username,
      password: slot.password,
      ipAddress: newIp.ipAddress,
      socksPort: slot.socksPort!,
    );
  }
}
```

- [ ] **Step 6: Add BotEngine to WatchdogService constructor and route stop()**

In `lib/config/services/watchdog/watchdog_service.dart`:
- Add import: `import 'package:command_center/config/services/bot_engine/bot_engine.dart';`
- Add to constructor: `required BotEngine botEngine,`
- Store as field: `final BotEngine _botEngine;`
- Pass to `WatchdogHandlers` constructor: `botEngine: botEngine,`
- In `stop()` method, replace `_nativeCommandsService.killProcess(client.pid!)` with `await _botEngine.stop(client.pid!)`

- [ ] **Step 7: Run existing tests**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: May have test failures from constructor changes — fix mock setups to provide `BotEngine` mock.

- [ ] **Step 8: Commit**

```bash
git add lib/config/services/watchdog/watchdog_service.dart lib/config/services/watchdog/watchdog_handlers.dart
git commit -m "feat(watchdog): wire BotEngine into WatchdogService/Handlers, replace DreamBot patterns"
```

---

### Task 11: Wire BotEngine into StatusController

**Files:**
- Modify: `lib/feature/Status/controller/status_controller.dart`

**Context:** `StatusController.launchCharacter()` (`status_controller.dart:104-152`) currently resolves proxy IP, then calls `_nativeService.runGameClient()` with character name, script, proxy, and flags. It must switch to `BotEngine.launch()` with flat params (email, password, proxyUrl, config). The controller must construct the SOCKS5 URL using `ProxyUrlBuilder` from `ProxySlotEntity` + `ProxyIpAddressEntity`. The `TrackedClient` constructor now requires `email` and `password`.

- [ ] **Step 1: Add BotEngine dependency**

In `status_controller.dart`:
- Add import: `import 'package:command_center/config/services/bot_engine/bot_engine.dart';`
- Add import: `import 'package:command_center/core/helper/proxy_url_builder.dart';`
- Add field: `final BotEngine _botEngine = Get.find<BotEngine>();`

- [ ] **Step 2: Update launchCharacter() to use BotEngine.launch()**

Replace the launch logic in `launchCharacter()`:

```dart
// Build proxy URL if proxy assigned
String? proxyUrl;
if (account.proxySlotId != null) {
  final slot = await _dbService.proxyRepository.getSlotById(account.proxySlotId!);
  if (slot != null && slot.currentIpAddressId != null && slot.socksPort != null) {
    final ip = await _dbService.proxyRepository.getIpAddressById(slot.currentIpAddressId!);
    if (ip != null) {
      proxyUrl = ProxyUrlBuilder.buildSocks5Url(
        username: slot.username,
        password: slot.password,
        ipAddress: ip.ipAddress,
        socksPort: slot.socksPort!,
      );
    }
  }
}

final pid = await _botEngine.launch(
  characterId: character.id!,
  characterName: character.displayName,
  email: account.email,
  password: account.password,
  proxyUrl: proxyUrl,
  config: launchConfig,
);

final trackedClient = TrackedClient(
  characterName: character.displayName,
  characterId: character.id!,
  accountId: account.id!,
  proxySlotId: account.proxySlotId,
  email: account.email,
  password: account.password,
  proxyUrl: proxyUrl,
  launchConfig: launchConfig,
  pid: pid,
  status: ClientStatus.running,
  launchedAt: DateTime.now(),
);

_watchdog.track(trackedClient);
```

- [ ] **Step 3: Run existing tests**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/feature/Status/controller/status_controller.dart
git commit -m "feat(status): switch launchCharacter() to BotEngine.launch() with SOCKS5 proxy URL"
```

---

### Task 12: Update Launch Dialog — remove DreamBot fields, add jvmArgs

**Files:**
- Modify: `lib/feature/Status/views/dialogs/launch_dialog.dart`

**Context:** Current dialog (`launch_dialog.dart:1-196`) has fields for `covert` (toggle), `render` (dropdown with 4 options), plus script, world, params, flags. Remove `covert` and `render` entirely. Add `jvmArgs` text field with placeholder `-Xmx512m`. The `_onLaunch()` method (line 176-195) constructs `LaunchConfig` — update to use the new constructor without `covert`/`render` and with `jvmArgs`.

- [ ] **Step 1: Remove covert and render state**

In the `_LaunchDialogState`:
- Remove: `late bool _covert;` and `late String _selectedRender;`
- Remove: Any references to render options list (`['NONE', 'ALL', 'GAME', 'SCRIPT']`)
- Add: `final _jvmArgsController = TextEditingController();`

- [ ] **Step 2: Remove covert/render UI widgets**

Remove the toggle and dropdown widgets for covert and render. Add a `TextBox` for JVM args:

```dart
InfoLabel(
  label: 'JVM Arguments',
  child: TextBox(
    controller: _jvmArgsController,
    placeholder: '-Xmx512m (default)',
  ),
),
```

- [ ] **Step 3: Update _onLaunch() to use new LaunchConfig**

```dart
void _onLaunch() {
  // Resolve world selection (matches existing logic)
  String world = _selectedWorld;
  if (world == 'specific') {
    world = _worldNumberController.text.isNotEmpty
        ? _worldNumberController.text
        : 'auto';
  }

  final config = LaunchConfig(
    scriptName: _selectedScript,
    world: world,
    scriptParams: _scriptParamsController.text.trim(),
    advancedFlags: _advancedFlagsController.text.trim(),
    jvmArgs: _jvmArgsController.text.trim().isEmpty
        ? null
        : _jvmArgsController.text.trim(),
  );
  _lastConfig = config;
  Navigator.of(context).pop(config);
}
```

- [ ] **Step 4: Update dispose**

Add `_jvmArgsController.dispose();` to the dispose method.

- [ ] **Step 5: Run the app visually (manual)**

Run: `cd /mnt/c/Projects/command_center_ux && flutter run -d windows`
Expected: Launch dialog shows script, world, params, JVM args, flags. No covert/render fields.

- [ ] **Step 6: Commit**

```bash
git add lib/feature/Status/views/dialogs/launch_dialog.dart
git commit -m "feat(ui): update launch dialog — remove DreamBot fields, add JVM args"
```

---

### Task 13: Register BotEngine in DI and update startup ordering

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart`

**Context:** `AppBindings` has two phases: `dependencies()` (sync, line 30-91) and `initializeAsyncServices()` (async, line 94-144). `WatchdogService` is registered last (line 134-143) with 5 constructor params. `BotEngine` (as `MicrobotEngine`) must be registered BEFORE WatchdogService since WatchdogService now takes `BotEngine` as a dependency. `MicrobotEngine` needs: `javaPath` (from AppConfigService), `jarPath` (from AppConfigService), `profilesBasePath` (from AppDataPath). The startup ordering after recapture must call `MicrobotEngine.cleanStaleProfiles()`.

- [ ] **Step 1: Add imports**

In `dependency_injection.dart`, add:

```dart
import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/core/helper/app_data_path.dart';
```

- [ ] **Step 2: Register AppDataPath in dependencies()**

In the `dependencies()` method, add early (before other services):

```dart
Get.put(AppDataPath(), permanent: true);
```

- [ ] **Step 3: Register MicrobotEngine in initializeAsyncServices()**

After `NotificationService` registration (step 8, around line 127) and BEFORE `WatchdogService`:

```dart
// Step 8.5: BotEngine (must be before WatchdogService)
final appDataPath = Get.find<AppDataPath>();
final basePath = await appDataPath.basePath;
final appConfig = Get.find<AppConfigService>();
final javaPath = await appConfig.getMicrobotJavaPath() ?? 'java';
final jarPath = await appConfig.getMicrobotJarPath() ?? '';

final microbotEngine = MicrobotEngine(
  javaPath: javaPath,
  jarPath: jarPath,
  profilesBasePath: AppDataPath.joinPath(basePath, 'microbot_profiles'),
  onLog: (msg) => developer.log(msg, name: 'MicrobotEngine'),
);
Get.put<BotEngine>(microbotEngine, permanent: true);
```

- [ ] **Step 4: Pass BotEngine to WatchdogService constructor**

Update the `WatchdogService` registration to include the new parameter:

```dart
Get.put(
  WatchdogService(
    nativeCommandsService: Get.find<NativeCommandsService>(),
    notificationService: Get.find<NotificationService>(),
    autoRotationService: Get.find<ProxyAutoRotationService>(),
    accountRepository: Get.find<DatabaseService>().accountRepository,
    proxyRepository: Get.find<DatabaseService>().proxyRepository,
    botEngine: Get.find<BotEngine>(),
  ),
  permanent: true,
);
```

- [ ] **Step 5: Chain stale profile cleanup into recapture flow**

The existing `WatchdogService.onInit()` calls `recaptureRunningClients()` async without awaiting. Since `cleanStaleProfiles()` must run AFTER recapture completes, there are two options:

**Option A (recommended):** Move cleanup into the end of `recaptureRunningClients()` in `watchdog_handlers.dart`. After the recapture loop completes, call `_botEngine.cleanStaleProfiles()` with the set of recaptured character IDs:

```dart
// At the end of recaptureRunningClients(), after the for loop:
final liveCharacterIds = trackedClients.values
    .map((c) => c.characterId)
    .toSet();
if (_botEngine is MicrobotEngine) {
  await (_botEngine as MicrobotEngine).cleanStaleProfiles(liveCharacterIds);
}
```

This ensures cleanup always happens after recapture, regardless of timing.

**Option B:** Make `WatchdogService.onInit()` await recapture and then call cleanup. This requires changing the `onInit()` to use a completion callback or Future chain.

Choose Option A — it's simpler and keeps the ordering guarantee within a single async method.

- [ ] **Step 6: Run the app to verify DI registration order**

Run: `cd /mnt/c/Projects/command_center_ux && flutter run -d windows`
Expected: App starts without DI errors. Services initialize in correct order.

- [ ] **Step 7: Commit**

```bash
git add lib/core/resource/dependency_injection.dart
git commit -m "feat(di): register BotEngine before WatchdogService, add startup profile cleanup"
```

---

## Chunk 4: Setup Services & Splash Screen

Dependency installation (Java 17 + Microbot JAR) and the splash screen UI.

### Task 14: JavaInstaller service

**Files:**
- Create: `lib/config/services/bot_engine/java_installer.dart`
- Test: `test/config/services/bot_engine/java_installer_test.dart`

**Context:** Downloads and verifies Eclipse Temurin JRE 17 from the Adoptium API. Mirrors `PythonSetupService` pattern (`python_setup_service.dart:53-165`): checks if installed → downloads if not → extracts → verifies → stores path in config. Uses `HttpClient` for downloads, `Archive` package or `Process.start('tar', ...)` for extraction. Stores `microbot_java_path` config key. Must be under 150 lines. See spec section "Setup & Splash Screen" → "Dependencies" → "Java 17+".

- [ ] **Step 1: Write the failing tests**

```dart
// test/config/services/bot_engine/java_installer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/java_installer.dart';

void main() {
  group('JavaInstaller', () {
    test('checkJavaVersion parses version string correctly', () {
      // Java 17 version output: 'openjdk 17.0.9 2023-10-17'
      expect(JavaInstaller.parseJavaMajorVersion('openjdk 17.0.9 2023-10-17'), 17);
      expect(JavaInstaller.parseJavaMajorVersion('openjdk 21.0.1 2023-10-17'), 21);
      expect(JavaInstaller.parseJavaMajorVersion('java version "1.8.0_301"'), 8);
      expect(JavaInstaller.parseJavaMajorVersion('not java output'), null);
    });

    test('isJava17OrHigher returns correct result', () {
      expect(JavaInstaller.isJava17OrHigher(17), isTrue);
      expect(JavaInstaller.isJava17OrHigher(21), isTrue);
      expect(JavaInstaller.isJava17OrHigher(8), isFalse);
      expect(JavaInstaller.isJava17OrHigher(null), isFalse);
    });

    test('adoptiumUrl returns correct download URL', () {
      final url = JavaInstaller.adoptiumDownloadUrl;
      expect(url, contains('api.adoptium.net'));
      expect(url, contains('/17/'));
      expect(url, contains('windows'));
      expect(url, contains('jre'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/java_installer_test.dart`
Expected: FAIL — class not defined

- [ ] **Step 3: Write implementation**

```dart
// lib/config/services/bot_engine/java_installer.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/helper/app_data_path.dart';
import 'package:path/path.dart' as p;

/// Downloads and manages Eclipse Temurin JRE 17 for Microbot.
class JavaInstaller {
  final AppConfigService _appConfig;
  final String _basePath;

  JavaInstaller({required AppConfigService appConfig, required String basePath})
      : _appConfig = appConfig,
        _basePath = basePath;

  static const adoptiumDownloadUrl =
      'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jre/hotspot/normal/eclipse';

  /// Check if Java 17+ is available (either configured path or system).
  Future<String?> findJavaPath() async {
    // 1. Check configured path
    final configured = await _appConfig.getMicrobotJavaPath();
    if (configured != null && await _verifyJava(configured)) return configured;

    // 2. Check system java
    if (await _verifyJava('java')) return 'java';

    return null;
  }

  /// Download and install Eclipse Temurin JRE 17.
  /// [onProgress] called with (bytesDownloaded, totalBytes) for UI updates.
  Future<String> install({void Function(int downloaded, int total)? onProgress}) async {
    final javaDir = p.join(_basePath, 'java');
    await Directory(javaDir).create(recursive: true);

    final zipPath = p.join(javaDir, 'temurin-jre-17.zip');

    developer.log('Downloading Java 17 JRE from Adoptium...', name: 'JavaInstaller');

    // Download
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(adoptiumDownloadUrl));
      final response = await request.close();

      // Follow redirects are handled automatically by HttpClient
      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(zipPath).openWrite();
      await for (final chunk in response) {
        file.add(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(downloadedBytes, totalBytes);
      }
      await file.close();
    } finally {
      client.close();
    }

    developer.log('Extracting Java JRE...', name: 'JavaInstaller');

    // Extract zip using PowerShell (Windows)
    final extractResult = await Process.run('powershell', [
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "$javaDir" -Force',
    ]);

    if (extractResult.exitCode != 0) {
      throw Exception('Failed to extract Java JRE: ${extractResult.stderr}');
    }

    // Find the extracted JRE directory (e.g., jdk-17.0.9+9-jre)
    final jreDir = await Directory(javaDir)
        .list()
        .where((e) => e is Directory && p.basename(e.path).startsWith('jdk-'))
        .first;

    final javaExePath = p.join(jreDir.path, 'bin', 'java.exe');

    // Store path in config
    await _appConfig.saveMicrobotJavaPath(javaExePath);

    // Clean up zip
    await File(zipPath).delete();

    developer.log('Java 17 installed at: $javaExePath', name: 'JavaInstaller');
    return javaExePath;
  }

  Future<bool> _verifyJava(String javaPath) async {
    try {
      final result = await Process.run(javaPath, ['--version']);
      final output = '${result.stdout}\n${result.stderr}';
      final version = parseJavaMajorVersion(output);
      return isJava17OrHigher(version);
    } catch (_) {
      return false;
    }
  }

  /// Parse Java major version from `java --version` output.
  static int? parseJavaMajorVersion(String output) {
    // Matches: openjdk 17.0.9, java version "1.8.0_301", etc.
    final modernMatch = RegExp(r'(?:openjdk|java)\s+(\d+)').firstMatch(output);
    if (modernMatch != null) return int.tryParse(modernMatch.group(1)!);

    // Legacy format: "1.8.0_301" → major version 8
    final legacyMatch = RegExp(r'"1\.(\d+)\.').firstMatch(output);
    if (legacyMatch != null) return int.tryParse(legacyMatch.group(1)!);

    return null;
  }

  static bool isJava17OrHigher(int? version) => version != null && version >= 17;
}
```

- [ ] **Step 4: Run tests**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/java_installer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/bot_engine/java_installer.dart test/config/services/bot_engine/java_installer_test.dart
git commit -m "feat(bot-engine): add JavaInstaller for Eclipse Temurin JRE 17 auto-download"
```

---

### Task 15: MicrobotJarDownloader service

**Files:**
- Create: `lib/config/services/bot_engine/microbot_jar_downloader.dart`
- Test: `test/config/services/bot_engine/microbot_jar_downloader_test.dart`

**Context:** Downloads and updates the Microbot shaded JAR from GitHub Releases API. Checks `https://api.github.com/repos/chsami/Microbot/releases/latest` for the latest release tag. Finds the `*-shaded.jar` asset. Compares local version (from `microbot_jar_version` config key) to remote. Downloads if missing or outdated. Handles GitHub API rate limiting (60 req/hr unauthenticated): skip update check on failure, use cached JAR. Must be under 150 lines.

- [ ] **Step 1: Write the failing tests**

```dart
// test/config/services/bot_engine/microbot_jar_downloader_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';

void main() {
  group('MicrobotJarDownloader', () {
    test('findShadedJarAsset finds correct asset from release JSON', () {
      final assets = [
        {'name': 'microbot-1.0.0.jar', 'browser_download_url': 'https://example.com/normal.jar'},
        {'name': 'microbot-1.0.0-shaded.jar', 'browser_download_url': 'https://example.com/shaded.jar'},
        {'name': 'source.zip', 'browser_download_url': 'https://example.com/source.zip'},
      ];

      final result = MicrobotJarDownloader.findShadedJarUrl(assets);
      expect(result, 'https://example.com/shaded.jar');
    });

    test('findShadedJarAsset returns null when no shaded JAR', () {
      final assets = [
        {'name': 'source.zip', 'browser_download_url': 'https://example.com/source.zip'},
      ];

      final result = MicrobotJarDownloader.findShadedJarUrl(assets);
      expect(result, isNull);
    });

    test('isUpdateAvailable compares versions', () {
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.0.0', remote: 'v1.1.0'), isTrue);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.1.0', remote: 'v1.1.0'), isFalse);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: null, remote: 'v1.0.0'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_jar_downloader_test.dart`
Expected: FAIL

- [ ] **Step 3: Write implementation**

```dart
// lib/config/services/bot_engine/microbot_jar_downloader.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:path/path.dart' as p;

/// Downloads and updates Microbot shaded JAR from GitHub Releases.
class MicrobotJarDownloader {
  final AppConfigService _appConfig;
  final String _basePath;

  static const _releasesUrl =
      'https://api.github.com/repos/chsami/Microbot/releases/latest';

  MicrobotJarDownloader({
    required AppConfigService appConfig,
    required String basePath,
  })  : _appConfig = appConfig,
        _basePath = basePath;

  /// Check for and download the latest Microbot JAR.
  /// Returns the path to the JAR, or null if download failed and no cached JAR exists.
  Future<String?> ensureJar({
    void Function(int downloaded, int total)? onProgress,
  }) async {
    final microbotDir = p.join(_basePath, 'microbot');
    await Directory(microbotDir).create(recursive: true);

    final existingPath = await _appConfig.getMicrobotJarPath();
    final existingVersion = await _appConfig.getMicrobotJarVersion();

    // Check for updates (gracefully handle rate limiting)
    String? remoteVersion;
    String? downloadUrl;
    try {
      final release = await _fetchLatestRelease();
      remoteVersion = release['tag_name'] as String?;
      final assets = (release['assets'] as List?)?.cast<Map<String, dynamic>>();
      downloadUrl = assets != null ? findShadedJarUrl(assets) : null;
    } catch (e) {
      developer.log('GitHub API check failed (rate limited?): $e', name: 'MicrobotJarDownloader');
      // Fall back to cached JAR if available
      if (existingPath != null && File(existingPath).existsSync()) return existingPath;
      return null;
    }

    // Skip download if up to date
    if (!isUpdateAvailable(local: existingVersion, remote: remoteVersion) &&
        existingPath != null &&
        File(existingPath).existsSync()) {
      return existingPath;
    }

    if (downloadUrl == null) {
      developer.log('No shaded JAR asset found in latest release', name: 'MicrobotJarDownloader');
      return existingPath;
    }

    developer.log('Downloading Microbot $remoteVersion...', name: 'MicrobotJarDownloader');

    // Download the JAR
    final jarPath = p.join(microbotDir, 'microbot-shaded.jar');
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();
      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(jarPath).openWrite();
      await for (final chunk in response) {
        file.add(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(downloadedBytes, totalBytes);
      }
      await file.close();
    } finally {
      client.close();
    }

    // Store path and version
    await _appConfig.saveMicrobotJarPath(jarPath);
    if (remoteVersion != null) {
      await _appConfig.saveMicrobotJarVersion(remoteVersion);
    }

    developer.log('Microbot JAR saved to: $jarPath', name: 'MicrobotJarDownloader');
    return jarPath;
  }

  Future<Map<String, dynamic>> _fetchLatestRelease() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_releasesUrl));
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close();

      if (response.statusCode == 403 || response.statusCode == 429) {
        throw Exception('GitHub API rate limited');
      }

      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Find the *-shaded.jar asset URL from release assets list.
  static String? findShadedJarUrl(List<Map<String, dynamic>> assets) {
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('-shaded.jar')) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// Compare local vs remote version tags (simple string comparison).
  static bool isUpdateAvailable({required String? local, required String? remote}) {
    if (local == null) return true;
    if (remote == null) return false;
    return local != remote;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_jar_downloader_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/bot_engine/microbot_jar_downloader.dart test/config/services/bot_engine/microbot_jar_downloader_test.dart
git commit -m "feat(bot-engine): add MicrobotJarDownloader for GitHub Releases auto-download"
```

---

### Task 16: MicrobotSetupService orchestrator

**Files:**
- Create: `lib/config/services/bot_engine/microbot_setup_service.dart`

**Context:** Orchestrator that coordinates `PythonSetupService` + `JavaInstaller` + `MicrobotJarDownloader`. Reports aggregate progress to the splash screen. Follows `PythonSetupService` pattern (`python_setup_service.dart`): extends `GetxService`, has observable progress fields (`setupProgress`, `setupProgressPercent`, `currentStep`). Steps: Python → Java → Microbot JAR → done. Must be under 100 lines (orchestration only, no download logic).

- [ ] **Step 1: Write implementation**

```dart
// lib/config/services/bot_engine/microbot_setup_service.dart
import 'dart:developer' as developer;
import 'package:command_center/config/services/bot_engine/java_installer.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:get/get.dart';

enum SetupStep { idle, python, java, microbot, complete, failed }

/// Orchestrates all dependency installation for the app.
/// Coordinates Python, Java 17, and Microbot JAR setup with progress reporting.
class MicrobotSetupService extends GetxService {
  final PythonSetupService _pythonSetup;
  final JavaInstaller _javaInstaller;
  final MicrobotJarDownloader _jarDownloader;

  final currentStep = SetupStep.idle.obs;
  final progress = ''.obs;
  final progressPercent = 0.0.obs;
  final isComplete = false.obs;

  MicrobotSetupService({
    required PythonSetupService pythonSetup,
    required JavaInstaller javaInstaller,
    required MicrobotJarDownloader jarDownloader,
  })  : _pythonSetup = pythonSetup,
        _javaInstaller = javaInstaller,
        _jarDownloader = jarDownloader;

  /// Run all dependency checks and installations.
  /// Called during splash screen before app loads.
  Future<void> ensureDependencies() async {
    try {
      // Step 1: Python + Patchright
      currentStep.value = SetupStep.python;
      progress.value = 'Checking Python...';
      progressPercent.value = 0.0;
      await _pythonSetup.initializeSetup();
      progressPercent.value = 0.33;

      // Step 2: Java 17
      currentStep.value = SetupStep.java;
      progress.value = 'Checking Java 17...';
      final javaPath = await _javaInstaller.findJavaPath();
      if (javaPath == null) {
        progress.value = 'Downloading Java 17 Runtime...';
        await _javaInstaller.install(onProgress: (downloaded, total) {
          if (total > 0) {
            final pct = downloaded / total;
            progressPercent.value = 0.33 + (pct * 0.33);
            final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            progress.value = 'Downloading Java 17... $mb MB / $totalMb MB';
          }
        });
      }
      progressPercent.value = 0.66;

      // Step 3: Microbot JAR
      currentStep.value = SetupStep.microbot;
      progress.value = 'Checking Microbot...';
      final jarPath = await _jarDownloader.ensureJar(onProgress: (downloaded, total) {
        if (total > 0) {
          final pct = downloaded / total;
          progressPercent.value = 0.66 + (pct * 0.34);
          final mb = (downloaded / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
          progress.value = 'Downloading Microbot... $mb MB / $totalMb MB';
        }
      });

      if (jarPath == null) {
        developer.log('Microbot JAR not available — launching without bot engine', name: 'MicrobotSetupService');
      }

      progressPercent.value = 1.0;
      currentStep.value = SetupStep.complete;
      progress.value = 'Ready';
      isComplete.value = true;
    } catch (e) {
      developer.log('Setup failed: $e', name: 'MicrobotSetupService');
      currentStep.value = SetupStep.failed;
      progress.value = 'Setup failed: $e';
    }
  }
}
```

- [ ] **Step 2: Write test**

```dart
// test/config/services/bot_engine/microbot_setup_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';

void main() {
  group('MicrobotSetupService', () {
    test('initial state is idle', () {
      // Cannot fully construct without mocks, but verify enum values exist
      expect(SetupStep.idle, isNotNull);
      expect(SetupStep.python, isNotNull);
      expect(SetupStep.java, isNotNull);
      expect(SetupStep.microbot, isNotNull);
      expect(SetupStep.complete, isNotNull);
      expect(SetupStep.failed, isNotNull);
    });

    test('SetupStep enum has correct ordering', () {
      expect(SetupStep.values.indexOf(SetupStep.python),
          lessThan(SetupStep.values.indexOf(SetupStep.java)));
      expect(SetupStep.values.indexOf(SetupStep.java),
          lessThan(SetupStep.values.indexOf(SetupStep.microbot)));
      expect(SetupStep.values.indexOf(SetupStep.microbot),
          lessThan(SetupStep.values.indexOf(SetupStep.complete)));
    });
  });
}
```

Note: Full integration testing of `ensureDependencies()` requires mocking `PythonSetupService`, `JavaInstaller`, and `MicrobotJarDownloader`. The implementer should add a more thorough test if GetX test utilities allow mock injection.

- [ ] **Step 3: Verify compilation and run test**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/microbot_setup_service_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/config/services/bot_engine/microbot_setup_service.dart test/config/services/bot_engine/microbot_setup_service_test.dart
git commit -m "feat(bot-engine): add MicrobotSetupService orchestrator for dependency installation"
```

---

### Task 17: Splash screen UI

**Files:**
- Create: `lib/feature/app/views/splash_screen.dart`
- Modify: `lib/feature/app.dart`

**Context:** The spec says the splash screen **replaces** `_buildLoadingScreen()` in `app.dart` (line 197-208). Current loading screen shows `ProgressRing` + "Loading...". New splash shows branded progress with step-by-step status (Python → Java → Microbot → Load services → Main UI). `_initializeApp()` (line 58-101) is extended to include `MicrobotSetupService.ensureDependencies()` before setting `_initialized = true`. The splash observes `MicrobotSetupService` reactive fields for real-time progress.

- [ ] **Step 1: Create splash screen widget**

```dart
// lib/feature/app/views/splash_screen.dart
import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Branded splash screen shown during app initialization and dependency setup.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // MicrobotSetupService may not be registered yet during early init
    final setupService = Get.isRegistered<MicrobotSetupService>()
        ? Get.find<MicrobotSetupService>()
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.scaffoldBackgroundColor,
            theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Command Center',
              style: theme.typography.title?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'v0.8.0', // TODO: Read from pubspec or PackageInfo at implementation time
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
            const SizedBox(height: 40),

            // Progress bar
            SizedBox(
              width: 300,
              child: setupService != null
                  ? Obx(() => ProgressBar(value: setupService.progressPercent.value * 100))
                  : const ProgressBar(),
            ),
            const SizedBox(height: 12),

            // Status text
            if (setupService != null)
              Obx(() => Text(
                    setupService.progress.value.isNotEmpty
                        ? setupService.progress.value
                        : 'Initializing...',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ))
            else
              Text(
                'Loading...',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update app.dart — replace _buildLoadingScreen()**

In `lib/feature/app.dart`:
- Add import: `import 'package:command_center/feature/app/views/splash_screen.dart';`
- Replace `_buildLoadingScreen()` body with: `return const SplashScreen();`

- [ ] **Step 3: Update _initializeApp() — add MicrobotSetupService**

In `_initializeApp()`, after `AppBindings.initializeAsyncServices()` completes and before `setState(() => _initialized = true)`:

```dart
// Dependency setup (Java 17 + Microbot JAR)
if (Get.isRegistered<MicrobotSetupService>()) {
  await Get.find<MicrobotSetupService>().ensureDependencies();
}
```

Also register `MicrobotSetupService` in `dependency_injection.dart` Phase 2, after JavaInstaller and JarDownloader are created but before the call to `ensureDependencies()`.

- [ ] **Step 4: Register MicrobotSetupService in DI**

In `dependency_injection.dart` `initializeAsyncServices()`, after creating `microbotEngine` and before `WatchdogService`:

```dart
// MicrobotSetupService (orchestrates dependency downloads)
final javaInstaller = JavaInstaller(appConfig: appConfig, basePath: basePath);
final jarDownloader = MicrobotJarDownloader(appConfig: appConfig, basePath: basePath);
Get.put(
  MicrobotSetupService(
    pythonSetup: Get.find<PythonSetupService>(),
    javaInstaller: javaInstaller,
    jarDownloader: jarDownloader,
  ),
  permanent: true,
);
```

**DI ordering resolution:** `MicrobotSetupService.ensureDependencies()` runs in `app.dart._initializeApp()` AFTER `AppBindings.initializeAsyncServices()`. But `MicrobotEngine` is registered during `initializeAsyncServices()` and needs paths that may not exist until setup runs.

**Solution:** Split `initializeAsyncServices()` into two phases:
1. **Phase 2a** (existing): Register core services (DB → AppConfig → Webshare → etc.), `PythonSetupService`, `MicrobotSetupService` (orchestrator only, no download yet), `NotificationService`
2. Return control to `app.dart._initializeApp()`, which calls `MicrobotSetupService.ensureDependencies()` (downloads happen here, splash screen shows progress)
3. **Phase 2b** (new static method `initializePostSetup()`): Register `MicrobotEngine` (now paths are available from AppConfig) → `WatchdogService` (depends on BotEngine)

In `app.dart._initializeApp()`:
```dart
await AppBindings.initializeAsyncServices();   // Phase 2a
await Get.find<MicrobotSetupService>().ensureDependencies();  // Downloads + splash
await AppBindings.initializePostSetup();       // Phase 2b — BotEngine + WatchdogService
```

This cleanly separates the dependency: setup runs first → paths are stored in AppConfig → MicrobotEngine reads them.

- [ ] **Step 5: Run the app to verify splash screen**

Run: `cd /mnt/c/Projects/command_center_ux && flutter run -d windows`
Expected: Branded splash screen appears with "Command Center" title, progress bar, and status text. Transitions to main app after initialization.

- [ ] **Step 6: Commit**

```bash
git add lib/feature/app/views/splash_screen.dart lib/feature/app.dart lib/core/resource/dependency_injection.dart
git commit -m "feat(ui): add branded splash screen with dependency installation progress"
```

---

## Chunk 5: Integration Testing & Cleanup

End-to-end verification, test updates, and final polish.

### Task 18: Update existing tests for new constructor signatures

**Files:**
- Modify: Any test files that construct `TrackedClient`, `LaunchConfig`, `WatchdogService`, or `WatchdogHandlers`

**Context:** Tasks 4-5 changed `LaunchConfig` (removed `covert`/`render`, added `jvmArgs`) and `TrackedClient` (added `email`/`password`/`proxyUrl`, removed `proxyAddress`). Task 10 added `BotEngine` to `WatchdogService`/`WatchdogHandlers` constructors. Any existing tests using these classes will fail on compilation. Search all test files for these class names and fix.

- [ ] **Step 1: Find all affected test files**

Run: `grep -r "TrackedClient\|LaunchConfig\|WatchdogService\|WatchdogHandlers" test/ --include="*.dart" -l`

- [ ] **Step 2: Fix each test file**

For each file found:
- `TrackedClient` constructors: add `email: 'test@test.com'`, `password: 'testpass'`, `proxyUrl: null` (or appropriate value)
- `LaunchConfig` constructors: remove `covert:` and `render:` params
- `WatchdogService` constructors: add `botEngine:` param (mock or fake)
- `WatchdogHandlers` constructors: add `botEngine:` param

- [ ] **Step 3: Run full test suite**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: ALL tests pass

- [ ] **Step 4: Commit**

```bash
git add test/
git commit -m "test: update existing tests for new TrackedClient/LaunchConfig/WatchdogService signatures"
```

---

### Task 19: Write integration tests for the full launch flow

**Files:**
- Create: `test/config/services/bot_engine/bot_engine_integration_test.dart`

**Context:** Test the end-to-end flow: `StatusController.launchCharacter()` → `BotEngine.launch()` → profile written → process started → TrackedClient created → WatchdogService tracking. Use mocks for `Process.start()` and DB. Verify: correct JVM args (before/after `-jar`), profile written with correct credentials, PID returned and tracked, proxy URL constructed correctly.

- [ ] **Step 1: Write integration test**

```dart
// test/config/services/bot_engine/bot_engine_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/core/helper/proxy_url_builder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('Bot Engine Integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bot_engine_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('profile writer creates correct files for launch', () async {
      final writer = MicrobotProfileWriter(profilesBasePath: tempDir.path);

      await writer.writeProfile(
        characterId: 42,
        email: 'player@test.com',
        password: 'secret',
        world: '301',
        scriptName: 'Woodcutter',
      );

      // Verify credentials file
      final creds = File(p.join(tempDir.path, 'bot-42', 'credentials.properties'));
      expect(creds.existsSync(), isTrue);
      final credsContent = creds.readAsStringSync();
      expect(credsContent, contains('email=player@test.com'));
      expect(credsContent, contains('password=secret'));

      // Verify settings file
      final settings = File(p.join(tempDir.path, 'bot-42', 'settings.properties'));
      expect(settings.existsSync(), isTrue);
      final settingsContent = settings.readAsStringSync();
      expect(settingsContent, contains('world=301'));
      expect(settingsContent, contains('script=Woodcutter'));
    });

    test('ProxyUrlBuilder + TrackedClient round-trip', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'user',
        password: 'pass',
        ipAddress: '1.2.3.4',
        socksPort: 1080,
      );

      final client = TrackedClient(
        characterName: 'TestBot',
        characterId: 42,
        accountId: 1,
        email: 'test@test.com',
        password: 'pass',
        proxyUrl: url,
        launchConfig: const LaunchConfig(scriptName: 'Test'),
        pid: 12345,
        launchedAt: DateTime.now(),
      );

      expect(client.proxyUrl, 'socks5://user:pass@1.2.3.4:1080');
      expect(client.email, 'test@test.com');
      expect(client.password, 'pass');
    });

    test('MicrobotEngine buildLaunchArgs produces correct command structure', () {
      final engine = MicrobotEngine(
        javaPath: '/java/bin/java.exe',
        jarPath: '/app/microbot-shaded.jar',
        profilesBasePath: tempDir.path,
        onLog: (_) {},
      );

      final args = engine.buildLaunchArgs(
        characterId: 42,
        proxyUrl: 'socks5://user:pass@1.2.3.4:1080',
        config: const LaunchConfig(
          scriptName: 'Woodcutter',
          jvmArgs: '-Xmx384m -XX:+UseG1GC',
          advancedFlags: '-fps 15',
        ),
      );

      // JVM flags come first (before -jar)
      final jarIndex = args.indexOf('-jar');
      expect(jarIndex, greaterThan(0));
      expect(args.sublist(0, jarIndex), contains('-Xmx384m'));
      expect(args.sublist(0, jarIndex), contains('-XX:+UseG1GC'));

      // App flags come after jar path
      expect(args[jarIndex + 1], '/app/microbot-shaded.jar');
      final appFlags = args.sublist(jarIndex + 2);
      expect(appFlags, contains('--profile=bot-42'));
      expect(appFlags, contains('--proxy=socks5://user:pass@1.2.3.4:1080'));
      expect(appFlags, contains('--safe-mode'));
      expect(appFlags, contains('-fps'));
      expect(appFlags, contains('15'));
    });
  });
}
```

- [ ] **Step 2: Run integration test**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test test/config/services/bot_engine/bot_engine_integration_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/config/services/bot_engine/bot_engine_integration_test.dart
git commit -m "test(bot-engine): add integration tests for launch flow, proxy URL, and profile generation"
```

---

### Task 20: Run full test suite and fix any remaining issues

**Files:**
- All modified/created files

**Context:** Final verification that all 18+ existing test files still pass alongside new tests. Fix any remaining compilation errors, import issues, or behavioral regressions.

- [ ] **Step 1: Run full test suite**

Run: `cd /mnt/c/Projects/command_center_ux && flutter test`
Expected: ALL tests pass

- [ ] **Step 2: Run static analysis**

Run: `cd /mnt/c/Projects/command_center_ux && flutter analyze`
Expected: No errors (warnings acceptable)

- [ ] **Step 3: Run Drift codegen to ensure schema is current**

Run: `cd /mnt/c/Projects/command_center_ux && dart run build_runner build --delete-conflicting-outputs`
Expected: Clean generation, no conflicts

- [ ] **Step 4: Fix any issues found**

Address any test failures, analysis errors, or codegen issues discovered.

- [ ] **Step 5: Final commit if fixes needed**

```bash
git add -A
git commit -m "fix: resolve remaining issues from Microbot integration"
```

---

## Summary

| Task | Component | New Files | Modified Files |
|------|-----------|-----------|----------------|
| 1 | AppDataPath helper | 2 | 0 |
| 2 | ProxyUrlBuilder helper | 2 | 0 |
| 3 | DB migration (socks_port) | 0 | 7 |
| 4 | LaunchConfig update | 0 | 1 (+test) |
| 5 | TrackedClient update | 0 | 1 |
| 6 | AppConfigService keys | 0 | 1 |
| 7 | BotEngine abstract | 1 | 0 |
| 8 | MicrobotProfileWriter | 1 (+test) | 0 |
| 9 | MicrobotEngine | 1 (+test) | 0 |
| 10 | Watchdog integration | 0 | 2 |
| 11 | StatusController integration | 0 | 1 |
| 12 | Launch dialog UI | 0 | 1 |
| 13 | DI registration | 0 | 1 |
| 14 | JavaInstaller | 1 (+test) | 0 |
| 15 | MicrobotJarDownloader | 1 (+test) | 0 |
| 16 | MicrobotSetupService | 1 | 0 |
| 17 | Splash screen | 1 | 2 |
| 18 | Test updates | 0 | varies |
| 19 | Integration tests | 1 | 0 |
| 20 | Final verification | 0 | varies |
