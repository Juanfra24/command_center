import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/core/helper/proxy_url_builder.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/character.dart';
import 'package:command_center/domain/entities/skills.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/helper/logger.dart';

class StatusController extends GetxController {
  var isLoading = true.obs;
  final accountList = <JagexAccount>[].obs;
  bool _isRefreshing = false;

  // Worker to refresh proxy addresses when active IPs change.
  // NOTE: proxyAddress on JagexAccount is resolved once per getAccountsData()
  // call and does not update reactively on its own. This worker ensures the
  // displayed address stays in sync after auto-rotation or manual IP changes.
  Worker? _proxyIpWorker;

  AccountRepository? _accountRepository;
  ProxyRepository? _proxyRepository;
  BotEngine? _botEngine;
  WatchdogService? _watchdog;

  @override
  void onInit() {
    super.onInit();
    _initDependencies();
    _loadData();
    _registerProxyIpWorker();
  }

  void _registerProxyIpWorker() {
    try {
      final proxyCtrl = Get.find<ProxyController>();
      _proxyIpWorker = ever(proxyCtrl.ipAddresses, (_) => getAccountsData());
    } catch (_) {
      // ProxyController not yet available; proxy addresses will update on
      // next manual refresh.
    }
  }

  @override
  void onClose() {
    _proxyIpWorker?.dispose();
    super.onClose();
  }

  Future<void> _loadData() async {
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
      _botEngine = Get.find<BotEngine>();
    } catch (e) {
      logger.e('BotEngine not available: $e');
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
    if (_isRefreshing) return;
    _isRefreshing = true;

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
                        defaultScriptName: c.defaultScriptName,
                      ))
                  .toList(),
            )
        ]);
    } catch (err) {
      logger.e(err);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Launch a single character with the given config.
  Future<void> launchCharacter(
    JagexAccount account,
    Character character,
    LaunchConfig config,
  ) async {
    if (_watchdog == null || _botEngine == null) return;
    if (character.id == null || account.id == null) {
      logger.e('Cannot launch ${character.name}: missing DB id');
      return;
    }

    // Build SOCKS5 proxy URL if a proxy slot is assigned
    String? proxyUrl;
    if (account.proxySlotId != null && _proxyRepository != null) {
      final slot = await _proxyRepository!.getSlotById(account.proxySlotId!);
      if (slot != null && slot.socksPort != null) {
        final ip =
            await _proxyRepository!.getActiveIpForSlot(account.proxySlotId!);
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

    final result = await _botEngine!.launch(
      characterId: character.id!,
      accountId: account.id!,
      characterName: character.name,
      email: account.email,
      password: account.password,
      proxyUrl: proxyUrl,
      config: config,
    );

    final tracked = TrackedClient(
      characterName: character.name,
      characterId: character.id!,
      accountId: account.id!,
      proxySlotId: account.proxySlotId,
      email: account.email,
      password: account.password,
      proxyUrl: proxyUrl,
      launchConfig: config,
      pid: result.pid,
      statusPort: result.statusPort,
      status: ClientStatus.running,
      launchedAt: DateTime.now(),
    );
    await _watchdog!.track(tracked);
  }

  /// Launch all launchable characters with the given config.
  Future<void> launchAll(LaunchConfig config) async {
    // Snapshot to avoid iterating a live RxList across awaits
    final snapshot = List.of(accountList);
    int consecutiveFailures = 0;
    const maxConsecutiveFailures = 3;

    outer:
    for (final account in snapshot) {
      for (final character in account.characters) {
        // Skip if already tracked (running, restarting, etc.)
        if (_watchdog?.trackedClients.containsKey(character.name) == true) {
          final existing = _watchdog!.trackedClients[character.name]!;
          if (existing.status != ClientStatus.stopped) continue;
        }
        // Skip banned characters (DB flag)
        if (character.banned) continue;

        try {
          await launchCharacter(account, character, config);
          consecutiveFailures = 0;
          // Small delay between launches to avoid overwhelming
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          logger.e('Failed to launch ${character.name}: $e');
          consecutiveFailures++;
          if (consecutiveFailures >= maxConsecutiveFailures) {
            logger.e(
              'Aborting launchAll after $maxConsecutiveFailures consecutive failures',
            );
            break outer;
          }
        }
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
      // Stop any running characters before deleting
      final account = await _accountRepository!.getAccountById(accountId);
      if (account != null && _watchdog != null) {
        for (final character in account.characters) {
          if (_watchdog!.trackedClients.containsKey(character.name)) {
            await _watchdog!.stop(character.name);
          }
        }
      }
      await _accountRepository!.deleteAccount(accountId);
      await getAccountsData();
      try {
        Get.find<StatusSelectionController>().clearSelection();
      } catch (_) {}
    } catch (e) {
      logger.e('Failed to delete account: $e');
    }
  }

  /// Add a character to an existing account.
  Future<void> addCharacterToAccount(
      int accountId, String characterName) async {
    if (_accountRepository == null) return;
    try {
      final account = await _accountRepository!.getAccountById(accountId);
      if (account == null) return;
      final updated = account.copyWith(
        characters: [
          ...account.characters,
          CharacterEntity(
            accountId: accountId,
            name: characterName,
            banned: false,
            actualSkills: SkillsEntity.empty(),
            targetSkills: SkillsEntity.empty(),
          ),
        ],
      );
      await _accountRepository!.updateAccount(updated);
      await getAccountsData();
    } catch (e) {
      logger.e('Failed to add character to account: $e');
    }
  }

  Future<void> updateDefaultScript(int characterId, String scriptName) async {
    await _accountRepository?.updateCharacterDefaultScript(
        characterId, scriptName);
    await getAccountsData();
  }

  /// Returns (withScripts, withoutScripts) counts for the given character IDs.
  ({int withScripts, int withoutScripts}) getBulkLaunchReadiness([
    Set<int>? characterIds,
  ]) {
    int withScripts = 0;
    int withoutScripts = 0;
    for (final account in accountList) {
      for (final character in account.characters) {
        if (characterIds != null && !characterIds.contains(character.id)) {
          continue;
        }
        if (character.defaultScriptName != null) {
          withScripts++;
        } else {
          withoutScripts++;
        }
      }
    }
    return (withScripts: withScripts, withoutScripts: withoutScripts);
  }

  /// Launches characters that have default scripts assigned.
  /// Skips characters that are already tracked (running/restarting).
  Future<int> launchWithDefaultScripts([Set<int>? characterIds]) async {
    int count = 0;
    // Snapshot to avoid iterating a live RxList across awaits
    final snapshot = List.of(accountList);
    for (final account in snapshot) {
      for (final character in account.characters) {
        if (characterIds != null && !characterIds.contains(character.id)) {
          continue;
        }
        // Skip if already tracked (running, restarting, etc.)
        if (_watchdog?.trackedClients.containsKey(character.name) == true) {
          final existing = _watchdog!.trackedClients[character.name]!;
          if (existing.status != ClientStatus.stopped) continue;
        }
        if (character.banned) continue;
        if (character.defaultScriptName == null) continue;
        final config = LaunchConfig(scriptName: character.defaultScriptName!);
        try {
          await launchCharacter(account, character, config);
          count++;
        } catch (e) {
          logger.e('Failed to launch ${character.name}: $e');
        }
      }
    }
    return count;
  }
}
