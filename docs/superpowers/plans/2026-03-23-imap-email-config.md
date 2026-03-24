# IMAP Email Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add IMAP email configuration UI so users can set up their catch-all mailbox for Jagex verification emails, gated as a required onboarding step.

**Architecture:** New `ImapConfigService` owns IMAP config (matching the `IpqsService` pattern). IMAP methods move out of `AppConfigService`. A new dialog + integration tile in Settings provides the UI. OnboardingService gates account creation on IMAP being configured.

**Tech Stack:** Flutter, Fluent UI, GetX (state/DI), Drift ORM (SQLite via ConfigRepository)

**Spec:** `docs/superpowers/specs/2026-03-23-imap-email-config-design.md`

---

### Task 1: Create ImapConfigService

**Files:**
- Create: `lib/config/services/imap/imap_config_service.dart`
- Test: `test/config/services/imap_config_service_test.dart`

- [ ] **Step 1: Write the test file**

Uses in-memory SQLite via `AppDatabase.forTesting(NativeDatabase.memory())` + `ConfigRepositoryImpl`, matching the project's existing repository test pattern. The `ImapConfigService` is initialized by injecting a `DatabaseService` backed by the in-memory DB.

```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/data/repositories/config_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ImapConfigService service;

  setUp(() async {
    Get.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Wire a DatabaseService with the in-memory DB so ImapConfigService can
    // resolve it via Get.find<DatabaseService>().configRepository.
    final dbService = DatabaseService();
    // We need to register the service and make configRepository available.
    // DatabaseService.init() creates a file-based DB, so we manually set up
    // the repo by registering a mock-like service with exposed configRepository.
    Get.put<DatabaseService>(dbService, permanent: true);
    // Override the configRepository by using the test helper
    final configRepo = ConfigRepositoryImpl(db);
    Get.put<ConfigRepositoryImpl>(configRepo, permanent: true);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  // Helper: create and init a service that uses the in-memory config repo.
  // Since ImapConfigService.init() calls Get.find<DatabaseService>().configRepository,
  // and our DatabaseService isn't fully initialized, we test ImapConfigService
  // by creating it directly with a test-friendly init pattern.
  //
  // Actually, since DatabaseService.configRepository is a late final field set by init(),
  // and we can't call init() (it creates a file DB), we need a different approach.
  // Let's test ImapConfigService by testing its behavior when repository is null
  // (matching IpqsService test pattern) AND by testing the repository logic directly.

  group('ImapConfigService - without DB (null repository)', () {
    test('init without DatabaseService sets isConfigured false', () async {
      Get.reset(); // no DatabaseService registered
      service = await ImapConfigService().init();
      expect(service.isConfigured.value, isFalse);
      expect(service.cachedHost, isNull);
    });

    test('saveConfig fails when repository not initialized', () async {
      Get.reset();
      service = await ImapConfigService().init();
      final result = await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );
      expect(result, isA<Failure>());
      expect(service.isConfigured.value, isFalse);
    });

    test('clearConfig fails when repository not initialized', () async {
      Get.reset();
      service = await ImapConfigService().init();
      final result = await service.clearConfig();
      expect(result, isA<Failure>());
    });

    test('saveConfig rejects empty fields', () async {
      Get.reset();
      service = await ImapConfigService().init();
      final result = await service.saveConfig(host: '', user: 'u', pass: 'p');
      expect(result, isA<Failure>());
    });
  });

  group('ImapConfigService - with in-memory DB', () {
    late DatabaseService dbService;

    setUp(() async {
      Get.reset();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dbService = await _createTestDatabaseService(db);
      Get.put<DatabaseService>(dbService, permanent: true);
      service = await ImapConfigService().init();
    });

    test('init seeds default host and sets isConfigured false', () {
      expect(service.isConfigured.value, isFalse);
      expect(service.cachedHost, 'mail.privateemail.com');
    });

    test('getHost returns seeded default', () async {
      expect(await service.getHost(), 'mail.privateemail.com');
    });

    test('getUser returns null when not configured', () async {
      expect(await service.getUser(), isNull);
    });

    test('saveConfig stores all 3 values and sets isConfigured true', () async {
      final result = await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );

      expect(result, isA<Success>());
      expect(service.isConfigured.value, isTrue);
      expect(service.cachedHost, 'imap.example.com');
      expect(await service.getHost(), 'imap.example.com');
      expect(await service.getUser(), 'user@example.com');
      expect(await service.getPass(), 'secret');
    });

    test('clearConfig removes user/pass and resets host to default', () async {
      await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );

      final result = await service.clearConfig();

      expect(result, isA<Success>());
      expect(service.isConfigured.value, isFalse);
      expect(service.cachedHost, 'mail.privateemail.com');
      expect(await service.getUser(), isNull);
      expect(await service.getPass(), isNull);
      expect(await service.getHost(), 'mail.privateemail.com');
    });

    test('isConfigured persists across re-init', () async {
      await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );

      final service2 = await ImapConfigService().init();
      expect(service2.isConfigured.value, isTrue);
      expect(service2.cachedHost, 'imap.example.com');
    });
  });
}

/// Creates a DatabaseService backed by the given in-memory AppDatabase.
/// This bypasses the file-based DB creation in DatabaseService.init().
Future<DatabaseService> _createTestDatabaseService(AppDatabase db) async {
  final service = _TestDatabaseService(db);
  return service;
}

/// Test-only DatabaseService subclass that accepts an injected AppDatabase.
class _TestDatabaseService extends DatabaseService {
  _TestDatabaseService(AppDatabase db) {
    configRepository = ConfigRepositoryImpl(db);
  }
}
```

Note: `DatabaseService.configRepository` is `late final`, set in `init()`. The test subclass `_TestDatabaseService` sets it in its constructor instead. If `late final` complains about being set outside `init()`, the implementer should check if `DatabaseService` allows this pattern — if not, add a `DatabaseService.forTesting(AppDatabase db)` named constructor to `DatabaseService` that sets `configRepository` directly (a one-line change). Alternatively, test only the null-repository path and trust that the DB integration works via the existing `ConfigRepositoryImpl` tests.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test test/config/services/imap_config_service_test.dart`
Expected: FAIL — `imap_config_service.dart` does not exist yet.

- [ ] **Step 3: Create ImapConfigService**

Create `lib/config/services/imap/imap_config_service.dart`:

```dart
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/repositories/config_repository.dart';
import 'package:get/get.dart';

class ImapConfigService extends GetxService {
  static const String _keyHost = 'imap_host';
  static const String _keyUser = 'imap_user';
  static const String _keyPass = 'imap_pass';
  static const String _defaultHost = 'mail.privateemail.com';

  ConfigRepository? _configRepository;

  final isConfigured = false.obs;
  String? cachedHost;

  Future<ImapConfigService> init() async {
    try {
      _configRepository = Get.find<DatabaseService>().configRepository;
      await _seedDefaults();
      await _loadConfig();
    } catch (e) {
      logger.e('Error initializing ImapConfigService: $e');
    }
    return this;
  }

  Future<void> _seedDefaults() async {
    if (_configRepository == null) return;
    final existing = await _configRepository!.getValue(_keyHost);
    if (existing == null) {
      await _configRepository!.setValue(_keyHost, _defaultHost);
    }
  }

  Future<void> _loadConfig() async {
    if (_configRepository == null) return;
    cachedHost = await _configRepository!.getValue(_keyHost);
    final user = await _configRepository!.getValue(_keyUser);
    final pass = await _configRepository!.getValue(_keyPass);
    isConfigured.value = user != null && pass != null;
  }

  Future<Result<void>> saveConfig({
    required String host,
    required String user,
    required String pass,
  }) async {
    if (host.isEmpty || user.isEmpty || pass.isEmpty) {
      return Result.failure('All fields are required');
    }
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }
      await _configRepository!.setValue(_keyHost, host);
      await _configRepository!.setValue(_keyUser, user);
      await _configRepository!.setValue(_keyPass, pass);
      cachedHost = host;
      isConfigured.value = true;
      return Result.success(null);
    } catch (e) {
      logger.e('Error saving IMAP config: $e');
      return Result.failure('Failed to save IMAP config.');
    }
  }

  Future<Result<void>> clearConfig() async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }
      await _configRepository!.deleteValue(_keyUser);
      await _configRepository!.deleteValue(_keyPass);
      await _configRepository!.setValue(_keyHost, _defaultHost);
      cachedHost = _defaultHost;
      isConfigured.value = false;
      return Result.success(null);
    } catch (e) {
      logger.e('Error clearing IMAP config: $e');
      return Result.failure('Failed to clear IMAP config.');
    }
  }

  Future<String?> getHost() async {
    return _configRepository?.getValue(_keyHost);
  }

  Future<String?> getUser() async {
    return _configRepository?.getValue(_keyUser);
  }

  Future<String?> getPass() async {
    return _configRepository?.getValue(_keyPass);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test test/config/services/imap_config_service_test.dart`
Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/imap/imap_config_service.dart test/config/services/imap_config_service_test.dart
git commit -m "feat(imap): add ImapConfigService with save/clear/getters"
```

---

### Task 2: Remove IMAP from AppConfigService + wire DI + update AutomationService

**Files:**
- Modify: `lib/config/services/app_config_service.dart` (remove lines 17-19 constants, 57-64 seed, 163-176 getters)
- Modify: `lib/core/resource/dependency_injection.dart` (add ImapConfigService registration at line 124-125)
- Modify: `lib/config/services/automation/automation_service.dart` (update lines 211-214)

- [ ] **Step 1: Remove IMAP constants, seed, and getters from AppConfigService**

In `lib/config/services/app_config_service.dart`:

Remove these 3 constants (lines 17-19):
```dart
  static const String _keyImapHost = 'imap_host';
  static const String _keyImapUser = 'imap_user';
  static const String _keyImapPass = 'imap_pass';
```

Remove `_seedDefaults()` method entirely (lines 57-64):
```dart
  /// Seed default IMAP host if not already set (credentials must be configured via UI)
  Future<void> _seedDefaults() async {
    if (_configRepository == null) return;
    final existing = await _configRepository!.getValue(_keyImapHost);
    if (existing == null) {
      await _configRepository!.setValue(_keyImapHost, 'mail.privateemail.com');
    }
  }
```

Remove the `await _seedDefaults();` call in `init()` (line 49).

Remove the 3 getter methods (lines 163-176):
```dart
  /// Get IMAP host
  Future<String?> getImapHost() async {
    return _configRepository?.getValue(_keyImapHost);
  }

  /// Get IMAP user
  Future<String?> getImapUser() async {
    return _configRepository?.getValue(_keyImapUser);
  }

  /// Get IMAP password
  Future<String?> getImapPass() async {
    return _configRepository?.getValue(_keyImapPass);
  }
```

- [ ] **Step 2: Register ImapConfigService in DI**

In `lib/core/resource/dependency_injection.dart`, add import at top:
```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
```

After step 4 (IpqsService, line 124), insert:
```dart
    // 4b. ImapConfigService (depends on DatabaseService)
    final imapConfigService = await ImapConfigService().init();
    Get.put<ImapConfigService>(imapConfigService, permanent: true);
```

Update the OnboardingService comment (line 133) to include ImapConfigService:
```dart
    // 7. OnboardingService (depends on WebshareService, IpqsService, ImapConfigService)
```

- [ ] **Step 3: Update AutomationService to use ImapConfigService**

In `lib/config/services/automation/automation_service.dart`, add import:
```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
```

Replace lines 211-214 in `createAccount()`:
```dart
          final cfg = Get.find<AppConfigService>();
          final imapHost = await cfg.getImapHost();
          final imapUser = await cfg.getImapUser();
          final imapPass = await cfg.getImapPass();
```
With:
```dart
          final imapService = Get.find<ImapConfigService>();
          final imapHost = await imapService.getHost();
          final imapUser = await imapService.getUser();
          final imapPass = await imapService.getPass();
```

Remove the `AppConfigService` import (line 1 of automation_service.dart) — it is no longer used in this file after the change. (`AppConfigService` only appeared at line 211 which we just replaced.)

- [ ] **Step 4: Run existing tests to verify no regressions**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test`
Expected: All tests pass (existing IMAP tests don't exist; onboarding tests may still pass since they don't call the IMAP getters).

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/app_config_service.dart lib/core/resource/dependency_injection.dart lib/config/services/automation/automation_service.dart
git commit -m "refactor(imap): move IMAP config from AppConfigService to ImapConfigService"
```

---

### Task 3: Update OnboardingService + fix existing tests

**Files:**
- Modify: `lib/config/services/onboarding_service.dart`
- Modify: `test/config/services/onboarding_service_test.dart`

- [ ] **Step 1: Update OnboardingService tests first**

In `test/config/services/onboarding_service_test.dart`, update both tests to include `isImapConfigured`:

Replace the `resetOnboarding` test (lines 13-28):
```dart
    test('resetOnboarding resets all observable flags to false', () async {
      final service = OnboardingService();

      // Manually set flags to true to simulate configured state
      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isImapConfigured.value = true;
      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isTrue);

      await service.resetOnboarding();

      expect(service.isWebshareConfigured.value, isFalse);
      expect(service.isIpqsConfigured.value, isFalse);
      expect(service.isImapConfigured.value, isFalse);
      expect(service.isInitialSyncComplete.value, isFalse);
      expect(service.isOnboardingComplete, isFalse);
    });
```

Replace the `isOnboardingComplete` test (lines 30-41):
```dart
    test('isOnboardingComplete requires all four flags', () {
      final service = OnboardingService();

      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isImapConfigured.value = false;
      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isFalse);

      service.isImapConfigured.value = true;
      expect(service.isOnboardingComplete, isTrue);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test test/config/services/onboarding_service_test.dart`
Expected: FAIL — `isImapConfigured` does not exist yet on OnboardingService.

- [ ] **Step 3: Update OnboardingService**

In `lib/config/services/onboarding_service.dart`:

Add import at top:
```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
```

Add constant after line 11 (`_initialSyncCompleteKey`):
```dart
  static const String _imapConfiguredKey = 'imap_configured';
```

Add observable after line 16 (`isInitialSyncComplete`):
```dart
  final isImapConfigured = false.obs;
```

Update `isOnboardingComplete` getter (line 23-26) to:
```dart
  bool get isOnboardingComplete =>
      isWebshareConfigured.value &&
      isIpqsConfigured.value &&
      isImapConfigured.value &&
      isInitialSyncComplete.value;
```

In `checkOnboardingStatus()`, after the IPQS block (after line 78), add:
```dart
      // Check IMAP configuration
      try {
        final imapService = Get.find<ImapConfigService>();
        isImapConfigured.value = imapService.isConfigured.value;

        _workers.add(ever(imapService.isConfigured, (configured) {
          isImapConfigured.value = configured;
          if (configured) {
            _saveImapConfigured();
          }
        }));
      } catch (_) {
        isImapConfigured.value = prefs.getBool(_imapConfiguredKey) ?? false;
      }
```

Add helper after `_saveIpqsConfigured()` (after line 101):
```dart
  Future<void> _saveImapConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_imapConfiguredKey, true);
  }
```

In `resetOnboarding()`, after `await prefs.remove(_initialSyncCompleteKey);` (line 119), add:
```dart
    await prefs.remove(_imapConfiguredKey);
```

After the IPQS clearing block (after line 136), add:
```dart
    // IMAP config lives in SQLite via ImapConfigService
    try {
      final imapService = Get.find<ImapConfigService>();
      await imapService.clearConfig();
    } catch (_) {
      // ImapConfigService may not be registered in test/debug scenarios
    }
```

After `isInitialSyncComplete.value = false;` (line 140), add:
```dart
    isImapConfigured.value = false;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test test/config/services/onboarding_service_test.dart`
Expected: Both tests PASS.

- [ ] **Step 5: Run full test suite**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/config/services/onboarding_service.dart test/config/services/onboarding_service_test.dart
git commit -m "feat(imap): add IMAP to onboarding requirements, gate account creation"
```

---

### Task 4: Update widget tree plumbing (AppLifecycle, app.dart, AppNavigation)

**Files:**
- Modify: `lib/feature/app/views/components/app_lifecycle.dart` (lines 6, 18-33, 58-66, 71-83)
- Modify: `lib/feature/app.dart` (line 128)
- Modify: `lib/feature/app/views/components/app_navigation.dart` (lines 1, 17-41, 96-102)

- [ ] **Step 1: Update AppLifecycle**

In `lib/feature/app/views/components/app_lifecycle.dart`:

Add import:
```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
```

Add `ImapConfigService?` to `ResolvedServices` class — add field (after line 24):
```dart
  final ImapConfigService? imapConfigService;
```

Add to constructor (after `this.appConfigService`):
```dart
    this.imapConfigService,
```

Add to `resolveServices()` (after `appConfigService` line 65):
```dart
      imapConfigService: _tryFind<ImapConfigService>(),
```

Add IMAP watcher to `setupOnboardingWorkers()` (after line 81):
```dart
      workers.add(ever(obs.isImapConfigured, check));
```

- [ ] **Step 2: Update app.dart**

In `lib/feature/app.dart`, add `imapConfigService` to the `AppNavigation` constructor call (after line 128):
```dart
                        imapConfigService: _services.imapConfigService,
```

- [ ] **Step 3: Update AppNavigation**

In `lib/feature/app/views/components/app_navigation.dart`:

Add import:
```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
```

Add field (after line 27):
```dart
  final ImapConfigService? imapConfigService;
```

Add to constructor (after `this.appConfigService`):
```dart
    this.imapConfigService,
```

Pass to SettingsSection (add after line 101):
```dart
                imapConfigService: imapConfigService,
```

- [ ] **Step 4: Add imapConfigService parameter to SettingsSection (so Task 4 compiles)**

In `lib/feature/app/views/sections/settings_section.dart`:

Add import:
```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
```

Add field (after line 19 `appConfigService`):
```dart
  final ImapConfigService? imapConfigService;
```

Add to constructor (after `this.appConfigService`):
```dart
    this.imapConfigService,
```

(The integration tile itself is added in Task 6.)

- [ ] **Step 5: Run full test suite**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test`
Expected: All tests pass — code compiles at this point.

- [ ] **Step 6: Commit**

```bash
git add lib/feature/app/views/components/app_lifecycle.dart lib/feature/app.dart lib/feature/app/views/components/app_navigation.dart lib/feature/app/views/sections/settings_section.dart
git commit -m "feat(imap): wire ImapConfigService through widget tree"
```

---

### Task 5: Create ImapConfigDialog

**Files:**
- Create: `lib/feature/app/views/dialogs/imap_config_dialog.dart`

- [ ] **Step 1: Create the dialog**

Create `lib/feature/app/views/dialogs/imap_config_dialog.dart`:

```dart
import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/feature/app/views/components/api_key_configured_banner.dart';
import 'package:command_center/feature/app/views/components/connect_action_button.dart';
import 'package:command_center/feature/app/views/components/info_bar_helper.dart';
import 'package:command_center/feature/app/views/components/processing_status_bar.dart';
import 'package:command_center/feature/app/views/components/unlink_action_button.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ImapConfigDialog extends StatefulWidget {
  const ImapConfigDialog._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ImapConfigDialog._(),
    );
  }

  @override
  State<ImapConfigDialog> createState() => _ImapConfigDialogState();
}

class _ImapConfigDialogState extends State<ImapConfigDialog> {
  final _hostController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _isProcessing = false.obs;
  final _statusMessage = Rxn<String>();
  final _isError = false.obs;

  late final bool _isConfigured;

  @override
  void initState() {
    super.initState();
    bool configured = false;
    try {
      final service = Get.find<ImapConfigService>();
      configured = service.isConfigured.value;
      _hostController.text = service.cachedHost ?? 'mail.privateemail.com';
    } catch (_) {
      _hostController.text = 'mail.privateemail.com';
    }
    _isConfigured = configured;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _userController.dispose();
    _passController.dispose();
    _isProcessing.close();
    _statusMessage.close();
    _isError.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 450),
      title: Text(
          _isConfigured ? 'Email Configuration' : 'Configure Email (IMAP)'),
      content: _isConfigured
          ? _buildConfiguredContent()
          : _buildFormContent(context),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_isConfigured)
          UnlinkActionButton(
            isProcessing: _isProcessing,
            onUnlink: () => _handleUnlink(context),
          )
        else
          ConnectActionButton(
            isProcessing: _isProcessing,
            label: 'Save',
            icon: FluentIcons.save,
            onConnect: () => _handleSave(context),
          ),
      ],
    );
  }

  Widget _buildConfiguredContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApiKeyConfiguredBanner(
          title: 'Email Connected',
          subtitle: 'IMAP verification is active',
        ),
        ProcessingStatusBar(
          statusMessage: _statusMessage,
          isError: _isError,
          isProcessing: _isProcessing,
        ),
      ],
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
            'Configure your IMAP mailbox for Jagex email verification.'),
        const SizedBox(height: 16),
        ..._buildFormFields(context),
        const SizedBox(height: 8),
        Text(
          'Uses IMAP over SSL (port 993). Your catch-all mailbox for '
          'receiving Jagex verification emails.',
          style: TextStyle(
            fontSize: 12,
            color: FluentTheme.of(context).inactiveColor,
          ),
        ),
        ProcessingStatusBar(
          statusMessage: _statusMessage,
          isError: _isError,
          isProcessing: _isProcessing,
        ),
      ],
    );
  }

  List<Widget> _buildFormFields(BuildContext context) {
    return [
      Obx(() => InfoLabel(
            label: 'IMAP Host',
            child: TextBox(
              controller: _hostController,
              placeholder: 'mail.privateemail.com',
              enabled: !_isProcessing.value,
            ),
          )),
      const SizedBox(height: 12),
      Obx(() => InfoLabel(
            label: 'Email / Username',
            child: TextBox(
              controller: _userController,
              placeholder: 'your@email.com',
              enabled: !_isProcessing.value,
            ),
          )),
      const SizedBox(height: 12),
      Obx(() => InfoLabel(
            label: 'Password',
            child: TextBox(
              controller: _passController,
              placeholder: 'IMAP password',
              obscureText: true,
              enabled: !_isProcessing.value,
            ),
          )),
    ];
  }

  Future<void> _handleSave(BuildContext outerContext) async {
    if (_hostController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty) {
      _statusMessage.value = 'All fields are required';
      _isError.value = true;
      return;
    }
    _isProcessing.value = true;
    _statusMessage.value = 'Saving...';
    _isError.value = false;
    try {
      final result = await Get.find<ImapConfigService>().saveConfig(
        host: _hostController.text,
        user: _userController.text,
        pass: _passController.text,
      );
      switch (result) {
        case Success():
          if (mounted) Navigator.of(context).pop();
          if (outerContext.mounted) {
            showInfoBarToast(outerContext,
                title: 'Success',
                message: 'Email (IMAP) configured!',
                severity: InfoBarSeverity.success);
          }
        case Failure(:final message):
          _statusMessage.value = message;
          _isError.value = true;
      }
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      _isProcessing.value = false;
    }
  }

  Future<void> _handleUnlink(BuildContext outerContext) async {
    _isProcessing.value = true;
    _statusMessage.value = 'Unlinking...';
    _isError.value = false;
    try {
      final result = await Get.find<ImapConfigService>().clearConfig();
      switch (result) {
        case Success():
          if (mounted) Navigator.of(context).pop();
          if (outerContext.mounted) {
            showInfoBarToast(outerContext,
                title: 'Unlinked',
                message: 'Email (IMAP) has been disconnected.',
                severity: InfoBarSeverity.warning);
          }
        case Failure(:final message):
          _statusMessage.value = message;
          _isError.value = true;
      }
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      _isProcessing.value = false;
    }
  }
}
```

- [ ] **Step 2: Verify line count**

Run: `wc -l lib/feature/app/views/dialogs/imap_config_dialog.dart`
Expected: ~200 lines (at or under the 200-line dialog ceiling).

- [ ] **Step 3: Commit**

```bash
git add lib/feature/app/views/dialogs/imap_config_dialog.dart
git commit -m "feat(imap): add ImapConfigDialog with 3-field form"
```

---

### Task 6: Add IMAP tile to Settings + onboarding step

**Files:**
- Modify: `lib/feature/app/views/sections/settings_section.dart`
- Modify: `lib/feature/app/views/sections/onboarding_section.dart`

- [ ] **Step 1: Update SettingsSection**

In `lib/feature/app/views/sections/settings_section.dart`:

Add import (the `imap_config_service.dart` import and `imapConfigService` field were already added in Task 4):
```dart
import 'package:command_center/feature/app/views/dialogs/imap_config_dialog.dart';
```

In `_buildIntegrationsCard`, after `_buildIpqsIntegrationTile(context),` (line 161) and its spacer (line 162), add:
```dart
          _buildImapIntegrationTile(context),
          const SizedBox(height: 12),
```

Add the new method after `_buildIpqsIntegrationTile` (after line 212):
```dart
  Widget _buildImapIntegrationTile(BuildContext context) {
    final imap = imapConfigService;
    if (imap == null) {
      return IntegrationTile(
        icon: FluentIcons.mail,
        title: 'Email (IMAP)',
        description: 'Email verification for account creation',
        isConfigured: false,
        onConfigure: () => ImapConfigDialog.show(context),
      );
    }
    return Obx(() => IntegrationTile(
          icon: FluentIcons.mail,
          title: 'Email (IMAP)',
          description: 'Email verification for account creation',
          isConfigured: imap.isConfigured.value,
          onConfigure: () => ImapConfigDialog.show(context),
        ));
  }
```

- [ ] **Step 2: Update OnboardingSection**

In `lib/feature/app/views/sections/onboarding_section.dart`:

Add import:
```dart
import 'package:command_center/feature/app/views/dialogs/imap_config_dialog.dart';
```

Update the description text (line 48) to:
```dart
                  'Configure your integrations to start managing proxies and creating accounts.',
```

In `_buildSetupChecklist`, add `isImapComplete` variable (after line 75):
```dart
      final isImapComplete = onboardingService!.isImapConfigured.value;
```

After the IPQS `SetupChecklistItem` (after line 91), add:
```dart
          const SizedBox(height: 12),
          SetupChecklistItem(
            title: 'Configure Email (IMAP)',
            subtitle: 'Set up email verification for account creation',
            isComplete: isImapComplete,
            isEnabled: isIpqsComplete,
            onTap: () => ImapConfigDialog.show(context),
          ),
```

- [ ] **Step 3: Run full test suite**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test`
Expected: All tests pass.

- [ ] **Step 4: Verify file sizes are under ceiling**

Run: `wc -l lib/feature/app/views/sections/settings_section.dart lib/feature/app/views/sections/onboarding_section.dart`
Expected: settings_section ~235 lines (under 300), onboarding_section ~108 lines (under 300).

- [ ] **Step 5: Commit**

```bash
git add lib/feature/app/views/sections/settings_section.dart lib/feature/app/views/sections/onboarding_section.dart
git commit -m "feat(imap): add IMAP integration tile in Settings and onboarding step"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run full test suite**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter test`
Expected: All tests pass.

- [ ] **Step 2: Verify the app compiles**

Run: `cd C:/Users/Juanfra/projects/command_center && flutter build windows --debug 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 3: Verify file size ceilings**

Run:
```bash
wc -l lib/config/services/imap/imap_config_service.dart lib/config/services/app_config_service.dart lib/config/services/onboarding_service.dart lib/feature/app/views/dialogs/imap_config_dialog.dart lib/feature/app/views/sections/settings_section.dart lib/feature/app/views/sections/onboarding_section.dart
```

Expected limits:
- `imap_config_service.dart`: ~90 lines (service ceiling: 250)
- `app_config_service.dart`: ~280 lines (still over 250 — pre-existing, not introduced by this work)
- `onboarding_service.dart`: ~175 lines (service ceiling: 250)
- `imap_config_dialog.dart`: ~200 lines (dialog ceiling: 200)
- `settings_section.dart`: ~235 lines (section ceiling: 300)
- `onboarding_section.dart`: ~108 lines (section ceiling: 300)
