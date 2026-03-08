import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';

/// Handles proxy IP replacement and rotation UI state.
/// Delegates actual API calls to [ProxyReplacementService].
class ProxyReplacementController extends GetxController {
  final ProxyController _proxyController;
  ProxyReplacementService? _replacementService;

  // Observable states
  var isReplacing = false.obs;

  // Subscription plan info
  var replacementsAvailable = Rxn<int>();
  var replacementsTotal = Rxn<int>();
  var replacementsUsed = Rxn<int>();

  ProxyReplacementController(this._proxyController);

  @override
  void onInit() {
    super.onInit();
    _initReplacementService();
  }

  void _initReplacementService() {
    try {
      final webshareService = Get.find<WebshareService>();
      _replacementService = ProxyReplacementService(webshareService);

      // Fetch plan info if webshare is configured
      if (webshareService.isConfigured.value) {
        fetchPlanInfo();
      }

      ever(webshareService.isConfigured, (configured) {
        if (configured) fetchPlanInfo();
      });
    } catch (e) {
      logger.w('WebshareService not initialized yet for replacement: $e');
    }
  }

  /// Request IP rotation via Webshare API (legacy v2)
  Future<bool> rotateSlotIp(ProxySlotEntity slot) async {
    if (_replacementService == null ||
        !_proxyController.isWebshareConfigured.value ||
        slot.webshareId == null) {
      _proxyController.lastSyncError.value =
          'Cannot rotate IP: Webshare not configured or slot not linked';
      return false;
    }

    try {
      final success = await _replacementService!.rotateSlotIp(slot);
      if (success) {
        await _proxyController.syncWithWebshare();
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error rotating IP: $e');
      _proxyController.lastSyncError.value =
          'Failed to rotate IP: ${e.toString()}';
      return false;
    }
  }

  /// Replace a proxy IP via the Webshare v3 Proxy Replacement API.
  Future<({bool success, String? error})> replaceProxyIp(
    ProxySlotEntity slot, {
    bool keepSameCountry = false,
  }) async {
    if (_replacementService == null ||
        !_proxyController.isWebshareConfigured.value) {
      return (
        success: false,
        error: 'Webshare not configured. Please add your API key in Settings.'
      );
    }

    final currentIp = _proxyController.getCurrentIpForSlot(slot);
    if (currentIp == null) {
      return (success: false, error: 'No active IP found for this slot');
    }

    isReplacing.value = true;
    _proxyController.lastSyncError.value = null;

    try {
      final result = await _replacementService!.replaceProxyIp(
        currentIp,
        keepSameCountry: keepSameCountry,
      );

      if (result.success) {
        // Sync to get the updated proxy data
        await _proxyController.syncWithWebshare();
        // Refresh plan info to update remaining replacements
        await fetchPlanInfo();
        return (success: true, error: null);
      } else {
        _proxyController.lastSyncError.value = result.error;
        return result;
      }
    } catch (e) {
      logger.e('Error replacing proxy: $e');
      final errorMsg = 'Failed to replace proxy: ${e.toString()}';
      _proxyController.lastSyncError.value = errorMsg;
      return (success: false, error: errorMsg);
    } finally {
      isReplacing.value = false;
    }
  }

  /// Fetch plan info from Webshare to get replacement quotas
  Future<void> fetchPlanInfo() async {
    if (_replacementService == null) return;

    try {
      final plan = await _replacementService!.fetchPlanInfo();
      if (plan != null) {
        replacementsAvailable.value = plan.proxyReplacementsAvailable;
        replacementsTotal.value = plan.proxyReplacementsTotal;
        replacementsUsed.value = plan.proxyReplacementsUsed;
        logger.i(
            'Plan info: ${plan.proxyReplacementsAvailable}/${plan.proxyReplacementsTotal} replacements available');
      }
    } catch (e) {
      logger.w('Error fetching plan info: $e');
    }
  }
}
