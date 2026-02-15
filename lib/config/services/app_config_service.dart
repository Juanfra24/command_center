import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/repositories/config_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Service for storing app configuration in SQLite
/// This ensures configuration persists locally
class AppConfigService extends GetxService {
  // Config keys
  static const String _keyWebshareApiKey = 'webshare_api_key';
  static const String _keyIsWebshareSetup = 'is_webshare_setup';
  static const String _keyThemeMode = 'theme_mode';

  ConfigRepository? _configRepository;

  // Observable configuration states
  final webshareApiKey = Rxn<String>();
  final isWebshareSetup = false.obs;
  final themeMode = 'system'.obs; // 'light', 'dark', 'system'
  final isLoading = true.obs;

  Future<AppConfigService> init() async {
    try {
      _configRepository = Get.find<DatabaseService>().configRepository;
      await loadConfig();
    } catch (e) {
      logger.e('Error initializing AppConfigService: $e');
    }
    return this;
  }

  /// Load configuration from SQLite
  Future<void> loadConfig() async {
    isLoading.value = true;
    try {
      if (_configRepository == null) return;

      webshareApiKey.value =
          await _configRepository!.getValue(_keyWebshareApiKey);

      final setupValue = await _configRepository!.getValue(_keyIsWebshareSetup);
      isWebshareSetup.value = setupValue == 'true';

      themeMode.value =
          await _configRepository!.getValue(_keyThemeMode) ?? 'system';
    } catch (e) {
      logger.e('Error loading config: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Save Webshare API key
  Future<bool> saveWebshareApiKey(String apiKey) async {
    try {
      if (_configRepository == null) return false;

      await _configRepository!.setValue(_keyWebshareApiKey, apiKey);
      await _configRepository!.setValue(_keyIsWebshareSetup, 'true');

      webshareApiKey.value = apiKey;
      isWebshareSetup.value = true;
      return true;
    } catch (e) {
      logger.e('Error saving Webshare API key: $e');
      return false;
    }
  }

  /// Clear Webshare API key (unlink)
  Future<bool> clearWebshareApiKey() async {
    try {
      if (_configRepository == null) return false;

      await _configRepository!.deleteValue(_keyWebshareApiKey);
      await _configRepository!.setValue(_keyIsWebshareSetup, 'false');

      webshareApiKey.value = null;
      isWebshareSetup.value = false;
      return true;
    } catch (e) {
      logger.e('Error clearing Webshare API key: $e');
      return false;
    }
  }

  /// Save theme mode preference
  Future<bool> saveThemeMode(String mode) async {
    try {
      if (_configRepository == null) return false;

      await _configRepository!.setValue(_keyThemeMode, mode);

      themeMode.value = mode;
      return true;
    } catch (e) {
      logger.e('Error saving theme mode: $e');
      return false;
    }
  }

  /// Get ThemeMode from string
  ThemeMode getThemeMode() {
    switch (themeMode.value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
