import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/bot_engine/bot_status.dart';
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
  final BotEngine _botEngine;
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
    required BotEngine botEngine,
    required NotificationService notificationService,
    required ProxyAutoRotationService autoRotationService,
    required AccountRepository accountRepository,
    required ProxyRepository proxyRepository,
  })  : _nativeCommandsService = nativeCommandsService,
        _botEngine = botEngine {
    _handlers = WatchdogHandlers(
      botEngine: botEngine,
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
    final wasEmpty = trackedClients.isEmpty;
    trackedClients[client.characterName] = client;
    trackedClients.refresh();
    // Switch to faster polling when first client is added
    if (wasEmpty) _startPolling();
    logger.i('Tracking ${client.characterName} (PID: ${client.pid})');
  }

  /// Stop a client: kill process (with profile cleanup), remove from tracking.
  Future<void> stop(String characterName) async {
    final client = trackedClients[characterName];
    if (client != null && client.pid != null) {
      await _botEngine.stop(client.pid!);
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

  void _startPolling({Duration? interval}) {
    _pollTimer?.cancel();
    interval ??= trackedClients.isEmpty
        ? const Duration(seconds: 30)
        : const Duration(seconds: 10);
    _pollTimer = Timer.periodic(interval, (_) => _tick());
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
          // Stability reset: alive > 5 min → reset retry counter only.
          // consecutiveQuickDeaths is only reset on a normal death (in classifyDeath)
          // to preserve ban escalation across restart cycles.
          if (client.launchedAt != null &&
              DateTime.now().difference(client.launchedAt!) >
                  _stabilityThreshold) {
            if (client.retryCount > 0) {
              client.retryCount = 0;
              changed = true;
            }
          }
          // Poll Status API if port is known
          if (client.statusPort != null) {
            try {
              final httpClient = HttpClient()
                ..connectionTimeout = const Duration(seconds: 2);
              final request = await httpClient
                  .getUrl(Uri.parse(
                      'http://127.0.0.1:${client.statusPort}/status'))
                  .timeout(const Duration(seconds: 2));
              final response =
                  await request.close().timeout(const Duration(seconds: 2));
              if (response.statusCode == 200) {
                final body = await response.transform(utf8.decoder).join();
                client.lastStatus = BotStatus.fromJson(
                    jsonDecode(body) as Map<String, dynamic>);
                changed = true;
              } else {
                client.lastStatus = null;
              }
              httpClient.close();
            } catch (_) {
              client.lastStatus = null;
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
      }
    } catch (e) {
      logger.e('Watchdog tick error: $e');
    } finally {
      _tickInProgress = false;
    }
  }

}
