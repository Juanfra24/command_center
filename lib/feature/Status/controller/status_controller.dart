import 'dart:async';

import 'package:command_center/config/services/native_commands_service.dart';
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
