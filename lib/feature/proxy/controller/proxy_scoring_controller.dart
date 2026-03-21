import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/proxy/scored_ip_result.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';

/// Handles IP quality scoring via IPQualityScore API.
/// Also exposes score-related statistics and filtering state.
class ProxyScoringController extends GetxController {
  final List<Worker> _workers = [];

  final ProxyRepository _proxyRepository;
  final IpqsService _ipqsService;
  final ProxyController _proxyController;

  ProxyAutoRotationService? _autoRotationService;

  var isScoring = false.obs;
  bool _scoringLock = false;

  // Integration state
  var isIpqsConfigured = false.obs;

  // Filter state
  var sortByScore = false.obs;

  ProxyScoringController(
      this._proxyRepository, this._ipqsService, this._proxyController);

  @override
  void onInit() {
    super.onInit();
    _initIpqs();
    try {
      _autoRotationService = Get.find<ProxyAutoRotationService>();
    } catch (_) {
      // Optional — auto-rotation not available
    }
  }

  @override
  void onReady() {
    super.onReady();
    _triggerStartupScoring();
  }

  void _triggerStartupScoring() {
    try {
      final webshare = Get.find<WebshareService>();
      final ipqs = Get.find<IpqsService>();
      if (!webshare.isConfigured.value || !ipqs.isConfigured.value) return;

      // Fire and forget — score stale IPs in background
      Future(() async {
        try {
          await scoreAllCurrentIps(skipStale: true);
        } catch (e) {
          logger.e('Startup scoring failed: $e');
        }
      });
    } catch (_) {
      // Services not available, skip
    }
  }

  void _initIpqs() {
    isIpqsConfigured.value = _ipqsService.isConfigured.value;

    _workers.add(ever(_ipqsService.isConfigured, (configured) {
      isIpqsConfigured.value = configured;
    }));

    // Recalculate stats whenever IP addresses change
    _workers
        .add(ever(_proxyController.ipAddresses, (_) => _recalculateStats()));
  }

  // --- Cached score statistics ---
  final hasScoredIps = false.obs;
  final averageFraudScore = 0.0.obs;
  final lowScoreCount = 0.obs;

  /// Exposed for testing only — call to force recalculation of cached stats.
  // ignore: invalid_use_of_visible_for_testing_member
  void recalculateStatsForTest() => _recalculateStats();

  void _recalculateStats() {
    final slots = _proxyController.proxySlots;
    int scored = 0;
    double totalScore = 0;
    int lowCount = 0;

    for (final slot in slots) {
      final ip = _proxyController.getCurrentIpForSlot(slot);
      if (ip != null && ip.hasBeenScored) {
        scored++;
        totalScore += ip.fraudScore;
        if (ip.fraudScore > 60) lowCount++;
      }
    }

    hasScoredIps.value = scored > 0;
    averageFraudScore.value = scored > 0 ? totalScore / scored : 0;
    lowScoreCount.value = lowCount;
  }

  /// Get details of high-fraud-score proxies for tooltip display
  List<String> getLowScoreSlotDetails() {
    final details = <String>[];
    for (final slot in _proxyController.proxySlots) {
      final ip = _proxyController.getCurrentIpForSlot(slot);
      if (ip != null && ip.hasBeenScored && ip.fraudScore > 60) {
        details.add(
            '${slot.slotName}: ${ip.ipAddress} (fraud: ${ip.fraudScore.toStringAsFixed(0)})');
      }
    }
    return details;
  }

  // --- Score actions ---

  /// Internal implementation: scores one IP and optionally reloads data.
  /// Does NOT acquire [_scoringLock] — callers must hold it.
  Future<bool> _scoreIpInternal(ProxyIpAddressEntity ip,
      {bool skipReload = false}) async {
    try {
      final result = await _ipqsService.scoreIp(ip.ipAddress);

      if (result.success) {
        // Raw IPQS fraud score (0-100, lower is better)
        final newScore = result.fraudScore;

        await _proxyRepository.updateIpAddress(
          ip.copyWith(
            ipScore: newScore,
            scoreLevel: ProxyIpAddressEntity.getScoreLevel(newScore),
            fraudScore: newScore,
            isVpn: result.isVpn,
            isProxy: result.isProxy,
            isDatacenter: result.isDatacenter,
            isTor: result.isTor,
            recentAbuse: result.recentAbuse,
            isCrawler: result.isCrawler,
            connectionType: result.connectionType,
            isp: result.isp,
            organization: result.organization,
            region: result.region,
            lastScoreCheck: DateTime.now(),
          ),
        );

        if (!skipReload) {
          await _proxyController.loadIpAddresses();

          // Refresh selected slot history if applicable
          if (_proxyController.selectedSlot.value != null &&
              _proxyController.selectedSlot.value!.id != null) {
            _proxyController.selectedSlotIpHistory.value = _proxyController
                .getIpHistoryForSlot(_proxyController.selectedSlot.value!.id!);
          }

          // Trigger auto-rotation for this single IP
          if (_autoRotationService != null) {
            final slot = _proxyController.proxySlots
                .firstWhereOrNull((s) => s.id == ip.slotId);
            if (slot != null) {
              // Use fresh IP entity from reloaded data (not the stale pre-scoring entity)
              final freshIp = _proxyController.getCurrentIpForSlot(slot);
              if (freshIp != null) {
                await _autoRotationService!.processScoreResults([
                  ScoredIpResult(ip: freshIp, slot: slot, score: newScore),
                ]);
                // Reload after auto-rotation may have changed IPs
                await _proxyController.loadIpAddresses();
              }
            }
          }
        }

        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error scoring IP with IPQS: $e');
      return false;
    }
  }

  /// Score a single IP address using IPQualityScore.
  /// When [skipReload] is true, skips reloading IP addresses from DB
  /// (useful during batch scoring to avoid N+1 reloads).
  Future<bool> scoreIpWithIpqs(ProxyIpAddressEntity ip,
      {bool skipReload = false}) async {
    if (!_ipqsService.isConfigured.value) {
      logger.w('IPQS not configured');
      return false;
    }

    if (_scoringLock) return false;
    _scoringLock = true;
    if (!skipReload) isScoring.value = true;
    try {
      return await _scoreIpInternal(ip, skipReload: skipReload);
    } finally {
      _scoringLock = false;
      if (!skipReload) isScoring.value = false;
    }
  }

  /// Score all current IPs for all slots.
  /// When [skipStale] is true, skips IPs scored within the last 6 hours
  /// (useful for startup scoring to avoid redundant API calls).
  Future<int> scoreAllCurrentIps({bool skipStale = false}) async {
    if (!_ipqsService.isConfigured.value) {
      logger.w('IPQS not configured');
      return 0;
    }

    if (_scoringLock) return 0;
    _scoringLock = true;
    isScoring.value = true;
    int successCount = 0;

    try {
      for (final slot in _proxyController.proxySlots) {
        if (isClosed) break;
        final currentIp = _proxyController.getCurrentIpForSlot(slot);
        if (currentIp != null) {
          // Skip IPs scored within the last 6 hours (for startup scoring only)
          if (skipStale &&
              currentIp.lastScoreCheck != null &&
              DateTime.now().difference(currentIp.lastScoreCheck!).inHours <
                  6) {
            continue;
          }

          final success = await _scoreIpInternal(currentIp, skipReload: true);
          if (success) successCount++;
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // Single reload after all scoring is done
      await _proxyController.loadIpAddresses();

      // Refresh selected slot history
      if (_proxyController.selectedSlot.value != null &&
          _proxyController.selectedSlot.value!.id != null) {
        _proxyController.selectedSlotIpHistory.value = _proxyController
            .getIpHistoryForSlot(_proxyController.selectedSlot.value!.id!);
      }

      // Trigger auto-rotation for all scored IPs
      if (_autoRotationService != null) {
        final results = <ScoredIpResult>[];
        for (final slot in _proxyController.proxySlots) {
          final currentIp = _proxyController.getCurrentIpForSlot(slot);
          if (currentIp != null && currentIp.hasBeenScored) {
            results.add(ScoredIpResult(
              ip: currentIp,
              slot: slot,
              score: currentIp.fraudScore,
            ));
          }
        }
        await _autoRotationService!.processScoreResults(results);
        // Reload after auto-rotation may have changed IPs
        await _proxyController.loadIpAddresses();
      }

      return successCount;
    } catch (e) {
      logger.e('Error scoring all IPs: $e');
      return successCount;
    } finally {
      _scoringLock = false;
      isScoring.value = false;
    }
  }

  /// Update IP score directly (manual override)
  Future<void> updateIpScore(ProxyIpAddressEntity ip, double newScore) async {
    try {
      await _proxyRepository.updateIpAddress(
        ip.copyWith(
          ipScore: newScore,
          fraudScore: newScore,
          scoreLevel: ProxyIpAddressEntity.getScoreLevel(newScore),
          lastScoreCheck: DateTime.now(),
        ),
      );
      await _proxyController.loadIpAddresses();
    } catch (e) {
      logger.e('Error updating IP score: $e');
      rethrow;
    }
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
