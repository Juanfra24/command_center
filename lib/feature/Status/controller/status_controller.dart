import 'dart:async';
import 'dart:io';

import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/helper/logger.dart';

class StatusController extends GetxController {
  var isLoading = true.obs;
  Timer? _processCheckTimer;
  List<JagexAccount> accountList = <JagexAccount>[].obs;
  List<int> processList = <int>[].obs;
  RxMap<String, ProcessClient> processClients =
      <String, ProcessClient>{}.obs; // Maps character names to their processes

  AccountRepository? _accountRepository;
  final NativeCommandsService _nativeCommandsService = Get.find();

  @override
  void onInit() async {
    super.onInit();
    _initRepositories();
    await getAccountsData().then((_) {
      updateRunningProcesses();
      _startProcessCheckTimer();
    });
    isLoading.value = false;
  }

  void _initRepositories() {
    try {
      final dbService = Get.find<DatabaseService>();
      _accountRepository = dbService.accountRepository;
    } catch (e) {
      logger.e('DatabaseService not initialized: $e');
    }
  }

  void _startProcessCheckTimer() {
    _processCheckTimer?.cancel(); // Cancel any existing timer
    _processCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      updateRunningProcesses();
    });
  }

  Future<void> updateRunningProcesses() async {
    var javaProcesses = await _nativeCommandsService.listJavaProcesses();
    var newRunningProcesses = <String, ProcessClient>{};
    for (var process in javaProcesses) {
      var match = RegExp(r'-script "(.*?)" -account "(.*?)"')
          .firstMatch(process.commandLine);
      if (match != null) {
        var characterName = match.group(2);
        if (characterName != null) {
          newRunningProcesses[characterName] = process;
        }
      }
    }
    processClients.value = newRunningProcesses;
  }

  Future<void> getAccountsData() async {
    if (_accountRepository == null) return;

    try {
      final accounts = await _accountRepository!.getAllAccounts();

      // Resolve proxy addresses
      ProxyController? proxyController;
      try {
        proxyController = Get.find<ProxyController>();
      } catch (_) {}

      accountList
        ..clear()
        ..addAll([
          for (var account in accounts)
            JagexAccount(
              accountName: account.accountName,
              birthday: account.birthday,
              email: account.email,
              password: account.password,
              proxyAddress: _resolveProxyAddress(account.proxySlotId, proxyController),
              characters: account.characters.map((c) => Character(
                banned: c.banned,
                name: c.name,
                actualSkills: _mapSkills(c.actualSkills),
                targetSkills: _mapSkills(c.targetSkills),
              )).toList(),
            )
        ]);
    } catch (err) {
      logger.e(err);
    }
  }

  String _resolveProxyAddress(int? proxySlotId, ProxyController? proxyController) {
    if (proxySlotId == null || proxyController == null) return 'No proxy';
    try {
      final slot = proxyController.proxySlots.firstWhereOrNull((s) => s.id == proxySlotId);
      if (slot == null) return 'No proxy';
      final currentIp = proxyController.getCurrentIpForSlot(slot);
      return currentIp?.ipAddress ?? 'No IP';
    } catch (_) {
      return 'No proxy';
    }
  }

  Skills _mapSkills(dynamic skillsEntity) {
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
    // Note: InfoBar display is handled in the UI layer for Fluent UI
  }

  Future<void> runGameClient(JagexAccount account) async {
    try {
      var proxy = account.proxyAddress == "none" ? null : account.proxyAddress;
      await _nativeCommandsService.runGameClient(
        characterName: account.characters[0].name,
        proxyAddress: proxy,
        scriptName: null,
      );
      sleep(const Duration(milliseconds: 100));
      await updateRunningProcesses(); // Update immediately after starting
      _startProcessCheckTimer(); // Restart the timer to ensure it's running
    } catch (e) {
      print('Failed to run game script: $e');
    }
  }

  Future<void> stopGameClient(ProcessClient? process) async {
    if (process != null) {
      await _nativeCommandsService.killProcess(process.processId);
      sleep(const Duration(milliseconds: 100));
      updateRunningProcesses(); // Refresh the running process list
      _startProcessCheckTimer(); // Restart the timer to ensure it's running
    }
  }

  @override
  void onClose() async {
    for (var processId in processList) {
      await _nativeCommandsService.killProcess(processId);
    }
    _processCheckTimer?.cancel();
    super.onClose();
  }
}
