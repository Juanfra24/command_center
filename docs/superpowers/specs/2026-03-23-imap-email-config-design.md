# IMAP Email Configuration

Add UI for configuring the IMAP mailbox used to receive Jagex verification emails during account creation. The backend (Python IMAP poller, env var passing, automation service integration) is already fully wired — only the configuration surface and onboarding gate are missing.

## Context

- Single catch-all mailbox (`*@domain.com` -> one IMAP inbox)
- Default host: `mail.privateemail.com` (Namecheap Private Email)
- All three fields configurable: host, user, password
- IMAP configuration is **required** before account creation can proceed

## Data Layer Changes

### New: ImapConfigService (`lib/config/services/imap/imap_config_service.dart`)

Dedicated service following the same pattern as `WebshareService` and `IpqsService` — each integration owns its own `isConfigured` observable and save/clear methods.

```dart
class ImapConfigService extends GetxService {
  final isConfigured = false.obs;
  String? cachedHost; // Synchronous access for dialog pre-fill
  // ...
}
```

**Methods:**

```dart
Future<ImapConfigService> init()
```
- Gets `ConfigRepository` from `DatabaseService`
- Seeds default host (`mail.privateemail.com`) if not set
- Loads `cachedHost` from DB (always has a value after seed)
- Checks if `imap_user` and `imap_pass` have values -> sets `isConfigured`

```dart
Future<Result<void>> saveConfig({
  required String host,
  required String user,
  required String pass,
})
```
- Validates all 3 are non-empty
- Saves `imap_host`, `imap_user`, `imap_pass` to the config repository
- Updates `cachedHost = host`
- Sets `isConfigured.value = true`

```dart
Future<Result<void>> clearConfig()
```
- Deletes `imap_user` and `imap_pass`
- Re-seeds `imap_host` to the default via `setValue` (not delete+seed, to avoid race)
- Updates `cachedHost` to the default
- Sets `isConfigured.value = false`

```dart
Future<String?> getHost()
Future<String?> getUser()
Future<String?> getPass()
```
- Moved from `AppConfigService` (removes 3 methods + the IMAP key constants from there, reducing its line count)

### Modified: AppConfigService (`lib/config/services/app_config_service.dart`)

**Remove:** `_keyImapHost`, `_keyImapUser`, `_keyImapPass` constants and `getImapHost()`, `getImapUser()`, `getImapPass()` methods, and the IMAP seed logic in `_seedDefaults()`. These move to `ImapConfigService`. This reduces AppConfigService by ~20 lines (currently 301, well over the 250-line ceiling).

### Modified: AutomationService (`lib/config/services/automation/automation_service.dart`)

Update `createAccount()` to read IMAP config from `ImapConfigService` instead of `AppConfigService`:
```dart
final imapService = Get.find<ImapConfigService>();
final imapHost = await imapService.getHost();
final imapUser = await imapService.getUser();
final imapPass = await imapService.getPass();
```

### Modified: DI (`lib/core/resource/dependency_injection.dart`)

Register `ImapConfigService` in Phase 2 (`initializeAsyncServices()`), after IpqsService (step 4) and before OnboardingService (step 7):
```dart
// 4b. ImapConfigService (depends on DatabaseService)
final imapConfigService = await ImapConfigService().init();
Get.put<ImapConfigService>(imapConfigService, permanent: true);
```

### Modified: OnboardingService (`lib/config/services/onboarding_service.dart`)

**New observable:**
```dart
final isImapConfigured = false.obs;
```

**New constant:**
```dart
static const String _imapConfiguredKey = 'imap_configured';
```

**In `checkOnboardingStatus()`:** Add IMAP block following the Webshare/IPQS pattern:
```dart
try {
  final imapService = Get.find<ImapConfigService>();
  isImapConfigured.value = imapService.isConfigured.value;
  _workers.add(ever(imapService.isConfigured, (configured) {
    isImapConfigured.value = configured;
    if (configured) _saveImapConfigured();
  }));
} catch (_) {
  isImapConfigured.value = prefs.getBool(_imapConfiguredKey) ?? false;
}
```

**New helper:**
```dart
Future<void> _saveImapConfigured() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_imapConfiguredKey, true);
}
```

**Update `isOnboardingComplete`:**
```dart
bool get isOnboardingComplete =>
    isWebshareConfigured.value &&
    isIpqsConfigured.value &&
    isImapConfigured.value &&
    isInitialSyncComplete.value;
```

**Update `resetOnboarding()`:** Add:
```dart
await prefs.remove(_imapConfiguredKey);
try {
  final imapService = Get.find<ImapConfigService>();
  await imapService.clearConfig();
} catch (_) {}
isImapConfigured.value = false;
```

This automatically gates account creation since `canCreateCharacter` checks `isOnboardingComplete`.

## Widget Tree Changes

### Modified: `app_lifecycle.dart` (`lib/feature/app/views/components/`)

**`setupOnboardingWorkers()`:** Add IMAP watcher so the parent `_AppState` rebuilds when IMAP config changes (without this, the onboarding screen won't dismiss after IMAP is configured):
```dart
workers.add(ever(obs.isImapConfigured, check));
```

**`ResolvedServices`:** Add `ImapConfigService? imapConfigService` field and resolve it in `resolveServices()`:
```dart
imapConfigService: _tryFind<ImapConfigService>(),
```

### Modified: `app.dart` (`lib/feature/`)

Pass `services.imapConfigService` through to `AppNavigation`.

### Modified: `app_navigation.dart` (`lib/feature/app/views/components/`)

Add `ImapConfigService? imapConfigService` constructor parameter. Pass it to `SettingsSection`.

## UI Layer Changes

### New: `imap_config_dialog.dart` (`lib/feature/app/views/dialogs/`)

Follows the pattern of `ipqs_config_dialog.dart` (190 lines):

- `StatefulWidget` with private constructor + `static void show(BuildContext context)`
- State: `_hostController`, `_userController`, `_passController`, `_isProcessing`, `_statusMessage`, `_isError`
- Reads `ImapConfigService.isConfigured` in `initState()` to determine configured vs unconfigured view
- Pre-fills host from `ImapConfigService.cachedHost` (synchronous, no async needed in initState)
- If approaching the 200-line dialog ceiling, extract the 3 form fields into a `_buildFormFields()` helper method

**Unconfigured view:**
- Instructional text: "Configure your IMAP mailbox for Jagex email verification."
- 3 `InfoLabel` + `TextBox` fields:
  - IMAP Host (pre-filled from `cachedHost`)
  - Email / Username
  - Password (`obscureText: true`)
- Helper text: "Uses IMAP over SSL (port 993). Your catch-all mailbox for receiving Jagex verification emails."
- `ProcessingStatusBar`

**Configured view:**
- `ApiKeyConfiguredBanner` with title "Email Connected", subtitle "IMAP verification is active"
- `ProcessingStatusBar`

**Actions:**
- Close button (always)
- Unconfigured: `ConnectActionButton` with label "Save", icon `FluentIcons.save`
- Configured: `UnlinkActionButton` calling `ImapConfigService.clearConfig()`

**Save handler:**
- Validates all 3 fields are non-empty
- Calls `ImapConfigService.saveConfig(host, user, pass)`
- On success: pops dialog, shows success info bar toast
- On failure: shows error in `ProcessingStatusBar`

**Unlink handler:**
- Calls `ImapConfigService.clearConfig()`
- On success: pops dialog, shows warning info bar toast

### Modified: `settings_section.dart` (`lib/feature/app/views/sections/`)

Add `ImapConfigService? imapConfigService` constructor parameter.

Add IMAP integration tile in `_buildIntegrationsCard()`, after IPQS and before WhatsApp:

```dart
_buildImapIntegrationTile(context),
const SizedBox(height: 12),
```

New method `_buildImapIntegrationTile(BuildContext context)`:
- Icon: `FluentIcons.mail`
- Title: "Email (IMAP)"
- Description: "Email verification for account creation"
- `isConfigured`: reads from `imapConfigService.isConfigured`
- `onConfigure`: opens `ImapConfigDialog.show(context)`
- Follows the null-check + `Obx()` wrapping pattern of existing tiles

### Modified: `onboarding_section.dart` (`lib/feature/app/views/sections/`)

Add step 3 after IPQS:

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

Reads `onboardingService.isImapConfigured.value` for the `isComplete` state.

Update description text to: "Configure your integrations to start managing proxies and creating accounts."

## Files Changed

| File | Change |
|------|--------|
| `lib/config/services/imap/imap_config_service.dart` | **New file** — IMAP config service (owns `isConfigured`, `cachedHost`, save/clear/getters) |
| `lib/config/services/app_config_service.dart` | **Remove** IMAP key constants, getters, and seed logic (moved to ImapConfigService) |
| `lib/config/services/automation/automation_service.dart` | Read IMAP config from `ImapConfigService` instead of `AppConfigService` |
| `lib/core/resource/dependency_injection.dart` | Register `ImapConfigService` in Phase 2, after IpqsService |
| `lib/config/services/onboarding_service.dart` | Add `isImapConfigured` observable, SharedPreferences fallback, update `isOnboardingComplete`, update `resetOnboarding()` |
| `lib/feature/app/views/components/app_lifecycle.dart` | Add IMAP watcher to `setupOnboardingWorkers()`, add `ImapConfigService` to `ResolvedServices` |
| `lib/feature/app.dart` | Pass `imapConfigService` to `AppNavigation` |
| `lib/feature/app/views/components/app_navigation.dart` | Add `imapConfigService` parameter, pass to `SettingsSection` |
| `lib/feature/app/views/dialogs/imap_config_dialog.dart` | **New file** — IMAP configuration dialog |
| `lib/feature/app/views/sections/settings_section.dart` | Add `imapConfigService` parameter, add IMAP integration tile |
| `lib/feature/app/views/sections/onboarding_section.dart` | Add IMAP onboarding step, update description text |

## Test Changes

- Update `OnboardingService` tests: `isOnboardingComplete` now requires all 4 flags (add `isImapConfigured`)
- Add unit tests for `ImapConfigService`: `init()`, `saveConfig()`, `clearConfig()`, `isConfigured` reactivity, `cachedHost` updates
- Verify `canCreateCharacter` gating works with the new IMAP requirement
- Update any mocks that depend on `AppConfigService` IMAP getters to use `ImapConfigService`

## Out of Scope

- IMAP connection test (can be added later as a Python subcommand)
- Per-account email configuration (single catch-all mailbox only)
- IMAP port configuration (hardcoded to 993 SSL in Python poller)
