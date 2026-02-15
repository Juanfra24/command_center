import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command_center/config/services/ipqs_service.dart';
import 'package:command_center/config/services/webshare_service.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';

/// Service to manage app onboarding state and requirements
class OnboardingService extends GetxService {
  static const String _webshareConfiguredKey = 'webshare_configured';
  static const String _ipqsConfiguredKey = 'ipqs_configured';
  static const String _initialSyncCompleteKey = 'initial_sync_complete';

  // Observable states
  final isWebshareConfigured = false.obs;
  final isIpqsConfigured = false.obs;
  final isInitialSyncComplete = false.obs;
  final isStatusSyncComplete = false.obs;
  final isLoading = true.obs;

  // Computed state - is onboarding complete?
  bool get isOnboardingComplete =>
      isWebshareConfigured.value &&
      isIpqsConfigured.value &&
      isInitialSyncComplete.value;

  @override
  void onInit() {
    super.onInit();
    checkOnboardingStatus();
  }

  /// Check the current onboarding status
  Future<void> checkOnboardingStatus() async {
    isLoading.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check Webshare configuration
      try {
        final webshareService = Get.find<WebshareService>();
        isWebshareConfigured.value = webshareService.isConfigured.value;

        // Listen for changes in webshare configuration
        ever(webshareService.isConfigured, (configured) {
          isWebshareConfigured.value = configured;
          if (configured) {
            _saveWebshareConfigured();
          }
        });
      } catch (_) {
        isWebshareConfigured.value =
            prefs.getBool(_webshareConfiguredKey) ?? false;
      }

      // Check IPQS configuration
      try {
        final ipqsService = Get.find<IpqsService>();
        isIpqsConfigured.value = ipqsService.isConfigured.value;

        // Listen for changes in IPQS configuration
        ever(ipqsService.isConfigured, (configured) {
          isIpqsConfigured.value = configured;
          if (configured) {
            _saveIpqsConfigured();
          }
        });
      } catch (_) {
        isIpqsConfigured.value = prefs.getBool(_ipqsConfiguredKey) ?? false;
      }

      // Check initial sync status
      isInitialSyncComplete.value =
          prefs.getBool(_initialSyncCompleteKey) ?? false;

      // Check status sync
      try {
        final statusController = Get.find<StatusController>();
        isStatusSyncComplete.value = !statusController.isLoading.value;

        ever(statusController.isLoading, (loading) {
          if (!loading) {
            isStatusSyncComplete.value = true;
          }
        });
      } catch (_) {
        isStatusSyncComplete.value = false;
      }
    } catch (e) {
      // Default to not configured on error
      isWebshareConfigured.value = false;
      isIpqsConfigured.value = false;
      isInitialSyncComplete.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveWebshareConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_webshareConfiguredKey, true);
  }

  Future<void> _saveIpqsConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ipqsConfiguredKey, true);
  }

  /// Mark initial sync as complete
  Future<void> markInitialSyncComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialSyncCompleteKey, true);
    isInitialSyncComplete.value = true;
  }

  /// Perform initial sync after webshare is configured
  Future<bool> performInitialSync() async {
    if (!isWebshareConfigured.value) {
      return false;
    }

    try {
      // Sync proxies
      final proxyController = Get.find<ProxyController>();
      await proxyController.syncWithWebshare();

      // Check if sync was successful
      if (proxyController.lastSyncError.value == null &&
          proxyController.proxySlots.isNotEmpty) {
        await markInitialSyncComplete();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get available proxy slots count for character creation
  int get availableProxySlots {
    try {
      final proxyController = Get.find<ProxyController>();
      final statusController = Get.find<StatusController>();

      // Total slots - assigned characters
      final totalSlots = proxyController.proxySlots.length;
      final assignedCount = statusController.accountList.length;

      return totalSlots - assignedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Check if we can create a new character
  bool get canCreateCharacter =>
      isOnboardingComplete && availableProxySlots > 0;

  /// Reset onboarding (for debugging or re-setup)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_webshareConfiguredKey);
    await prefs.remove(_initialSyncCompleteKey);
    await prefs.remove('webshare_api_key');

    isWebshareConfigured.value = false;
    isInitialSyncComplete.value = false;
    isStatusSyncComplete.value = false;
  }
}
