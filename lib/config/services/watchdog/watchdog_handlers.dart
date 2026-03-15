import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';

/// Handles death classification, restart scheduling, and ban processing.
/// Extracted from WatchdogService to respect the 250-line service ceiling.
class WatchdogHandlers {
  final NativeCommandsService _nativeCommandsService;
  final NotificationService _notificationService;
  final ProxyAutoRotationService _autoRotationService;
  final AccountRepository _accountRepository;
  final ProxyRepository _proxyRepository;

  WatchdogHandlers({
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

  /// Classify a client death as quick (potential ban) or normal (restart).
  void classifyDeath(TrackedClient client) {
    final now = DateTime.now();
    final alive = client.launchedAt != null
        ? now.difference(client.launchedAt!)
        : Duration.zero;

    client.pid = null;
    client.lastDeathAt = now;

    if (alive < WatchdogService.quickDeathThreshold) {
      client.consecutiveQuickDeaths++;
      if (client.consecutiveQuickDeaths >= WatchdogService.banEscalationThreshold) {
        client.status = ClientStatus.banned;
        logger.e('Ban detected for ${client.characterName} '
            '(${client.consecutiveQuickDeaths} consecutive quick deaths)');
      } else {
        client.status = ClientStatus.failed;
        client.retryCount++;
        logger.w(
            'Quick death #${client.consecutiveQuickDeaths} for ${client.characterName}');
        _notificationService.createNotification(
          type: NotificationType.clientFailed,
          severity: NotificationSeverity.warning,
          title: 'Client Failed',
          message: '${client.characterName} died quickly '
              '(attempt ${client.retryCount}/${WatchdogService.maxRetries})',
        );
      }
    } else {
      client.consecutiveQuickDeaths = 0;
      client.status = ClientStatus.restarting;
      client.retryCount++;
      logger.i('Normal death for ${client.characterName}, scheduling restart');
    }
  }

  /// Handle restart with exponential backoff. Returns true if state changed.
  Future<bool> handleRestart(TrackedClient client) async {
    if (client.retryCount >= WatchdogService.maxRetries) {
      client.status = ClientStatus.stopped;
      logger.e('Max retries reached for ${client.characterName}');
      await _notificationService.createNotification(
        type: NotificationType.maxRetriesReached,
        severity: NotificationSeverity.error,
        title: 'Max Retries Reached',
        message:
            '${client.characterName} stopped after ${WatchdogService.maxRetries} attempts.',
      );
      return true;
    }

    // Check cooldown: 30s × 2^retryCount, capped at 5 min
    final cooldown = Duration(
      seconds: (30 * (1 << (client.retryCount - 1)))
          .clamp(30, WatchdogService.maxCooldownSeconds),
    );
    if (client.lastDeathAt != null &&
        DateTime.now().difference(client.lastDeathAt!) < cooldown) {
      return false; // Still cooling down
    }

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
      logger.i(
          'Relaunched ${client.characterName} (PID: $pid, retry ${client.retryCount})');
      await _notificationService.createNotification(
        type: NotificationType.clientRelaunched,
        severity: NotificationSeverity.info,
        title: 'Client Relaunched',
        message:
            '${client.characterName} restarted (attempt ${client.retryCount}/${WatchdogService.maxRetries})',
      );
      return true;
    } catch (e) {
      logger.e('Failed to relaunch ${client.characterName}: $e');
      return false;
    }
  }

  /// Handle ban: mark in DB, notify, rotate proxy.
  Future<void> handleBan(TrackedClient client) async {
    // Transition immediately to prevent re-entry on next tick
    client.status = ClientStatus.awaitingAccount;

    await _accountRepository.updateCharacterBanned(client.characterId, true);

    await _notificationService.createNotification(
      type: NotificationType.banDetected,
      severity: NotificationSeverity.error,
      title: 'Ban Detected',
      message: '${client.characterName} banned after '
          '${client.consecutiveQuickDeaths} consecutive quick deaths.',
    );

    if (client.proxySlotId != null) {
      final rotated =
          await _autoRotationService.rotateSlot(client.proxySlotId!);
      if (rotated) {
        final newIp =
            await _proxyRepository.getActiveIpForSlot(client.proxySlotId!);
        if (newIp != null) {
          client.proxyAddress = newIp.ipAddress;
        }
      }
    }
  }
}
