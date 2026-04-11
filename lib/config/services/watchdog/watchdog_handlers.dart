import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/proxy_url_builder.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:get/get.dart';

/// Handles death classification, restart scheduling, ban processing,
/// PID discovery, and startup recapture.
/// Extracted from WatchdogService to respect the 250-line service ceiling.
class WatchdogHandlers {
  final BotEngine _botEngine;
  final NativeCommandsService _nativeCommandsService;
  final NotificationService _notificationService;
  final ProxyAutoRotationService _autoRotationService;
  final AccountRepository _accountRepository;
  final ProxyRepository _proxyRepository;

  WatchdogHandlers({
    required BotEngine botEngine,
    required NativeCommandsService nativeCommandsService,
    required NotificationService notificationService,
    required ProxyAutoRotationService autoRotationService,
    required AccountRepository accountRepository,
    required ProxyRepository proxyRepository,
  })  : _botEngine = botEngine,
        _nativeCommandsService = nativeCommandsService,
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
      if (client.consecutiveQuickDeaths >=
          WatchdogService.banEscalationThreshold) {
        client.status = ClientStatus.banned;
        logger.e('Ban detected for ${client.characterName} '
            '(${client.consecutiveQuickDeaths} consecutive quick deaths)');
      } else {
        client.status = ClientStatus.failed;
        logger.w(
            'Quick death #${client.consecutiveQuickDeaths} for ${client.characterName}');
        _notificationService.createNotification(
          type: NotificationType.clientFailed,
          severity: NotificationSeverity.warning,
          title: 'Client Failed',
          message: '${client.characterName} died quickly',
        );
      }
    } else {
      client.consecutiveQuickDeaths = 0;
      client.status = ClientStatus.restarting;
      logger.i('Normal death for ${client.characterName}, scheduling restart');
    }
  }

  /// Handle restart with exponential backoff. Returns true if state changed.
  Future<bool> handleRestart(TrackedClient client) async {
    if (_botEngine.isOutdated) {
      client.status = ClientStatus.stopped;
      logger.w(
          'Stopping ${client.characterName} without restart — engine JAR is outdated');
      return true;
    }

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

    // Check cooldown: 30s x 2^retryCount, capped at 5 min
    final cooldown = Duration(
      seconds: (30 * (1 << client.retryCount))
          .clamp(30, WatchdogService.maxCooldownSeconds),
    );
    if (client.lastDeathAt != null &&
        DateTime.now().difference(client.lastDeathAt!) < cooldown) {
      return false; // Still cooling down
    }

    // Increment retryCount before attempt — otherwise failures never count
    // toward the retry limit, causing infinite retry loops.
    client.retryCount++;

    try {
      final result = await _botEngine.launch(
        characterId: client.characterId,
        accountId: client.accountId,
        characterName: client.characterName,
        email: client.email,
        password: client.password,
        proxyUrl: client.proxyUrl,
        config: client.launchConfig,
      );
      client.pid = result.pid;
      client.statusPort = result.statusPort;
      client.status = ClientStatus.running;
      client.launchedAt = DateTime.now();
      logger.i(
          'Relaunched ${client.characterName} (PID: ${result.pid}, attempt ${client.retryCount}/${WatchdogService.maxRetries})');
      await _notificationService.createNotification(
        type: NotificationType.clientRelaunched,
        severity: NotificationSeverity.info,
        title: 'Client Relaunched',
        message:
            '${client.characterName} restarted (attempt ${client.retryCount}/${WatchdogService.maxRetries})',
      );
      return true;
    } catch (e) {
      client.lastDeathAt = DateTime.now();
      client.status = ClientStatus.failed;
      logger.e('Failed to relaunch ${client.characterName}: $e');
      return true;
    }
  }

  /// Match a tracked client to a live process by characterId in command line.
  int? discoverPid(TrackedClient client, List<ProcessClient> liveProcesses) {
    final profileArg = '--cc-profile-dir=';
    final suffixPattern =
        RegExp(r'bot-' + client.characterId.toString() + r'(?:[/\\]|$)');
    for (final process in liveProcesses) {
      if (process.commandLine.contains(profileArg) &&
          suffixPattern.hasMatch(process.commandLine)) {
        return process.processId;
      }
    }
    return null;
  }

  /// Scan running Java processes and recapture any that match known characters.
  Future<void> recaptureRunningClients(
      RxMap<String, TrackedClient> trackedClients) async {
    try {
      final processes = await _nativeCommandsService.listJavaProcesses();
      final accounts = await _accountRepository.getAllAccounts();

      // Build lookup: characterId -> (name, accountId, email, password, proxySlotId)
      final characterLookup = <int,
          ({
        String name,
        int accountId,
        String email,
        String password,
        int? proxySlotId
      })>{};
      for (final account in accounts) {
        for (final character in account.characters) {
          if (character.id != null) {
            characterLookup[character.id!] = (
              name: character.name,
              accountId: account.id!,
              email: account.email,
              password: account.password,
              proxySlotId: account.proxySlotId,
            );
          }
        }
      }

      int recaptured = 0;
      final recapturedCharacterIds = <int>{};
      final profileRegex = RegExp(r'--cc-profile-dir=.*bot-(\d+)');

      for (final process in processes) {
        final profileMatch = profileRegex.firstMatch(process.commandLine);
        if (profileMatch == null) continue;

        final characterId = int.parse(profileMatch.group(1)!);
        final info = characterLookup[characterId];
        if (info == null) {
          logger.w('Orphaned Microbot process (PID: ${process.processId}, '
              'characterId: $characterId) — no DB match, skipping');
          continue;
        }

        // Reconstruct proxyUrl if proxy is assigned
        String? proxyUrl;
        if (info.proxySlotId != null) {
          proxyUrl = await _buildProxyUrl(info.proxySlotId!);
        }

        trackedClients[info.name] = TrackedClient(
          characterName: info.name,
          characterId: characterId,
          accountId: info.accountId,
          proxySlotId: info.proxySlotId,
          email: info.email,
          password: info.password,
          proxyUrl: proxyUrl,
          launchConfig: const LaunchConfig(scriptName: 'Unknown'),
          pid: process.processId,
          status: ClientStatus.running,
          // Sentinel in the past: a recaptured process has already been
          // running before the app restart, so the first post-recapture
          // death must NOT be classified as a quick death (which would
          // falsely start the ban escalation counter).
          launchedAt: DateTime.now()
              .subtract(WatchdogService.quickDeathThreshold * 2),
        );
        recapturedCharacterIds.add(characterId);
        _botEngine.registerRecapturedPid(
          pid: process.processId,
          characterId: characterId,
        );
        recaptured++;
      }

      if (recaptured > 0) {
        trackedClients.refresh();
        logger.i('Recaptured $recaptured running bot clients');
      }

      // Stale profiles are cleaned during stop() — removing from recapture to avoid
      // race where a launching bot's profile is deleted before it appears in ps output.
      // if (engine is MicrobotEngine) {
      //   await engine.cleanStaleProfiles(recapturedCharacterIds);
      // }
    } catch (e) {
      logger.e('Failed to recapture running clients: $e');
    }
  }

  /// Handle ban: mark in DB, notify, rotate proxy.
  Future<void> handleBan(TrackedClient client) async {
    // Transition immediately to prevent re-entry on next tick
    client.status = ClientStatus.awaitingAccount;

    try {
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
          final newProxyUrl = await _buildProxyUrl(client.proxySlotId!);
          if (newProxyUrl != null) {
            client.proxyUrl = newProxyUrl;
          }
        }
      }
    } catch (e) {
      // Don't fall through to `failed` — the restart loop would pick it up
      // and re-ban immediately, creating an infinite ban-restart cycle.
      // The account is already known banned; stop the client definitively.
      logger.e('Failed to handle ban for ${client.characterName}: $e');
      client.status = ClientStatus.stopped;
    }
  }

  /// Build a full socks5:// proxy URL from a slot's credentials and active IP.
  Future<String?> _buildProxyUrl(int proxySlotId) async {
    final slot = await _proxyRepository.getSlotById(proxySlotId);
    if (slot == null || slot.socksPort == null) return null;

    final activeIp = await _proxyRepository.getActiveIpForSlot(proxySlotId);
    if (activeIp == null) return null;

    return ProxyUrlBuilder.buildSocks5Url(
      username: slot.username,
      password: slot.password,
      ipAddress: activeIp.ipAddress,
      socksPort: slot.socksPort!,
    );
  }
}
