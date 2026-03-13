import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';

/// Handles proxy IP rotation and replacement via Webshare API.
class ProxyReplacementService {
  final WebshareService _webshareService;

  ProxyReplacementService(this._webshareService);

  /// Request IP rotation via Webshare API (legacy v2)
  Future<bool> rotateSlotIp(ProxySlotEntity slot) async {
    if (slot.webshareId == null) {
      return false;
    }

    try {
      final newProxy = await _webshareService.replaceProxy(slot.webshareId!);
      return newProxy != null;
    } catch (e) {
      logger.e('Error rotating IP: $e');
      rethrow;
    }
  }

  /// Replace a proxy IP via the Webshare v3 Proxy Replacement API.
  Future<Result<void>> replaceProxyIp(
    ProxyIpAddressEntity currentIp, {
    bool keepSameCountry = false,
  }) async {
    final countryCode = keepSameCountry ? currentIp.countryCode : null;

    return _webshareService.replaceProxyIp(
      currentIp.ipAddress,
      countryCode: countryCode,
    );
  }

  /// Fetch the active subscription plan to get replacement quotas
  Future<WebsharePlanInfo?> fetchPlanInfo() async {
    try {
      return await _webshareService.getActivePlan();
    } catch (e) {
      logger.w('Error fetching plan info: $e');
      return null;
    }
  }
}
