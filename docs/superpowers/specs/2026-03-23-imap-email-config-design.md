# IMAP Email Configuration

Add UI for configuring the IMAP mailbox used to receive Jagex verification emails during account creation. The backend (Python IMAP poller, env var passing, automation service integration) is already fully wired — only the configuration surface and onboarding gate are missing.

## Context

- Single catch-all mailbox (`*@domain.com` -> one IMAP inbox)
- Default host: `mail.privateemail.com` (Namecheap Private Email)
- All three fields configurable: host, user, password
- IMAP configuration is **required** before account creation can proceed

## Data Layer Changes

### AppConfigService (`lib/config/services/app_config_service.dart`)

**New observable:**
```dart
final isImapConfigured = false.obs;
```

Loaded in `loadConfig()` — true when both `imap_user` and `imap_pass` have non-null values in the DB.

**New methods:**

```dart
Future<Result<void>> saveImapConfig({
  required String host,
  required String user,
  required String pass,
})
```
- Saves all 3 keys (`imap_host`, `imap_user`, `imap_pass`) to the config repository
- Sets `isImapConfigured.value = true`

```dart
Future<Result<void>> clearImapConfig()
```
- Deletes `imap_user` and `imap_pass`
- Re-seeds `imap_host` to the default (`mail.privateemail.com`)
- Sets `isImapConfigured.value = false`

### OnboardingService (`lib/config/services/onboarding_service.dart`)

**New observable:**
```dart
final isImapConfigured = false.obs;
```

- In `checkOnboardingStatus()`: read `AppConfigService.isImapConfigured` and watch it with `ever()`, same pattern as Webshare/IPQS
- Add to `isOnboardingComplete` getter:
  ```dart
  bool get isOnboardingComplete =>
      isWebshareConfigured.value &&
      isIpqsConfigured.value &&
      isImapConfigured.value &&
      isInitialSyncComplete.value;
  ```
- Add IMAP clearing to `resetOnboarding()`

This automatically gates account creation since `canCreateCharacter` checks `isOnboardingComplete`.

## UI Layer Changes

### New: `imap_config_dialog.dart` (`lib/feature/app/views/dialogs/`)

Follows the pattern of `webshare_config_dialog.dart`:

- `StatefulWidget` with private constructor + `static void show(BuildContext context)`
- State: `_hostController`, `_userController`, `_passController`, `_isProcessing`, `_statusMessage`, `_isError`
- Reads `AppConfigService.isImapConfigured` in `initState()` to determine configured vs unconfigured view

**Unconfigured view:**
- Instructional text: "Configure your IMAP mailbox for Jagex email verification."
- 3 `InfoLabel` + `TextBox` fields:
  - IMAP Host (pre-filled with current value or default `mail.privateemail.com`)
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
- Configured: `UnlinkActionButton` calling `AppConfigService.clearImapConfig()`

**Save handler:**
- Validates all 3 fields are non-empty
- Calls `AppConfigService.saveImapConfig(host, user, pass)`
- On success: pops dialog, shows success info bar toast
- On failure: shows error in `ProcessingStatusBar`

**Unlink handler:**
- Calls `AppConfigService.clearImapConfig()`
- On success: pops dialog, shows warning info bar toast

### Modified: `settings_section.dart` (`lib/feature/app/views/sections/`)

Add IMAP integration tile in `_buildIntegrationsCard()`, after IPQS and before WhatsApp:

```dart
_buildImapIntegrationTile(context),
const SizedBox(height: 12),
```

New method `_buildImapIntegrationTile(BuildContext context)`:
- Icon: `FluentIcons.mail`
- Title: "Email (IMAP)"
- Description: "Email verification for account creation"
- `isConfigured`: reads from `AppConfigService.isImapConfigured`
- `onConfigure`: opens `ImapConfigDialog.show(context)`

`SettingsSection` constructor gains an `AppConfigService?` parameter (already has it).

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

## Files Changed

| File | Change |
|------|--------|
| `lib/config/services/app_config_service.dart` | Add `isImapConfigured` observable, `saveImapConfig()`, `clearImapConfig()`, update `loadConfig()` |
| `lib/config/services/onboarding_service.dart` | Add `isImapConfigured` observable, update `isOnboardingComplete`, update `checkOnboardingStatus()`, update `resetOnboarding()` |
| `lib/feature/app/views/dialogs/imap_config_dialog.dart` | **New file** — IMAP configuration dialog |
| `lib/feature/app/views/sections/settings_section.dart` | Add IMAP integration tile |
| `lib/feature/app/views/sections/onboarding_section.dart` | Add IMAP onboarding step |

## Out of Scope

- IMAP connection test (can be added later as a Python subcommand)
- Per-account email configuration (single catch-all mailbox only)
- IMAP port configuration (hardcoded to 993 SSL in Python poller)
