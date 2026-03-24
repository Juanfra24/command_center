import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';

/// Service to manage app onboarding state and requirements
class OnboardingService extends GetxService {
  static const String _webshareConfiguredKey = 'webshare_configured';
  static const String _ipqsConfiguredKey = 'ipqs_configured';
  static const String _initialSyncCompleteKey = 'initial_sync_complete';
  static const String _imapConfiguredKey = 'imap_configured';

  // Observable states
  final isWebshareConfigured = false.obs;
  final isIpqsConfigured = false.obs;
  final isImapConfigured = false.obs;
  final isInitialSyncComplete = false.obs;
  final isLoading = true.obs;

  // Workers list to prevent duplicate ever() listeners
  final List<Worker> _workers = [];

  // Computed state - is onboarding complete?
  bool get isOnboardingComplete =>
      isWebshareConfigured.value &&
      isIpqsConfigured.value &&
      isImapConfigured.value &&
      isInitialSyncComplete.value;

  @override
  void onInit() {
    super.onInit();
    checkOnboardingStatus();
  }

  /// Check the current onboarding status
  Future<void> checkOnboardingStatus() async {
    // Cancel previous listeners to prevent duplicates
    for (final w in _workers) {
      w.dispose();
    }
    _workers.clear();

    isLoading.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check Webshare configuration
      try {
        final webshareService = Get.find<WebshareService>();
        isWebshareConfigured.value = webshareService.isConfigured.value;

        // Listen for changes in webshare configuration
        _workers.add(ever(webshareService.isConfigured, (configured) {
          isWebshareConfigured.value = configured;
          if (configured) {
            _saveWebshareConfigured();
          }
        }));
      } catch (_) {
        isWebshareConfigured.value =
            prefs.getBool(_webshareConfiguredKey) ?? false;
      }

      // Check IPQS configuration
      try {
        final ipqsService = Get.find<IpqsService>();
        isIpqsConfigured.value = ipqsService.isConfigured.value;

        // Listen for changes in IPQS configuration
        _workers.add(ever(ipqsService.isConfigured, (configured) {
          isIpqsConfigured.value = configured;
          if (configured) {
            _saveIpqsConfigured();
          }
        }));
      } catch (_) {
        isIpqsConfigured.value = prefs.getBool(_ipqsConfiguredKey) ?? false;
      }

      // Check IMAP configuration
      try {
        final imapService = Get.find<ImapConfigService>();
        isImapConfigured.value = imapService.isConfigured.value;

        _workers.add(ever(imapService.isConfigured, (configured) {
          isImapConfigured.value = configured;
          if (configured) {
            _saveImapConfigured();
          }
        }));
      } catch (_) {
        isImapConfigured.value = prefs.getBool(_imapConfiguredKey) ?? false;
      }

      // Check initial sync status
      isInitialSyncComplete.value =
          prefs.getBool(_initialSyncCompleteKey) ?? false;
    } catch (e) {
      // Default to not configured on error
      isWebshareConfigured.value = false;
      isIpqsConfigured.value = false;
      isImapConfigured.value = false;
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

  Future<void> _saveImapConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_imapConfiguredKey, true);
  }

  /// Mark initial sync as complete
  Future<void> markInitialSyncComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialSyncCompleteKey, true);
    isInitialSyncComplete.value = true;
  }

  /// Check if we can create a new character (onboarding complete guard only;
  /// slot availability is checked separately in the dialog).
  bool get canCreateCharacter => isOnboardingComplete;

  /// Reset onboarding (for debugging or re-setup)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_webshareConfiguredKey);
    await prefs.remove(_ipqsConfiguredKey);
    await prefs.remove(_initialSyncCompleteKey);
    await prefs.remove(_imapConfiguredKey);

    // Clear the actual API keys from their source-of-truth storage
    // Webshare key lives in SQLite via AppConfigService
    try {
      final appConfig = Get.find<AppConfigService>();
      await appConfig.clearWebshareApiKey();
    } catch (_) {
      // AppConfigService may not be registered in test/debug scenarios
    }

    // IPQS key lives in SQLite via IpqsService
    try {
      final ipqs = Get.find<IpqsService>();
      await ipqs.clearApiKey();
    } catch (_) {
      // IpqsService may not be registered in test/debug scenarios
    }

    // IMAP config lives in SQLite via ImapConfigService
    try {
      final imapService = Get.find<ImapConfigService>();
      await imapService.clearConfig();
    } catch (_) {
      // ImapConfigService may not be registered in test/debug scenarios
    }

    isWebshareConfigured.value = false;
    isIpqsConfigured.value = false;
    isImapConfigured.value = false;
    isInitialSyncComplete.value = false;
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
