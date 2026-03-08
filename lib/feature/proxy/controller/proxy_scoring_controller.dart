import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';

/// Handles IP quality scoring via IPQualityScore API.
class ProxyScoringController extends GetxController {
  final ProxyRepository _proxyRepository;
  final IpqsService _ipqsService;
  final ProxyController _proxyController;

  var isScoring = false.obs;

  ProxyScoringController(
      this._proxyRepository, this._ipqsService, this._proxyController);

  /// Score a single IP address using IPQualityScore
  Future<bool> scoreIpWithIpqs(ProxyIpAddressEntity ip) async {
    if (!_ipqsService.isConfigured.value) {
      logger.w('IPQS not configured');
      return false;
    }

    isScoring.value = true;
    try {
      final result = await _ipqsService.scoreIp(ip.ipAddress);

      if (result.success) {
        // Use the normalized score (100 = safest, 0 = riskiest)
        final newScore = result.normalizedScore;

        await _proxyRepository.updateIpAddress(
          ip.copyWith(
            ipScore: newScore,
            fraudScore: result.fraudScore,
            isVpn: result.isVpn,
            isProxy: result.isProxy,
            isDatacenter: result.isDatacenter,
            isTor: result.isTor,
            abuseConfidence: result.recentAbuse ? 100 : 0,
            lastScoreCheck: DateTime.now(),
          ),
        );

        await _proxyController.loadIpAddresses();

        // Refresh selected slot history if applicable
        if (_proxyController.selectedSlot.value != null &&
            _proxyController.selectedSlot.value!.id != null) {
          _proxyController.selectedSlotIpHistory.value =
              _proxyController
                  .getIpHistoryForSlot(_proxyController.selectedSlot.value!.id!);
        }

        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error scoring IP with IPQS: $e');
      return false;
    } finally {
      isScoring.value = false;
    }
  }

  /// Score all current IPs for all slots
  Future<int> scoreAllCurrentIps() async {
    if (!_ipqsService.isConfigured.value) {
      logger.w('IPQS not configured');
      return 0;
    }

    isScoring.value = true;
    int successCount = 0;

    try {
      for (final slot in _proxyController.proxySlots) {
        final currentIp = _proxyController.getCurrentIpForSlot(slot);
        if (currentIp != null) {
          final success = await scoreIpWithIpqs(currentIp);
          if (success) successCount++;
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      await _proxyController.loadIpAddresses();
      return successCount;
    } catch (e) {
      logger.e('Error scoring all IPs: $e');
      return successCount;
    } finally {
      isScoring.value = false;
    }
  }
}
