import 'dart:async';

import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_handlers.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:get/get.dart';

class WatchdogService extends GetxService {
  final NativeCommandsService _nativeCommandsService;
  late final WatchdogHandlers _handlers;

  static const int maxRetries = 5;
  static const Duration quickDeathThreshold = Duration(seconds: 30);
  static const Duration _stabilityThreshold = Duration(minutes: 5);
  static const int _maxDiscoveryMisses = 3;
  static const int banEscalationThreshold = 3;
  static const int maxCooldownSeconds = 300;

  Timer? _pollTimer;
  bool _tickInProgress = false;

  final trackedClients = <String, TrackedClient>{}.obs;

  WatchdogService({
    required NativeCommandsService nativeCommandsService,
    required NotificationService notificationService,
    required ProxyAutoRotationService autoRotationService,
    required AccountRepository accountRepository,
    required ProxyRepository proxyRepository,
  }) : _nativeCommandsService = nativeCommandsService {
    _handlers = WatchdogHandlers(
      nativeCommandsService: nativeCommandsService,
      notificationService: notificationService,
      autoRotationService: autoRotationService,
      accountRepository: accountRepository,
      proxyRepository: proxyRepository,
    );
  }

  @override
  void onInit() {
    super.onInit();
    _handlers.recaptureRunningClients(trackedClients);
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

  /// Re-evaluate and apply the correct polling interval.
  /// Called after state changes — _startPolling reads current state.
  void _adjustPollingRate() {
    _startPolling();
  }

  Future<void> _tick() async {
    if (trackedClients.isEmpty || _tickInProgress) return;
    _tickInProgress = true;

    try {
      final liveProcesses = await _nativeCommandsService.listJavaProcesses();
      final livePids = <int>{};
      for (final p in liveProcesses) {
        livePids.add(p.processId);
      }

      bool changed = false;

      for (final client in trackedClients.values.toList()) {
        // Skip terminal states
        if (client.status == ClientStatus.stopped ||
            client.status == ClientStatus.awaitingAccount) {
          continue;
        }

        // Discovery: client launched but PID not yet confirmed
        if (client.pid == null) {
          final match = _handlers.discoverPid(client, liveProcesses);
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
              DateTime.now().difference(client.launchedAt!) >
                  _stabilityThreshold) {
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
        _handlers.classifyDeath(client);
      }

      // Handle restarts and bans
      for (final client in trackedClients.values.toList()) {
        if (client.status == ClientStatus.restarting ||
            client.status == ClientStatus.failed) {
          changed |= await _handlers.handleRestart(client);
        } else if (client.status == ClientStatus.banned) {
          await _handlers.handleBan(client);
          changed = true;
        }
      }

      if (changed) {
        trackedClients.refresh();
        _adjustPollingRate();
      }
    } finally {
      _tickInProgress = false;
    }
  }

}
