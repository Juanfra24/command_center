import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/proxy/scored_ip_result.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';

class ProxyAutoRotationService {
  final ProxyReplacementService _replacementService;
  final WebshareService _webshareService;
  final IpqsService _ipqsService;
  final ProxyRepository _proxyRepository;
  final ProxySyncService _syncService;
  final NotificationService _notificationService;
  final AppConfigService _configService;

  ProxyAutoRotationService({
    required ProxyReplacementService replacementService,
    required WebshareService webshareService,
    required IpqsService ipqsService,
    required ProxyRepository proxyRepository,
    required ProxySyncService syncService,
    required NotificationService notificationService,
    required AppConfigService configService,
  })  : _replacementService = replacementService,
        _webshareService = webshareService,
        _ipqsService = ipqsService,
        _proxyRepository = proxyRepository,
        _syncService = syncService,
        _notificationService = notificationService,
        _configService = configService;

  final _recentlyRotatedSlotIds = <int>{};
  bool _isRunning = false;

  Future<void> processScoreResults(List<ScoredIpResult> results) async {
    if (_isRunning) {
      logger.w('Auto-rotation: already running, skipping');
      return;
    }
    if (!_configService.autoRotationEnabled.value) return;
    if (!_webshareService.isConfigured.value) return;

    _isRunning = true;
    try {
      await _processResults(results);
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _processResults(List<ScoredIpResult> results) async {
    final threshold = _configService.autoRotationThreshold.value;

    // Filter to below-threshold IPs, sorted worst first
    _recentlyRotatedSlotIds.clear();
    final belowThreshold = results
        .where((r) => r.score < threshold && r.slot.id != null)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score)); // worst first

    if (belowThreshold.isEmpty) return;

    logger.i(
        'Auto-rotation: ${belowThreshold.length} IPs below threshold ($threshold)');

    int replacedCount = 0;
    int failedCount = 0;

    for (final scored in belowThreshold) {
      // Check quota
      final planInfo = await _replacementService.fetchPlanInfo();
      if (planInfo == null || planInfo.proxyReplacementsAvailable <= 0) {
        final remaining = belowThreshold.length - replacedCount - failedCount;
        await _notificationService.createNotification(
          type: NotificationType.quotaExhausted,
          severity: NotificationSeverity.error,
          title: 'Replacement Quota Exhausted',
          message:
              '$remaining proxies still below threshold. Webshare quota: '
              '${planInfo?.proxyReplacementsAvailable ?? 0}/'
              '${planInfo?.proxyReplacementsTotal ?? 0} remaining.',
        );
        logger.w('Auto-rotation: quota exhausted, stopping');
        break;
      }

      // Replace
      _recentlyRotatedSlotIds.add(scored.slot.id!);
      final result = await _replacementService.replaceProxyIp(
        scored.ip,
        keepSameCountry: true,
      );

      switch (result) {
        case Success():
          // Sync to get new IP
          try {
            await _syncService.syncWithWebshare();
          } catch (e) {
            logger.w('Auto-rotation: sync after replacement failed: $e');
          }

          // Score the new IP
          final newIp =
              await _proxyRepository.getActiveIpForSlot(scored.slot.id!);
          if (newIp != null) {
            final scoreResult = await _ipqsService.scoreIp(newIp.ipAddress);
            if (scoreResult.success) {
              final newScore = scoreResult.normalizedScore;
              await _proxyRepository.updateIpAddress(
                newIp.copyWith(
                  ipScore: newScore,
                  scoreLevel:
                      ProxyIpAddressEntity.getScoreLevel(newScore),
                  fraudScore: scoreResult.fraudScore,
                  isVpn: scoreResult.isVpn,
                  isProxy: scoreResult.isProxy,
                  isDatacenter: scoreResult.isDatacenter,
                  isTor: scoreResult.isTor,
                  abuseConfidence: scoreResult.recentAbuse ? 100 : 0,
                  lastScoreCheck: DateTime.now(),
                ),
              );

              if (newScore < threshold) {
                await _notificationService.createNotification(
                  type: NotificationType.rotationFailed,
                  severity: NotificationSeverity.warning,
                  title: 'New IP Below Threshold',
                  message:
                      '${scored.slot.slotName}: replacement IP scored '
                      '${newScore.toStringAsFixed(0)}. Manual review recommended.',
                );
                failedCount++;
              } else {
                replacedCount++;
              }
            } else {
              replacedCount++; // Replacement succeeded even if re-score failed
            }
          } else {
            replacedCount++;
          }

        case Failure(:final message):
          logger.w(
              'Auto-rotation: failed to replace ${scored.slot.slotName}: $message');
          failedCount++;
      }

      // Small delay between replacements
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Summary notification
    if (replacedCount > 0 && failedCount == 0) {
      await _notificationService.createNotification(
        type: NotificationType.rotationCompleted,
        severity: NotificationSeverity.info,
        title: 'Auto-Rotation Complete',
        message:
            'Replaced $replacedCount proxies. All new IPs scored above threshold.',
      );
    } else if (replacedCount > 0 && failedCount > 0) {
      await _notificationService.createNotification(
        type: NotificationType.rotationCompleted,
        severity: NotificationSeverity.info,
        title: 'Auto-Rotation Partial',
        message:
            'Replaced $replacedCount proxies. $failedCount still need attention.',
      );
    } else if (failedCount > 0) {
      await _notificationService.createNotification(
        type: NotificationType.rotationFailed,
        severity: NotificationSeverity.warning,
        title: 'Auto-Rotation Failed',
        message:
            'All $failedCount replacement attempts failed. Manual review recommended.',
      );
    }
  }
}
