import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';

/// Handles proxy IP replacement and rotation UI state.
/// Delegates actual API calls to [ProxyReplacementService].
class ProxyReplacementController extends GetxController {
  final List<Worker> _workers = [];

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
      _replacementService = Get.find<ProxyReplacementService>();

      final webshareService = Get.find<WebshareService>();
      if (webshareService.isConfigured.value) {
        fetchPlanInfo();
      }

      _workers.add(ever(webshareService.isConfigured, (configured) {
        if (configured) fetchPlanInfo();
      }));
    } catch (e) {
      logger.w('Replacement service not available yet: $e');
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
  Future<Result<void>> replaceProxyIp(
    ProxySlotEntity slot, {
    bool keepSameCountry = false,
  }) async {
    if (_replacementService == null ||
        !_proxyController.isWebshareConfigured.value) {
      return Result.failure(
          'Webshare not configured. Please add your API key in Settings.');
    }

    final currentIp = _proxyController.getCurrentIpForSlot(slot);
    if (currentIp == null) {
      return Result.failure('No active IP found for this slot');
    }

    isReplacing.value = true;
    _proxyController.lastSyncError.value = null;

    try {
      final result = await _replacementService!.replaceProxyIp(
        currentIp,
        keepSameCountry: keepSameCountry,
      );

      switch (result) {
        case Success():
          // Sync to get the updated proxy data
          try {
            await _proxyController.syncWithWebshare();
          } catch (e) {
            logger.w('Sync after replacement failed: $e');
            // Replacement succeeded but sync failed — still a partial success
            await fetchPlanInfo();
            return Result.success(null);
          }
          // Refresh plan info to update remaining replacements
          await fetchPlanInfo();
          return Result.success(null);
        case Failure(:final message):
          _proxyController.lastSyncError.value = message;
          return Result.failure(message);
      }
    } catch (e) {
      logger.e('Error replacing proxy: $e');
      final errorMsg = 'Failed to replace proxy: ${e.toString()}';
      _proxyController.lastSyncError.value = errorMsg;
      return Result.failure(errorMsg, e);
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

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
