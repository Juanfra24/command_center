import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';

/// Handles proxy IP rotation and replacement via Webshare API.
class ProxyReplacementService {
  final WebshareService _webshareService;

  ProxyReplacementService(this._webshareService);

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
