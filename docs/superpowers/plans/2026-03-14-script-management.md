# Script Management & Launch — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to select DreamBot scripts at launch time with configurable parameters, and automatically recover from bot crashes and bans via a lightweight process watchdog.

**Architecture:** C++ platform channel rebuilt (WMI COM for process list, CreateProcess for launch returning PID). New WatchdogService owns the single poll timer, death classification (failed vs banned escalation), relaunch with exponential backoff, and startup recapture. StatusController becomes a thin wrapper that delegates to watchdog observables.

**Tech Stack:** Flutter, GetX, Fluent UI, Win32 WMI COM API, CreateProcess, DreamBot QuickStart CLI

**Spec:** `docs/superpowers/specs/2026-03-14-script-management-design.md`

---

## Chunk 1: Foundation — Models, Enums, Repository Changes

### Task 1: Add new NotificationType enum values

**Files:**
- Modify: `lib/domain/entities/notification.dart:3-7`

- [ ] **Step 1: Add four new enum values**

```dart
enum NotificationType {
  rotationCompleted,
  rotationFailed,
  quotaExhausted,
  banDetected,
  maxRetriesReached,
  clientRelaunched,
  clientFailed,
}
```

These are stored as `e.name` strings in the DB (see `notification_repository_impl.dart:33`), so no migration needed.

- [ ] **Step 2: Verify no breakage**

Run: `cd /mnt/c/Projects/command_center && flutter analyze`
Expected: No new errors (existing enum references use specific values, not exhaustive switches)

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/notification.dart
git commit -m "feat(notifications): add watchdog notification types"
```

---

### Task 2: Add `updateCharacterBanned()` to AccountRepository

**Files:**
- Modify: `lib/domain/repositories/account_repository.dart:28` (add method to interface)
- Modify: `lib/data/repositories/account_repository_impl.dart` (add implementation)

- [ ] **Step 1: Add method to the abstract interface**

In `lib/domain/repositories/account_repository.dart`, add after line 28 (before closing `}`):

```dart
  /// Update a character's banned flag by character ID (not account ID)
  Future<void> updateCharacterBanned(int characterId, bool banned);
```

- [ ] **Step 2: Add implementation**

In `lib/data/repositories/account_repository_impl.dart`, add after `getAccountsByProxySlot()` method (after line 149):

```dart
  @override
  Future<void> updateCharacterBanned(int characterId, bool banned) async {
    await (_db.update(_db.charactersTable)
          ..where((tbl) => tbl.id.equals(characterId)))
        .write(CharactersTableCompanion(
      banned: Value(banned),
      lastUpdated: Value(DateTime.now()),
    ));
  }
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/domain/repositories/account_repository.dart lib/data/repositories/account_repository_impl.dart
git commit -m "feat(repository): add updateCharacterBanned method"
```

---

### Task 3: Add `proxySlotId` to JagexAccount view model

**Files:**
- Modify: `lib/feature/Status/data/jagex_account_model.dart`

- [ ] **Step 1: Add field, constructor param, fromJson, and props**

```dart
class JagexAccount extends Equatable {
  final int? id;
  final String accountName;
  final String birthday;
  final String email;
  final String password;
  final String proxyAddress;
  final int? proxySlotId;
  final List<Character> characters;

  const JagexAccount({
    this.id,
    this.accountName = 'Default Name',
    this.birthday = '01-01-2000',
    this.email = 'default@example.com',
    this.password = 'defaultPassword123',
    this.proxyAddress = '0.0.0.0',
    this.proxySlotId,
    this.characters = const <Character>[],
  });

  factory JagexAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return JagexAccount(
        accountName: 'Default Name',
        birthday: '01-01-2000',
        email: 'default@example.com',
        password: 'defaultPassword123',
        proxyAddress: '0.0.0.0',
        characters: const [],
      );
    }
    return JagexAccount(
      id: json['id'] as int?,
      accountName: json['accountName'] ?? "Default Name",
      birthday: json['birthday'] ?? "01-01-2000",
      email: json['email'] ?? "default@example.com",
      password: json['password'] ?? "defaultPassword123",
      proxyAddress: json['proxyAddress'] ?? "0.0.0.0",
      proxySlotId: json['proxySlotId'] as int?,
      characters: (json['characters'] as List? ?? [])
          .map((characterJson) => Character.fromJson(characterJson))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [id, accountName, birthday, email, password, proxyAddress, proxySlotId, characters];
}
```

- [ ] **Step 2: Add `id` field to Character view model**

In `lib/feature/Status/data/character_model.dart`, add `int? id` field:

```dart
// ignore: must_be_immutable
class Character extends Equatable {
  int? id;
  bool banned = false;
  String name = 'Default Character';
  Skills actualSkills = Skills.empty();
  Skills targetSkills = Skills.empty();

  Character({
    this.id,
    required this.banned,
    required this.name,
    required this.actualSkills,
    required this.targetSkills,
  });

  factory Character.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Character(
        banned: false,
        name: 'Default Character',
        actualSkills: Skills.empty(),
        targetSkills: Skills.empty(),
      );
    }
    return Character(
      id: json['id'] as int?,
      banned: json['banned'] ?? false,
      name: json['name'] ?? 'Jhon Doe',
      actualSkills:
          Skills.fromJson(json['actualSkills'] as Map<String, dynamic>? ?? {}),
      targetSkills:
          Skills.fromJson(json['targetSkills'] as Map<String, dynamic>? ?? {}),
    );
  }

  @override
  List<Object?> get props => [id, banned, name, actualSkills, targetSkills];
}
```

- [ ] **Step 3: Update StatusController mapping to populate new fields**

In `lib/feature/Status/controller/status_controller.dart`, update the mapping in `getAccountsData()` (lines 86-104):

```dart
        ..addAll([
          for (var account in accounts)
            JagexAccount(
              id: account.id,
              accountName: account.accountName,
              birthday: account.birthday,
              email: account.email,
              password: account.password,
              proxySlotId: account.proxySlotId,
              proxyAddress:
                  _resolveProxyAddress(account.proxySlotId, proxyController),
              characters: account.characters
                  .map((c) => Character(
                        id: c.id,
                        banned: c.banned,
                        name: c.name,
                        actualSkills: _mapSkills(c.actualSkills),
                        targetSkills: _mapSkills(c.targetSkills),
                      ))
                  .toList(),
            )
        ]);
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/feature/Status/data/jagex_account_model.dart lib/feature/Status/data/character_model.dart lib/feature/Status/controller/status_controller.dart
git commit -m "feat(models): add proxySlotId to JagexAccount and id to Character"
```

---

### Task 4: Add `rotateSlot()` to ProxyAutoRotationService

**Files:**
- Modify: `lib/config/services/proxy/proxy_auto_rotation_service.dart`

- [ ] **Step 1: Add `rotateSlot` method**

Add after the `_processResults` method (after line 194), before the closing `}`:

```dart
  /// Rotate the IP for a specific slot (triggered by watchdog on ban detection).
  /// Looks up the active IP via repository (not controller — services don't depend on controllers).
  Future<bool> rotateSlot(int slotId) async {
    final currentIp = await _proxyRepository.getActiveIpForSlot(slotId);
    if (currentIp == null) {
      logger.w('rotateSlot: no active IP for slot $slotId');
      return false;
    }

    final result = await _replacementService.replaceProxyIp(
      currentIp,
      keepSameCountry: true,
    );

    switch (result) {
      case Success():
        try {
          await _syncService.syncWithWebshare();
        } catch (e) {
          logger.w('rotateSlot: sync after replacement failed: $e');
        }
        logger.i('rotateSlot: replaced IP for slot $slotId');
        return true;
      case Failure(:final message):
        logger.w('rotateSlot: failed for slot $slotId: $message');
        return false;
    }
  }
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/proxy/proxy_auto_rotation_service.dart
git commit -m "feat(proxy): add rotateSlot method for watchdog ban rotation"
```

---

### Task 5: Add script registry to AppConfigService

**Files:**
- Modify: `lib/config/services/app_config_service.dart`

- [ ] **Step 1: Add config key, observable, load/save methods**

Add the config key constant after line 19:

```dart
  static const String _keyScriptRegistry = 'script_registry';
```

Add the observable after line 29:

```dart
  final scriptRegistry = <String>['Tutorial Journey'].obs;
```

Add to `loadConfig()` — after the `autoRotationThreshold` load block (after line 72), inside the try:

```dart
      final registryJson =
          await _configRepository!.getValue(_keyScriptRegistry);
      if (registryJson != null) {
        try {
          final decoded = jsonDecode(registryJson) as List;
          scriptRegistry.value = decoded.cast<String>();
        } catch (e) {
          logger.e('Error parsing script registry: $e');
        }
      }
```

Add the import at top of file:

```dart
import 'dart:convert';
```

Add save methods after `saveAutoRotationThreshold()` (after line 180):

```dart
  /// Add a script name to the registry
  Future<Result<void>> addScript(String scriptName) async {
    if (_configRepository == null) {
      return Result.failure('Config repository not initialized');
    }
    if (scriptRegistry.contains(scriptName)) {
      return Result.failure('Script already exists');
    }
    scriptRegistry.add(scriptName);
    await _configRepository!
        .setValue(_keyScriptRegistry, jsonEncode(scriptRegistry));
    return Result.success(null);
  }

  /// Remove a script name from the registry
  Future<Result<void>> removeScript(String scriptName) async {
    if (_configRepository == null) {
      return Result.failure('Config repository not initialized');
    }
    scriptRegistry.remove(scriptName);
    await _configRepository!
        .setValue(_keyScriptRegistry, jsonEncode(scriptRegistry));
    return Result.success(null);
  }
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/app_config_service.dart
git commit -m "feat(config): add script registry persistence"
```

---

## Chunk 2: C++ Platform Channel — WMI COM + CreateProcess

### Task 6: Replace `ListJavaProcesses` with WMI COM API

**Files:**
- Modify: `windows/runner/main.cpp:78-100`

- [ ] **Step 1: Add WMI COM headers**

Add after the existing includes (after line 17):

```cpp
#include <comdef.h>
#include <Wbemidl.h>
#pragma comment(lib, "wbemuuid.lib")
```

- [ ] **Step 2: Replace `ListJavaProcesses` function**

Replace the existing function (lines 78-100) with:

```cpp
void ListJavaProcesses(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> &result)
{
    IWbemLocator *pLocator = nullptr;
    IWbemServices *pServices = nullptr;
    IEnumWbemClassObject *pEnumerator = nullptr;

    HRESULT hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IWbemLocator, (LPVOID *)&pLocator);
    if (FAILED(hr))
    {
        result->Error("WMI Error", "Failed to create WbemLocator");
        return;
    }

    hr = pLocator->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), nullptr, nullptr, nullptr,
                                  0, nullptr, nullptr, &pServices);
    if (FAILED(hr))
    {
        pLocator->Release();
        result->Error("WMI Error", "Failed to connect to WMI");
        return;
    }

    hr = CoSetProxyBlanket(pServices, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, nullptr,
                           RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
                           nullptr, EOAC_NONE);
    if (FAILED(hr))
    {
        pServices->Release();
        pLocator->Release();
        result->Error("WMI Error", "Failed to set proxy blanket");
        return;
    }

    hr = pServices->ExecQuery(
        bstr_t("WQL"),
        bstr_t("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'java.exe' OR Name = 'javaw.exe'"),
        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr, &pEnumerator);
    if (FAILED(hr))
    {
        pServices->Release();
        pLocator->Release();
        result->Error("WMI Error", "WMI query failed");
        return;
    }

    flutter::EncodableList processList;
    IWbemClassObject *pObj = nullptr;
    ULONG numReturned = 0;

    while (pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &numReturned) == S_OK)
    {
        VARIANT vtPid, vtCmd;
        VariantInit(&vtPid);
        VariantInit(&vtCmd);

        int pid = 0;
        std::string commandLine;

        if (SUCCEEDED(pObj->Get(L"ProcessId", 0, &vtPid, nullptr, nullptr)))
        {
            pid = vtPid.intVal;
        }
        if (SUCCEEDED(pObj->Get(L"CommandLine", 0, &vtCmd, nullptr, nullptr)) && vtCmd.vt == VT_BSTR)
        {
            _bstr_t bstrCmd(vtCmd.bstrVal);
            commandLine = std::string((const char *)bstrCmd);
        }

        VariantClear(&vtPid);
        VariantClear(&vtCmd);
        pObj->Release();

        if (!commandLine.empty())
        {
            flutter::EncodableMap entry;
            entry[flutter::EncodableValue("pid")] = flutter::EncodableValue(pid);
            entry[flutter::EncodableValue("commandLine")] = flutter::EncodableValue(commandLine);
            processList.push_back(flutter::EncodableValue(entry));
        }
    }

    pEnumerator->Release();
    pServices->Release();
    pLocator->Release();

    result->Success(flutter::EncodableValue(processList));
}
```

- [ ] **Step 3: Verify old helpers**

The `base64_encode` call at line 90 of the old `ListJavaProcesses` is gone (the entire function is replaced). The `base64_encode` utility itself lives in `utils.h`/`utils.cpp` — leave it in place since other code may use it. No explicit removal needed.

- [ ] **Step 4: Update `HandleMethodCall` for `listJavaProcesses`**

The existing call at line 114 (`ListJavaProcesses(result)`) stays the same — the function signature is unchanged.

- [ ] **Step 5: Build to verify**

Run: `flutter build windows` (or just the C++ compilation step)
Expected: Compiles without errors

- [ ] **Step 6: Commit**

```bash
git add windows/runner/main.cpp
git commit -m "feat(platform): replace wmic with WMI COM API for process listing"
```

---

### Task 7: Replace `RunGameClient` with CreateProcess, return PID

**Files:**
- Modify: `windows/runner/main.cpp`

- [ ] **Step 1: Replace input validation**

Replace `isValidInput` function (line 54-57) with:

```cpp
bool containsShellMetachars(const std::string &input)
{
    return input.find_first_of("&|;<>`$") != std::string::npos;
}
```

- [ ] **Step 2: Replace `RunGameClient` function**

Replace the existing function (lines 59-76) with:

```cpp
int RunGameClient(const flutter::EncodableMap &args)
{
    auto getString = [&](const char *key) -> std::string {
        auto it = args.find(flutter::EncodableValue(key));
        if (it != args.end() && std::holds_alternative<std::string>(it->second))
            return std::get<std::string>(it->second);
        return "";
    };
    auto getBool = [&](const char *key, bool defaultVal = false) -> bool {
        auto it = args.find(flutter::EncodableValue(key));
        if (it != args.end() && std::holds_alternative<bool>(it->second))
            return std::get<bool>(it->second);
        return defaultVal;
    };

    std::string characterName = getString("characterName");
    std::string proxyAddress = getString("proxyAddress");
    std::string scriptName = getString("scriptName");
    std::string world = getString("world");
    std::string render = getString("render");
    std::string scriptParams = getString("scriptParams");
    std::string advancedFlags = getString("advancedFlags");
    bool covert = getBool("covert");
    bool destroyOnBan = getBool("destroyOnBan", true);
    bool destroy = getBool("destroy", true);
    bool minimized = getBool("minimized", true);

    // Validate structured fields against shell metacharacters
    if (containsShellMetachars(characterName) || containsShellMetachars(proxyAddress) ||
        containsShellMetachars(scriptName) || containsShellMetachars(world) ||
        containsShellMetachars(render) || containsShellMetachars(scriptParams))
    {
        throw std::invalid_argument("Unsafe characters in input.");
    }

    std::string userName = GetEnvironmentVariable("USERNAME");
    std::string command = "java -jar C:\\Users\\" + userName + "\\DreamBot\\Launcher.jar";
    command += " -script \"" + scriptName + "\" -account \"" + characterName + "\"";

    if (!proxyAddress.empty() && proxyAddress != "none")
    {
        command += " -proxy \"" + proxyAddress + "\"";
    }
    if (!world.empty() && world != "auto")
    {
        command += " -world " + world;
    }
    if (covert)
    {
        command += " -covert";
    }
    if (!render.empty() && render != "NONE")
    {
        command += " -render " + render;
    }
    if (destroy)
    {
        command += " -destroy";
    }
    if (destroyOnBan)
    {
        command += " -destroy-on-ban";
    }
    if (minimized)
    {
        command += " -minimized";
    }
    if (!advancedFlags.empty())
    {
        command += " " + advancedFlags;
    }
    // -params must be last per DreamBot requirements
    if (!scriptParams.empty())
    {
        command += " -params " + scriptParams;
    }

    // Use CreateProcess instead of system() — no CMD shell, returns PID directly
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    // CreateProcess needs a mutable copy of the command string
    std::vector<char> cmdBuf(command.begin(), command.end());
    cmdBuf.push_back('\0');

    if (!CreateProcessA(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE,
                        CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi))
    {
        throw std::runtime_error("CreateProcess failed with error " + std::to_string(GetLastError()));
    }

    int pid = static_cast<int>(pi.dwProcessId);

    // Close handles — we don't need to wait on the process
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return pid;
}
```

- [ ] **Step 3: Update `HandleMethodCall` for `runGameClient`**

Replace the `runGameClient` handler (lines 146-166) with:

```cpp
    else if (method_call.method_name().compare("runGameClient") == 0)
    {
        const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments)
        {
            result->Error("Invalid arguments", "Expected arguments map.");
            return;
        }
        try
        {
            int pid = RunGameClient(*arguments);
            result->Success(flutter::EncodableValue(pid));
        }
        catch (const std::invalid_argument &e)
        {
            result->Error("Invalid Input", e.what());
        }
        catch (const std::runtime_error &e)
        {
            result->Error("Launch Error", e.what());
        }
    }
```

- [ ] **Step 4: Verify `ExecuteCommandAsync` is still needed**

`ExecuteCommandAsync` is still used by `KillProcessAndChilds` (line 105) and `runCmdCommand` (line 143). Do **not** remove it. Only `RunGameClient` and `ListJavaProcesses` no longer use it.

- [ ] **Step 5: Build to verify**

Run: `flutter build windows`
Expected: Compiles without errors

- [ ] **Step 6: Commit**

```bash
git add windows/runner/main.cpp
git commit -m "feat(platform): use CreateProcess for game launch, return PID"
```

---

### Task 8: Update Dart-side NativeCommandsService

**Files:**
- Modify: `lib/config/services/native_commands_service.dart`
- Modify: `lib/feature/Status/data/process_model.dart`

- [ ] **Step 1: Update `ProcessClient.parseProcessData` → replace with map-based factory**

Replace the entire `process_model.dart` content:

```dart
import 'package:equatable/equatable.dart';

class ProcessClient extends Equatable {
  final String commandLine;
  final int processId;

  const ProcessClient({required this.commandLine, required this.processId});

  /// Parse from WMI COM API structured response (list of maps)
  static List<ProcessClient> fromPlatformList(List<dynamic> data) {
    return data
        .whereType<Map>()
        .map((entry) => ProcessClient(
              commandLine: entry['commandLine'] as String? ?? '',
              processId: entry['pid'] as int? ?? 0,
            ))
        .where((p) => p.commandLine.isNotEmpty)
        .toList();
  }

  @override
  List<Object?> get props => [commandLine, processId];
}
```

- [ ] **Step 2: Rewrite NativeCommandsService**

Replace the entire `native_commands_service.dart` content. Remove `GetxController` base class and dead `output.obs`:

```dart
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:flutter/services.dart';

class NativeCommandsService {
  static const _platform = MethodChannel('com.onemanco/commands');

  /// List running Java processes via WMI COM API.
  /// Returns structured data directly — no base64 decoding.
  Future<List<ProcessClient>> listJavaProcesses() async {
    try {
      final List<dynamic> result =
          await _platform.invokeMethod('listJavaProcesses');
      return ProcessClient.fromPlatformList(result);
    } on PlatformException catch (e) {
      logger.e('Failed to get Java processes: ${e.message}');
      return [];
    }
  }

  /// Kill a process and its children via taskkill.
  Future<void> killProcess(int pid) async {
    try {
      await _platform.invokeMethod('killProcessAndChilds', {'pid': pid});
    } on PlatformException catch (e) {
      logger.e('Failed to kill process $pid: ${e.message}');
    }
  }

  /// Launch a DreamBot game client via CreateProcess.
  /// Returns the child process PID.
  Future<int> runGameClient({
    required String characterName,
    required String? proxyAddress,
    required String scriptName,
    String world = 'auto',
    bool covert = true,
    String render = 'NONE',
    String scriptParams = '',
    String advancedFlags = '',
  }) async {
    try {
      final int pid = await _platform.invokeMethod('runGameClient', {
        'characterName': characterName,
        'proxyAddress': proxyAddress ?? 'none',
        'scriptName': scriptName,
        'world': world,
        'covert': covert,
        'render': render,
        'scriptParams': scriptParams,
        'advancedFlags': advancedFlags,
        'destroyOnBan': true,
        'destroy': true,
        'minimized': true,
      });
      logger.i('Game client started for $characterName (PID: $pid)');
      return pid;
    } on PlatformException catch (e) {
      logger.e('Failed to run game client: ${e.message}');
      rethrow;
    }
  }

  /// Run a generic CMD command.
  Future<String> runCmdCommand(String command) async {
    try {
      final String result =
          await _platform.invokeMethod('runCmdCommand', {'command': command});
      return result;
    } on PlatformException catch (e) {
      logger.e('Failed to run CMD command: ${e.message}');
      rethrow;
    }
  }
}
```

- [ ] **Step 3: Update DI registration**

In `lib/core/resource/dependency_injection.dart`, line 34 — `NativeCommandsService` no longer extends `GetxController`, but `Get.put` works with any class:

```dart
    Get.put<NativeCommandsService>(NativeCommandsService(), permanent: true);
```

No change needed — this already works.

- [ ] **Step 4: Fix StatusController references**

In `lib/feature/Status/controller/status_controller.dart`, the `stopGameClient` method accesses `output.value` nowhere, and `killProcess` has no return. Check for any references to `_nativeCommandsService.output` — there are none. The field init at line 26 (`Get.find()`) still works.

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/config/services/native_commands_service.dart lib/feature/Status/data/process_model.dart
git commit -m "feat(native): structured WMI response, runGameClient returns PID"
```

---

## Chunk 3: Watchdog Service — Core Engine

### Task 9: Create LaunchConfig model

**Files:**
- Create: `lib/config/services/watchdog/launch_config.dart`

- [ ] **Step 1: Create the model**

```dart
/// Presentation model for DreamBot launch parameters.
/// Session-scoped — not persisted to DB (future work: script profiles).
class LaunchConfig {
  final String scriptName;
  final String world;
  final bool covert;
  final String render;
  final String scriptParams;
  final String advancedFlags;

  const LaunchConfig({
    required this.scriptName,
    this.world = 'auto',
    this.covert = true,
    this.render = 'NONE',
    this.scriptParams = '',
    this.advancedFlags = '',
  });
}
```

- [ ] **Step 2: Commit**

```bash
mkdir -p lib/config/services/watchdog
git add lib/config/services/watchdog/launch_config.dart
git commit -m "feat(watchdog): add LaunchConfig model"
```

---

### Task 10: Create TrackedClient model

**Files:**
- Create: `lib/config/services/watchdog/tracked_client.dart`

- [ ] **Step 1: Create the model**

```dart
import 'package:command_center/config/services/watchdog/launch_config.dart';

/// Mutable in-memory model tracking a running bot client.
/// Not a domain entity — lives in the watchdog service directory.
enum ClientStatus { running, restarting, stopped, failed, banned, awaitingAccount }

class TrackedClient {
  final String characterName;
  final int characterId;
  final int accountId;
  final int? proxySlotId;
  String? proxyAddress;
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
    this.proxyAddress,
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

- [ ] **Step 2: Commit**

```bash
git add lib/config/services/watchdog/tracked_client.dart
git commit -m "feat(watchdog): add TrackedClient model with death classification state"
```

---

### Task 11: Create WatchdogService

**Files:**
- Create: `lib/config/services/watchdog/watchdog_service.dart`

This is the largest file (~250 lines). If it exceeds the ceiling, extract death classification into a private helper.

- [ ] **Step 1: Create the service skeleton with dependencies and observable state**

```dart
import 'dart:async';

import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:get/get.dart';

class WatchdogService extends GetxService {
  final NativeCommandsService _nativeCommandsService;
  final NotificationService _notificationService;
  final ProxyAutoRotationService _autoRotationService;
  final AccountRepository _accountRepository;
  final ProxyRepository _proxyRepository;

  static const int maxRetries = 5;
  static const Duration _quickDeathThreshold = Duration(seconds: 30);
  static const Duration _stabilityThreshold = Duration(minutes: 5);
  static const int _maxDiscoveryMisses = 3;
  static const int _banEscalationThreshold = 3;
  static const Duration _maxCooldown = Duration(minutes: 5);

  Timer? _pollTimer;

  final trackedClients = <String, TrackedClient>{}.obs;

  WatchdogService({
    required NativeCommandsService nativeCommandsService,
    required NotificationService notificationService,
    required ProxyAutoRotationService autoRotationService,
    required AccountRepository accountRepository,
    required ProxyRepository proxyRepository,
  })  : _nativeCommandsService = nativeCommandsService,
        _notificationService = notificationService,
        _autoRotationService = autoRotationService,
        _accountRepository = accountRepository,
        _proxyRepository = proxyRepository;

  @override
  void onInit() {
    super.onInit();
    _recaptureRunningClients();
    _startPolling();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  // ===== Computed counts for UI =====

  int get runningCount => trackedClients.values
      .where((c) => c.status == ClientStatus.running)
      .length;
  int get restartingCount => trackedClients.values
      .where((c) =>
          c.status == ClientStatus.restarting ||
          c.status == ClientStatus.failed)
      .length;
  int get stoppedCount => trackedClients.values
      .where((c) => c.status == ClientStatus.stopped)
      .length;
  int get bannedCount => trackedClients.values
      .where((c) =>
          c.status == ClientStatus.banned ||
          c.status == ClientStatus.awaitingAccount)
      .length;

  // ===== Public API =====

  /// Start tracking a client (called after launch dialog).
  void track(TrackedClient client) {
    trackedClients[client.characterName] = client;
    trackedClients.refresh();
    logger.i('Tracking ${client.characterName} (PID: ${client.pid})');
  }

  /// Stop a client: kill process, remove from tracking.
  Future<void> stop(String characterName) async {
    final client = trackedClients[characterName];
    if (client != null && client.pid != null) {
      await _nativeCommandsService.killProcess(client.pid!);
    }
    trackedClients.remove(characterName);
    trackedClients.refresh();
    logger.i('Stopped $characterName');
  }

  /// Stop all tracked clients.
  Future<void> stopAll() async {
    final names = trackedClients.keys.toList();
    for (final name in names) {
      await stop(name);
    }
  }

  // ===== Polling =====

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = trackedClients.isEmpty
        ? const Duration(seconds: 30)
        : const Duration(seconds: 10);
    _pollTimer = Timer.periodic(interval, (_) => _tick());
  }

  void _adjustPollingRate() {
    final shouldBeActive = trackedClients.isNotEmpty;
    final currentInterval = trackedClients.isEmpty ? 30 : 10;
    final desiredInterval = shouldBeActive ? 10 : 30;
    if (currentInterval != desiredInterval) {
      _startPolling();
    }
  }

  Future<void> _tick() async {
    if (trackedClients.isEmpty) return;

    final liveProcesses = await _nativeCommandsService.listJavaProcesses();
    final livePids = <int>{};
    for (final p in liveProcesses) {
      livePids.add(p.processId);
    }

    bool changed = false;

    for (final client in trackedClients.values.toList()) {
      // Skip terminal states
      if (client.status == ClientStatus.stopped ||
          client.status == ClientStatus.awaitingAccount) continue;

      // Discovery: client launched but PID not yet confirmed
      if (client.pid == null) {
        final match = _discoverPid(client, liveProcesses);
        if (match != null) {
          client.pid = match;
          client.resetDiscoveryMisses();
          changed = true;
        } else {
          client.incrementDiscoveryMisses();
          if (client.discoveryMisses >= _maxDiscoveryMisses) {
            client.status = ClientStatus.failed;
            client.lastDeathAt = DateTime.now();
            logger.e('Discovery timeout for ${client.characterName}');
            changed = true;
          }
        }
        continue;
      }

      // Check if process is still alive
      if (livePids.contains(client.pid)) {
        // Stability reset: alive > 5 min → reset retry counters
        if (client.launchedAt != null &&
            DateTime.now().difference(client.launchedAt!) > _stabilityThreshold) {
          if (client.retryCount > 0 || client.consecutiveQuickDeaths > 0) {
            client.retryCount = 0;
            client.consecutiveQuickDeaths = 0;
            changed = true;
          }
        }
        continue;
      }

      // Process died — classify death
      changed = true;
      _classifyDeath(client);
    }

    // Handle restarts and bans
    for (final client in trackedClients.values.toList()) {
      if (client.status == ClientStatus.restarting ||
          client.status == ClientStatus.failed) {
        changed |= await _handleRestart(client);
      } else if (client.status == ClientStatus.banned) {
        await _handleBan(client);
        changed = true;
      }
    }

    if (changed) {
      trackedClients.refresh();
      _adjustPollingRate();
    }
  }

  // ===== Death Classification =====

  void _classifyDeath(TrackedClient client) {
    final now = DateTime.now();
    final alive = client.launchedAt != null
        ? now.difference(client.launchedAt!)
        : Duration.zero;

    client.pid = null;
    client.lastDeathAt = now;

    if (alive < _quickDeathThreshold) {
      client.consecutiveQuickDeaths++;
      if (client.consecutiveQuickDeaths >= _banEscalationThreshold) {
        client.status = ClientStatus.banned;
        logger.e('Ban detected for ${client.characterName} '
            '(${client.consecutiveQuickDeaths} consecutive quick deaths)');
      } else {
        client.status = ClientStatus.failed;
        client.retryCount++;
        logger.w('Quick death #${client.consecutiveQuickDeaths} for ${client.characterName}');
        _notificationService.createNotification(
          type: NotificationType.clientFailed,
          severity: NotificationSeverity.warning,
          title: 'Client Failed',
          message: '${client.characterName} died quickly '
              '(attempt ${client.retryCount}/$maxRetries)',
        );
      }
    } else {
      // Normal death — restarting
      client.consecutiveQuickDeaths = 0;
      client.status = ClientStatus.restarting;
      client.retryCount++;
      logger.i('Normal death for ${client.characterName}, scheduling restart');
    }
  }

  // ===== Restart Handling =====

  Future<bool> _handleRestart(TrackedClient client) async {
    if (client.retryCount >= maxRetries) {
      client.status = ClientStatus.stopped;
      logger.e('Max retries reached for ${client.characterName}');
      await _notificationService.createNotification(
        type: NotificationType.maxRetriesReached,
        severity: NotificationSeverity.error,
        title: 'Max Retries Reached',
        message: '${client.characterName} stopped after $maxRetries attempts.',
      );
      return true;
    }

    // Check cooldown: 30s × 2^retryCount, capped at 5 min
    final cooldown = Duration(
      seconds: (30 * (1 << (client.retryCount - 1)))
          .clamp(30, _maxCooldown.inSeconds),
    );
    if (client.lastDeathAt != null &&
        DateTime.now().difference(client.lastDeathAt!) < cooldown) {
      return false; // Still cooling down
    }

    // Relaunch
    try {
      final pid = await _nativeCommandsService.runGameClient(
        characterName: client.characterName,
        proxyAddress: client.proxyAddress,
        scriptName: client.launchConfig.scriptName,
        world: client.launchConfig.world,
        covert: client.launchConfig.covert,
        render: client.launchConfig.render,
        scriptParams: client.launchConfig.scriptParams,
        advancedFlags: client.launchConfig.advancedFlags,
      );
      client.pid = pid;
      client.status = ClientStatus.running;
      client.launchedAt = DateTime.now();
      logger.i('Relaunched ${client.characterName} (PID: $pid, retry ${client.retryCount})');
      await _notificationService.createNotification(
        type: NotificationType.clientRelaunched,
        severity: NotificationSeverity.info,
        title: 'Client Relaunched',
        message: '${client.characterName} restarted (attempt ${client.retryCount}/$maxRetries)',
      );
      return true;
    } catch (e) {
      logger.e('Failed to relaunch ${client.characterName}: $e');
      return false;
    }
  }

  // ===== Ban Handling =====

  Future<void> _handleBan(TrackedClient client) async {
    // Mark character banned in DB
    await _accountRepository.updateCharacterBanned(client.characterId, true);

    await _notificationService.createNotification(
      type: NotificationType.banDetected,
      severity: NotificationSeverity.error,
      title: 'Ban Detected',
      message: '${client.characterName} banned after '
          '${client.consecutiveQuickDeaths} consecutive quick deaths.',
    );

    // Rotate proxy if available
    if (client.proxySlotId != null) {
      final rotated = await _autoRotationService.rotateSlot(client.proxySlotId!);
      if (rotated) {
        // Re-resolve proxy address for future relaunches
        final newIp =
            await _proxyRepository.getActiveIpForSlot(client.proxySlotId!);
        if (newIp != null) {
          client.proxyAddress = newIp.ipAddress;
        }
      }
    }

    client.status = ClientStatus.awaitingAccount;
  }

  // ===== PID Discovery =====

  int? _discoverPid(TrackedClient client, List<ProcessClient> liveProcesses) {
    for (final process in liveProcesses) {
      if (process.commandLine.contains('-account "${client.characterName}"') ||
          process.commandLine.contains("-account '${client.characterName}'") ||
          process.commandLine.contains('-account ${client.characterName}')) {
        return process.processId;
      }
    }
    return null;
  }

  // ===== Startup Recapture =====

  Future<void> _recaptureRunningClients() async {
    try {
      final processes = await _nativeCommandsService.listJavaProcesses();
      final accounts = await _accountRepository.getAllAccounts();

      // Build character lookup: name → (characterId, accountId, proxySlotId)
      final characterLookup = <String, ({int characterId, int accountId, int? proxySlotId})>{};
      for (final account in accounts) {
        for (final character in account.characters) {
          if (character.id != null) {
            characterLookup[character.name] = (
              characterId: character.id!,
              accountId: account.id!,
              proxySlotId: account.proxySlotId,
            );
          }
        }
      }

      int recaptured = 0;
      final accountRegex = RegExp(r'-account "([^"]+)"');
      final scriptRegex = RegExp(r'-script "([^"]+)"');

      for (final process in processes) {
        final accountMatch = accountRegex.firstMatch(process.commandLine);
        if (accountMatch == null) continue;

        final charName = accountMatch.group(1)!;
        final info = characterLookup[charName];
        if (info == null) continue;

        // Extract script name if available
        final scriptMatch = scriptRegex.firstMatch(process.commandLine);
        final scriptName = scriptMatch?.group(1) ?? 'Unknown';

        trackedClients[charName] = TrackedClient(
          characterName: charName,
          characterId: info.characterId,
          accountId: info.accountId,
          proxySlotId: info.proxySlotId,
          launchConfig: LaunchConfig(scriptName: scriptName),
          pid: process.processId,
          status: ClientStatus.running,
          launchedAt: DateTime.now(),
        );
        recaptured++;
      }

      if (recaptured > 0) {
        trackedClients.refresh();
        logger.i('Recaptured $recaptured running bot clients');
      }
    } catch (e) {
      logger.e('Failed to recapture running clients: $e');
    }
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/watchdog/
git commit -m "feat(watchdog): add WatchdogService with death classification and recapture"
```

---

### Task 12: Register WatchdogService in DI

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart`

- [ ] **Step 1: Add import**

Add after existing imports:

```dart
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
```

- [ ] **Step 2: Add eager registration at end of `dependencies()`**

Add after the debug-only block (after line 87), before the closing `}` of `dependencies()`:

```dart
    // Watchdog — eager init for startup recapture scan
    Get.put<WatchdogService>(WatchdogService(
      nativeCommandsService: Get.find<NativeCommandsService>(),
      notificationService: Get.find<NotificationService>(),
      autoRotationService: Get.find<ProxyAutoRotationService>(),
      accountRepository: Get.find<DatabaseService>().accountRepository,
      proxyRepository: Get.find<DatabaseService>().proxyRepository,
    ));
```

**Important:** This `Get.put` must come after `dependencies()` is called, which is after `initializeAsyncServices()` completes. Since `dependencies()` is called by `GetMaterialApp` during build (after async init in `main()`), all lazy services resolve correctly because `NotificationService`, `DatabaseService`, etc. are already `Get.put` in `initializeAsyncServices()`.

However, `ProxyAutoRotationService` is registered with `Get.lazyPut` in the same `dependencies()` method — it needs to be registered *before* the `Get.put<WatchdogService>`. Since `lazyPut` registers the factory immediately (it just delays instantiation), and `Get.find` inside `Get.put` forces instantiation, the ordering within `dependencies()` is what matters. The `ProxyAutoRotationService` lazyPut is at line 68-79, which runs before our new code at end of method — correct.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/core/resource/dependency_injection.dart
git commit -m "feat(di): register WatchdogService with eager init for recapture"
```

---

## Chunk 4: UI — Launch Dialog, Status Badge, Summary Bar

### Task 13: Create Launch Dialog

**Files:**
- Create: `lib/feature/Status/views/dialogs/launch_dialog.dart`
- Create: `lib/feature/Status/views/components/script_selector.dart`

The dialog exceeds the 200-line ceiling if script registry management is inline. Extract the script ComboBox + "Add" button into a `ScriptSelector` component (~60 lines), keeping the dialog at ~200 lines.

- [ ] **Step 1: Create `ScriptSelector` component**

```dart
import 'package:command_center/config/services/app_config_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ScriptSelector extends StatelessWidget {
  final String selectedScript;
  final ValueChanged<String> onChanged;

  const ScriptSelector({
    super.key,
    required this.selectedScript,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final configService = Get.find<AppConfigService>();

    return Obx(() {
      final scripts = configService.scriptRegistry.toList();
      final current = scripts.contains(selectedScript) ? selectedScript : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Script'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ComboBox<String>(
                  value: current,
                  items: scripts
                      .map((s) => ComboBoxItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                  placeholder: const Text('Select script'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.add, size: 14),
                onPressed: () => _showAddDialog(context, configService),
              ),
            ],
          ),
        ],
      );
    });
  }

  Future<void> _showAddDialog(
      BuildContext context, AppConfigService configService) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Add Script'),
        content: TextBox(
          controller: controller,
          placeholder: 'Script name',
          autofocus: true,
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await configService.addScript(name);
      onChanged(name);
    }
  }
}
```

- [ ] **Step 2: Create the dialog**

Follow the `ReplaceProxyDialog` pattern: constructor params in, result out via `Navigator.pop`.

```dart
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/feature/Status/views/components/script_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class LaunchDialog extends StatefulWidget {
  const LaunchDialog({super.key});

  /// Show the dialog and return a LaunchConfig, or null if cancelled.
  static Future<LaunchConfig?> show(BuildContext context) {
    return showDialog<LaunchConfig>(
      context: context,
      builder: (_) => const LaunchDialog(),
    );
  }

  /// Session-scoped last used config for pre-filling.
  static LaunchConfig? _lastConfig;

  @override
  State<LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<LaunchDialog> {
  late String _selectedScript;
  late String _selectedWorld;
  late bool _covert;
  late String _selectedRender;
  final _worldNumberController = TextEditingController();
  final _scriptParamsController = TextEditingController();
  final _advancedFlagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final configService = Get.find<AppConfigService>();
    final last = LaunchDialog._lastConfig;
    _selectedScript = last?.scriptName ?? configService.scriptRegistry.first;
    _selectedWorld = _worldFromConfig(last);
    _covert = last?.covert ?? true;
    _selectedRender = last?.render ?? 'NONE';
    _scriptParamsController.text = last?.scriptParams ?? '';
    _advancedFlagsController.text = last?.advancedFlags ?? '';
  }

  String _worldFromConfig(LaunchConfig? config) {
    if (config == null) return 'auto';
    final w = config.world;
    if (w == 'auto' || w == 'f2p' || w == 'members') return w;
    return 'specific';
  }

  @override
  void dispose() {
    _worldNumberController.dispose();
    _scriptParamsController.dispose();
    _advancedFlagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Launch Configuration'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ScriptSelector(
              selectedScript: _selectedScript,
              onChanged: (v) => setState(() => _selectedScript = v),
            ),
            const SizedBox(height: 12),
            _buildWorldSelector(),
            const SizedBox(height: 12),
            _buildCovertToggle(),
            const SizedBox(height: 12),
            _buildRenderSelector(),
            const SizedBox(height: 12),
            _buildScriptParams(),
            const SizedBox(height: 12),
            _buildAdvancedFlags(),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onLaunch,
          child: const Text('Launch'),
        ),
      ],
    );
  }

  Widget _buildWorldSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('World'),
        const SizedBox(height: 4),
        Row(
          children: [
            ComboBox<String>(
              value: _selectedWorld,
              items: const [
                ComboBoxItem(value: 'auto', child: Text('Auto')),
                ComboBoxItem(value: 'f2p', child: Text('F2P')),
                ComboBoxItem(value: 'members', child: Text('Members')),
                ComboBoxItem(value: 'specific', child: Text('World #')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedWorld = v);
              },
            ),
            if (_selectedWorld == 'specific') ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: NumberBox<int>(
                  value: int.tryParse(_worldNumberController.text),
                  onChanged: (v) {
                    _worldNumberController.text = v?.toString() ?? '';
                  },
                  min: 1,
                  max: 999,
                  placeholder: '#',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCovertToggle() {
    return Row(
      children: [
        const Text('Covert mode'),
        const Spacer(),
        ToggleSwitch(
          checked: _covert,
          onChanged: (v) => setState(() => _covert = v),
        ),
      ],
    );
  }

  Widget _buildRenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Render mode'),
        const SizedBox(height: 4),
        ComboBox<String>(
          value: _selectedRender,
          items: const [
            ComboBoxItem(value: 'NONE', child: Text('None')),
            ComboBoxItem(value: 'ALL', child: Text('All')),
            ComboBoxItem(value: 'GAME', child: Text('Game')),
            ComboBoxItem(value: 'SCRIPT', child: Text('Script')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _selectedRender = v);
          },
        ),
      ],
    );
  }

  Widget _buildScriptParams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Script parameters'),
        const SizedBox(height: 4),
        TextBox(
          controller: _scriptParamsController,
          placeholder: 'e.g. tree oak',
        ),
      ],
    );
  }

  Widget _buildAdvancedFlags() {
    return Expander(
      header: const Text('Advanced flags'),
      content: TextBox(
        controller: _advancedFlagsController,
        placeholder: 'e.g. -fps 15',
      ),
    );
  }

  void _onLaunch() {
    String world = _selectedWorld;
    if (world == 'specific') {
      world = _worldNumberController.text.isNotEmpty
          ? _worldNumberController.text
          : 'auto';
    }

    final config = LaunchConfig(
      scriptName: _selectedScript,
      world: world,
      covert: _covert,
      render: _selectedRender,
      scriptParams: _scriptParamsController.text.trim(),
      advancedFlags: _advancedFlagsController.text.trim(),
    );

    LaunchDialog._lastConfig = config;
    Navigator.pop(context, config);
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/feature/Status/views/dialogs/launch_dialog.dart lib/feature/Status/views/components/script_selector.dart
git commit -m "feat(ui): add launch configuration dialog with script registry"
```

---

### Task 14: Create BotStatusBadge component

**Files:**
- Create: `lib/feature/Status/views/components/bot_status_badge.dart`

- [ ] **Step 1: Create the component**

```dart
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:fluent_ui/fluent_ui.dart';

class BotStatusBadge extends StatelessWidget {
  final ClientStatus? status;
  final int retryCount;

  const BotStatusBadge({
    super.key,
    this.status,
    this.retryCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _resolve() {
    switch (status) {
      case ClientStatus.running:
        return ('Running', Colors.green);
      case ClientStatus.restarting:
        return ('Restarting $retryCount/${WatchdogService.maxRetries}', Colors.orange);
      case ClientStatus.failed:
        return ('Failed $retryCount/${WatchdogService.maxRetries}', Colors.orange);
      case ClientStatus.stopped:
        return ('Stopped', Colors.grey);
      case ClientStatus.banned:
        return ('Banned', Colors.red);
      case ClientStatus.awaitingAccount:
        return ('Awaiting Account', Colors.blue);
      case null:
        return ('Stopped', Colors.grey);
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/Status/views/components/bot_status_badge.dart
git commit -m "feat(ui): add BotStatusBadge component with watchdog status display"
```

---

### Task 15: Create BotFarmSummaryBar component

**Files:**
- Create: `lib/feature/Status/views/components/bot_farm_summary_bar.dart`

- [ ] **Step 1: Create the component**

```dart
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class BotFarmSummaryBar extends StatelessWidget {
  final VoidCallback onStartAll;
  final VoidCallback onStopAll;

  const BotFarmSummaryBar({
    super.key,
    required this.onStartAll,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    final watchdog = Get.find<WatchdogService>();

    return Obx(() {
      // Force re-evaluation when trackedClients changes
      watchdog.trackedClients.length;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _statChip('Running', watchdog.runningCount, Colors.green),
            const SizedBox(width: 8),
            _statChip('Restarting', watchdog.restartingCount, Colors.orange),
            const SizedBox(width: 8),
            _statChip('Stopped', watchdog.stoppedCount, Colors.grey),
            const SizedBox(width: 8),
            _statChip('Banned', watchdog.bannedCount, Colors.red),
            const Spacer(),
            FilledButton(
              onPressed: onStartAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.play, size: 12),
                  SizedBox(width: 4),
                  Text('Start All'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: onStopAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.stop, size: 12),
                  SizedBox(width: 4),
                  Text('Stop All'),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/Status/views/components/bot_farm_summary_bar.dart
git commit -m "feat(ui): add BotFarmSummaryBar with reactive watchdog counts"
```

---

## Chunk 5: Integration — Wire Everything Together

### Task 16: Rewrite StatusController to delegate to WatchdogService

**Files:**
- Modify: `lib/feature/Status/controller/status_controller.dart`

- [ ] **Step 1: Remove polling, add watchdog delegation**

Replace the entire file:

```dart
import 'dart:async';

import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/skills.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/helper/logger.dart';

class StatusController extends GetxController {
  var isLoading = true.obs;
  final accountList = <JagexAccount>[].obs;

  AccountRepository? _accountRepository;
  ProxyRepository? _proxyRepository;
  WatchdogService? _watchdog;

  @override
  void onInit() async {
    super.onInit();
    _initDependencies();
    await getAccountsData();
    isLoading.value = false;
  }

  void _initDependencies() {
    try {
      final dbService = Get.find<DatabaseService>();
      _accountRepository = dbService.accountRepository;
      _proxyRepository = dbService.proxyRepository;
    } catch (e) {
      logger.e('DatabaseService not initialized: $e');
    }
    try {
      _watchdog = Get.find<WatchdogService>();
    } catch (e) {
      logger.e('WatchdogService not available: $e');
    }
  }

  WatchdogService? get watchdog => _watchdog;

  Future<void> getAccountsData() async {
    if (_accountRepository == null) return;

    try {
      final accounts = await _accountRepository!.getAllAccounts();

      ProxyController? proxyController;
      try {
        proxyController = Get.find<ProxyController>();
      } catch (_) {}

      accountList
        ..clear()
        ..addAll([
          for (var account in accounts)
            JagexAccount(
              id: account.id,
              accountName: account.accountName,
              birthday: account.birthday,
              email: account.email,
              password: account.password,
              proxySlotId: account.proxySlotId,
              proxyAddress:
                  _resolveProxyAddress(account.proxySlotId, proxyController),
              characters: account.characters
                  .map((c) => Character(
                        id: c.id,
                        banned: c.banned,
                        name: c.name,
                        actualSkills: _mapSkills(c.actualSkills),
                        targetSkills: _mapSkills(c.targetSkills),
                      ))
                  .toList(),
            )
        ]);
    } catch (err) {
      logger.e(err);
    }
  }

  /// Launch a single character with the given config.
  Future<void> launchCharacter(
    JagexAccount account,
    Character character,
    LaunchConfig config,
  ) async {
    if (_watchdog == null) return;

    // Resolve proxy address
    String? proxyAddress;
    if (account.proxySlotId != null && _proxyRepository != null) {
      final ip =
          await _proxyRepository!.getActiveIpForSlot(account.proxySlotId!);
      if (ip != null) {
        proxyAddress = ip.ipAddress;
      }
    }

    try {
      final nativeService = Get.find<NativeCommandsService>();
      final pid = await nativeService.runGameClient(
        characterName: character.name,
        proxyAddress: proxyAddress,
        scriptName: config.scriptName,
        world: config.world,
        covert: config.covert,
        render: config.render,
        scriptParams: config.scriptParams,
        advancedFlags: config.advancedFlags,
      );

      final tracked = TrackedClient(
        characterName: character.name,
        characterId: character.id ?? 0,
        accountId: account.id ?? 0,
        proxySlotId: account.proxySlotId,
        proxyAddress: proxyAddress,
        launchConfig: config,
        pid: pid,
        status: ClientStatus.running,
        launchedAt: DateTime.now(),
      );
      _watchdog!.track(tracked);
    } catch (e) {
      logger.e('Failed to launch ${character.name}: $e');
    }
  }

  /// Launch all launchable characters with the given config.
  Future<void> launchAll(LaunchConfig config) async {
    for (final account in accountList) {
      for (final character in account.characters) {
        // Skip if already tracked (running, restarting, etc.)
        if (_watchdog?.trackedClients.containsKey(character.name) == true) {
          final existing = _watchdog!.trackedClients[character.name]!;
          if (existing.status != ClientStatus.stopped) continue;
        }
        // Skip banned characters (DB flag)
        if (character.banned) continue;

        await launchCharacter(account, character, config);
        // Small delay between launches to avoid overwhelming
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// Stop a specific character.
  Future<void> stopCharacter(String characterName) async {
    await _watchdog?.stop(characterName);
  }

  /// Stop all tracked characters.
  Future<void> stopAll() async {
    await _watchdog?.stopAll();
  }

  String _resolveProxyAddress(
      int? proxySlotId, ProxyController? proxyController) {
    if (proxySlotId == null || proxyController == null) return 'No proxy';
    try {
      final slot = proxyController.proxySlots
          .firstWhereOrNull((s) => s.id == proxySlotId);
      if (slot == null) return 'No proxy';
      final currentIp = proxyController.getCurrentIpForSlot(slot);
      return currentIp?.ipAddress ?? 'No IP';
    } catch (_) {
      return 'No proxy';
    }
  }

  Skills _mapSkills(SkillsEntity skillsEntity) {
    return Skills(
      attack: skillsEntity.attack,
      defence: skillsEntity.defence,
      strength: skillsEntity.strength,
      hitpoints: skillsEntity.hitpoints,
      range: skillsEntity.range,
      prayer: skillsEntity.prayer,
      magic: skillsEntity.magic,
      cooking: skillsEntity.cooking,
      woodcutting: skillsEntity.woodcutting,
      fletching: skillsEntity.fletching,
      fishing: skillsEntity.fishing,
      firemaking: skillsEntity.firemaking,
      crafting: skillsEntity.crafting,
      mining: skillsEntity.mining,
      smithing: skillsEntity.smithing,
      agility: skillsEntity.agility,
      herblore: skillsEntity.herblore,
      thieving: skillsEntity.thieving,
      slayer: skillsEntity.slayer,
      farming: skillsEntity.farming,
      runecrafting: skillsEntity.runecrafting,
      construction: skillsEntity.construction,
      hunter: skillsEntity.hunter,
    );
  }

  void copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> deleteAccount(int accountId) async {
    if (_accountRepository == null) return;
    try {
      await _accountRepository!.deleteAccount(accountId);
      await getAccountsData();
    } catch (e) {
      logger.e('Failed to delete account: $e');
    }
  }
}
```

- [ ] **Step 2: Add missing import for NativeCommandsService**

The `launchCharacter` method uses `Get.find<NativeCommandsService>()` — add at top:

```dart
import 'package:command_center/config/services/native_commands_service.dart';
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/feature/Status/controller/status_controller.dart
git commit -m "refactor(status): delegate process management to WatchdogService"
```

---

### Task 17: Update AccountListSection to use watchdog and launch dialog

**Files:**
- Modify: `lib/feature/Status/views/sections/account_list_section.dart`

- [ ] **Step 1: Replace ProcessStatusBadge import and add new imports**

Replace the import of `process_status_badge.dart` and `process_model.dart`:

```dart
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/feature/Status/views/components/bot_status_badge.dart';
import 'package:command_center/feature/Status/views/dialogs/launch_dialog.dart';
import 'package:get/get.dart';
```

- [ ] **Step 2: Update `isRunning` and status badge in `_buildAccountsTable`**

In `_buildAccountsTable`, replace the `isRunning` determination at line 81-82:

Old:
```dart
              final isRunning = row.character != null &&
                  controller.processClients.containsKey(row.character!.name);
```

New (use `Get.find` since `AccountListSection` is a `StatelessWidget` without a stored watchdog reference):
```dart
              final watchdog = Get.find<WatchdogService>();
              final tracked = watchdog.trackedClients[row.character?.name];
              final isRunning = tracked != null &&
                  tracked.status == ClientStatus.running;
```

Replace `ProcessStatusBadge` usage (line 116) with:

```dart
                    Expanded(
                      child: Obx(() {
                        final tracked = Get.find<WatchdogService>()
                            .trackedClients[row.character?.name];
                        return BotStatusBadge(
                          status: tracked?.status,
                          retryCount: tracked?.retryCount ?? 0,
                        );
                      }),
                    ),
```

- [ ] **Step 3: Update actions cell to use launch dialog and watchdog stop**

Replace `_buildActionsCell` method:

```dart
  Widget _buildActionsCell(
    BuildContext context,
    JagexAccount account,
    Character character,
    bool isRunning,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            Tooltip(
              message: 'Stop',
              child: IconButton(
                icon: Icon(FluentIcons.stop, color: Colors.red),
                onPressed: () async {
                  await controller.stopCharacter(character.name);
                },
              ),
            )
          else
            Tooltip(
              message: 'Start',
              child: IconButton(
                icon: Icon(FluentIcons.play, color: Colors.green),
                onPressed: () async {
                  final config = await LaunchDialog.show(context);
                  if (config != null) {
                    await controller.launchCharacter(account, character, config);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Remove old ProcessStatusBadge file**

Delete `lib/feature/Status/views/components/process_status_badge.dart` — replaced by `BotStatusBadge`.

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/feature/Status/views/sections/account_list_section.dart
git rm lib/feature/Status/views/components/process_status_badge.dart
git commit -m "feat(ui): wire launch dialog and watchdog status into account list"
```

---

### Task 18: Add BotFarmSummaryBar to StatusScreen

**Files:**
- Modify: `lib/feature/Status/views/status_screen.dart`

- [ ] **Step 1: Add import and summary bar**

Add imports:

```dart
import 'package:command_center/feature/Status/views/components/bot_farm_summary_bar.dart';
import 'package:command_center/feature/Status/views/dialogs/launch_dialog.dart';
```

In `_buildAccountsContent`, add the summary bar between `SummaryCards` and `AccountListSection` (after line 126):

```dart
          const SizedBox(height: 16),
          BotFarmSummaryBar(
            onStartAll: () async {
              final config = await LaunchDialog.show(context);
              if (config != null) {
                await controller.launchAll(config);
              }
            },
            onStopAll: () async {
              await controller.stopAll();
            },
          ),
```

- [ ] **Step 2: Update Refresh button — remove `updateRunningProcesses()` call**

In the header's Refresh CommandBarButton (lines 31-34), the current code calls both `getAccountsData()` and `updateRunningProcesses()`. Remove only the `updateRunningProcesses()` call — keep `getAccountsData()` since it refreshes the account list from the DB:

```dart
              onPressed: () async {
                await controller.getAccountsData();
              },
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/feature/Status/views/status_screen.dart
git commit -m "feat(ui): add bot farm summary bar to status screen"
```

---

### Task 19: Final verification — full build

- [ ] **Step 1: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors or warnings from our changes

- [ ] **Step 2: Build Windows**

Run: `flutter build windows`
Expected: Successful build with no errors

- [ ] **Step 3: Commit any remaining fixes**

If analyze or build surface issues, fix them and commit:

```bash
git commit -m "fix: address build issues from script management integration"
```

---

### Task 20: Clean up dead code and fix remaining `processClients` references

**Files:**
- Modify: `lib/feature/Status/views/status_screen.dart` (SummaryCards)
- Modify: `lib/feature/main_menu/views/sections/characters_status_section.dart`
- Modify: `lib/feature/app.dart`

- [ ] **Step 1: Fix SummaryCards in StatusScreen**

`SummaryCards` at line 121-125 of `status_screen.dart` passes `runningProcesses: controller.processClients.length`. Replace with:

```dart
          SummaryCards(
            totalAccounts: controller.accountList.length,
            totalCharacters: totalCharacters,
            runningProcesses: controller.watchdog?.runningCount ?? 0,
          ),
```

- [ ] **Step 2: Fix CharactersStatusSection**

In `lib/feature/main_menu/views/sections/characters_status_section.dart`, replace the `_getCharacterCounts()` method. It currently reads `ctrl.processClients` (line 60). Replace with watchdog:

```dart
  Map<String, int> _getCharacterCounts() {
    try {
      final ctrl = statusController ?? Get.find<StatusController>();
      final accounts = ctrl.accountList;
      final total = accounts.length;
      final running = ctrl.watchdog?.runningCount ?? 0;

      return {'total': total, 'running': running, 'stopped': total - running};
    } catch (_) {
      return {'total': 0, 'running': 0, 'stopped': 0};
    }
  }
```

Remove the `ProcessClient` import if present — no longer needed.

- [ ] **Step 3: Fix app.dart onWindowClose**

In `lib/feature/app.dart`, around line 358-367, the `onWindowClose` handler kills all running processes via `statusController.processClients`. Per the spec, **bots are left running on app close**. Remove the process-killing block:

Old:
```dart
      try {
        final statusController = Get.find<StatusController>();
        // Kill all running processes
        for (final process in statusController.processClients.values) {
          try {
            Process.killPid(process.processId);
          } catch (_) {}
        }
      } catch (_) {}
```

Replace with nothing (remove the entire block). The watchdog's in-memory state is lost, but the startup recapture scan will rediscover running bots on next launch.

- [ ] **Step 4: Search for any remaining references**

Search for: `processClients`, `updateRunningProcesses`, `_processCheckTimer`, `ProcessClient.parseProcessData`, `output.obs`, `stopGameClient`, `runGameClient(account)` (old single-param signature)

Run: `flutter analyze`
Expected: No errors

Fix any remaining references found.

- [ ] **Step 5: Final build**

Run: `flutter build windows`
Expected: Clean build

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: clean up dead processClients references, bots left running on close"
```
