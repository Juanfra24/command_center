import 'package:get/get.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/feature/main_menu/data/bot_tile_data.dart';
import 'package:command_center/feature/main_menu/data/proxy_health_data.dart';

class MainMenuController extends GetxController {
  // Follow codebase defensive pattern: nullable + try-catch
  StatusController? _statusController;
  ProxyController? _proxyController;
  ProxyScoringController? _scoringController;
  WatchdogService? _watchdogService;

  // Bot status data
  final botTiles = <BotTileData>[].obs;

  // Proxy health data
  final proxyHealth = ProxyHealthData.empty().obs;

  // Quick action loading states
  final isScoringAll = false.obs;
  final isSyncing = false.obs;

  // Workers for disposal
  final List<Worker> _workers = [];

  @override
  void onInit() {
    super.onInit();
    try {
      _statusController = Get.find<StatusController>();
    } catch (_) {}
    try {
      _proxyController = Get.find<ProxyController>();
    } catch (_) {}
    try {
      _scoringController = Get.find<ProxyScoringController>();
    } catch (_) {}
    try {
      _watchdogService = Get.find<WatchdogService>();
    } catch (_) {}

    _refreshData();

    // Re-compute when tracked clients change
    if (_watchdogService != null) {
      _workers.add(
        ever(_watchdogService!.trackedClients, (_) => _refreshBotTiles()),
      );
    }
    if (_statusController != null) {
      _workers.add(
        ever(_statusController!.accountList, (_) => _refreshBotTiles()),
      );
    }
    if (_proxyController != null) {
      _workers.add(
        ever(_proxyController!.proxySlots, (_) => _refreshProxyHealth()),
      );
    }
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _refreshData() {
    _refreshBotTiles();
    _refreshProxyHealth();
  }

  void _refreshBotTiles() {
    if (_statusController == null) return;
    final tiles = <BotTileData>[];
    for (final account in _statusController!.accountList) {
      for (final character in account.characters) {
        final tracked = _watchdogService?.trackedClients[character.name];
        String status = 'stopped';
        Duration? uptime;
        if (character.banned) {
          status = 'banned';
        } else if (tracked != null) {
          status = tracked.status.name;
          if (tracked.status == ClientStatus.running &&
              tracked.launchedAt != null) {
            uptime = DateTime.now().difference(tracked.launchedAt!);
          }
        }
        tiles.add(BotTileData(
          characterId: character.id ?? 0,
          characterName: character.name,
          defaultScriptName: character.defaultScriptName,
          proxySlotName: account.proxyAddress,
          countryCode: null, // could resolve from proxy controller
          status: status,
          uptime: uptime,
        ));
      }
    }
    botTiles.assignAll(tiles);
  }

  void _refreshProxyHealth() {
    if (_proxyController == null) return;
    int excellent = 0, fair = 0, poor = 0, bad = 0, unscored = 0;
    final attention = <ProxyAttentionItem>[];

    for (final slot in _proxyController!.proxySlots) {
      final slotId = slot.id ?? 0;
      final ip = _proxyController!.getCurrentIpForSlot(slot);
      if (ip == null || !ip.hasBeenScored) {
        unscored++;
        attention.add(ProxyAttentionItem(
          slotId: slotId,
          slotName: slot.slotName,
          isUnscored: true,
        ));
        continue;
      }
      if (ip.fraudScore <= 30) {
        excellent++;
      } else if (ip.fraudScore <= 60) {
        fair++;
      } else if (ip.fraudScore <= 80) {
        poor++;
        attention.add(ProxyAttentionItem(
          slotId: slotId,
          slotName: slot.slotName,
          fraudScore: ip.fraudScore,
          connectionType: ip.connectionType,
        ));
      } else {
        bad++;
        attention.add(ProxyAttentionItem(
          slotId: slotId,
          slotName: slot.slotName,
          fraudScore: ip.fraudScore,
          connectionType: ip.connectionType,
        ));
      }
    }

    proxyHealth.value = ProxyHealthData(
      excellentCount: excellent,
      fairCount: fair,
      poorCount: poor,
      badCount: bad,
      unscoredCount: unscored,
      attentionItems: attention,
    );
  }

  Future<void> scoreAllIps() async {
    isScoringAll.value = true;
    try {
      await _scoringController?.scoreAllCurrentIps();
    } finally {
      isScoringAll.value = false;
    }
  }

  Future<void> syncProxies() async {
    isSyncing.value = true;
    try {
      await _proxyController?.syncWithWebshare();
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> startAll() async {
    await _statusController?.launchWithDefaultScripts();
  }

  Future<void> stopAll() async {
    await _statusController?.stopAll();
  }
}
