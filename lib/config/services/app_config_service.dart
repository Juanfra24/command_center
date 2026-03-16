import 'dart:convert';

import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
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
  static const String _keyImapHost = 'imap_host';
  static const String _keyImapUser = 'imap_user';
  static const String _keyImapPass = 'imap_pass';
  static const String _keyAutoRotationEnabled = 'auto_rotation_enabled';
  static const String _keyAutoRotationThreshold = 'auto_rotation_threshold';
  static const String _keyScriptRegistry = 'script_registry';

  ConfigRepository? _configRepository;

  // Observable configuration states
  final webshareApiKey = Rxn<String>();
  final isWebshareSetup = false.obs;
  final themeMode = 'system'.obs; // 'light', 'dark', 'system'
  bool isLoading = true;
  final autoRotationEnabled = true.obs;
  final autoRotationThreshold = 60.obs;
  final scriptRegistry = <String>['Tutorial Journey'].obs;

  Future<AppConfigService> init() async {
    try {
      _configRepository = Get.find<DatabaseService>().configRepository;
      await _seedDefaults();
      await loadConfig();
    } catch (e) {
      logger.e('Error initializing AppConfigService: $e');
    }
    return this;
  }

  /// Seed default IMAP host if not already set (credentials must be configured via UI)
  Future<void> _seedDefaults() async {
    if (_configRepository == null) return;
    final existing = await _configRepository!.getValue(_keyImapHost);
    if (existing == null) {
      await _configRepository!.setValue(_keyImapHost, 'mail.privateemail.com');
    }
  }

  /// Load configuration from SQLite
  Future<void> loadConfig() async {
    isLoading = true;
    try {
      if (_configRepository == null) return;

      webshareApiKey.value =
          await _configRepository!.getValue(_keyWebshareApiKey);

      final setupValue = await _configRepository!.getValue(_keyIsWebshareSetup);
      isWebshareSetup.value = setupValue == 'true';

      themeMode.value =
          await _configRepository!.getValue(_keyThemeMode) ?? 'system';

      final rotationEnabled =
          await _configRepository!.getValue(_keyAutoRotationEnabled);
      autoRotationEnabled.value = rotationEnabled != 'false'; // default true

      final threshold =
          await _configRepository!.getValue(_keyAutoRotationThreshold);
      autoRotationThreshold.value = int.tryParse(threshold ?? '') ?? 60;

      final registryJson =
          await _configRepository!.getValue(_keyScriptRegistry);
      if (registryJson != null) {
        try {
          final decoded = jsonDecode(registryJson) as List;
          scriptRegistry.value = decoded.cast<String>();
        } catch (e) {
          logger.e('Error parsing script registry: $e');
        }
      }
    } catch (e) {
      logger.e('Error loading config: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Save Webshare API key
  Future<Result<void>> saveWebshareApiKey(String apiKey) async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }

      await _configRepository!.setValue(_keyWebshareApiKey, apiKey);
      await _configRepository!.setValue(_keyIsWebshareSetup, 'true');

      webshareApiKey.value = apiKey;
      isWebshareSetup.value = true;
      return Result.success(null);
    } catch (e) {
      logger.e('Error saving Webshare API key: $e');
      return Result.failure('Failed to save Webshare API key: $e', e);
    }
  }

  /// Clear Webshare API key (unlink)
  Future<Result<void>> clearWebshareApiKey() async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }

      await _configRepository!.deleteValue(_keyWebshareApiKey);
      await _configRepository!.setValue(_keyIsWebshareSetup, 'false');

      webshareApiKey.value = null;
      isWebshareSetup.value = false;
      return Result.success(null);
    } catch (e) {
      logger.e('Error clearing Webshare API key: $e');
      return Result.failure('Failed to clear Webshare API key: $e', e);
    }
  }

  /// Save theme mode preference
  Future<Result<void>> saveThemeMode(String mode) async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }

      await _configRepository!.setValue(_keyThemeMode, mode);

      themeMode.value = mode;
      return Result.success(null);
    } catch (e) {
      logger.e('Error saving theme mode: $e');
      return Result.failure('Failed to save theme mode: $e', e);
    }
  }

  /// Get IMAP host
  Future<String?> getImapHost() async {
    return _configRepository?.getValue(_keyImapHost);
  }

  /// Get IMAP user
  Future<String?> getImapUser() async {
    return _configRepository?.getValue(_keyImapUser);
  }

  /// Get IMAP password
  Future<String?> getImapPass() async {
    return _configRepository?.getValue(_keyImapPass);
  }

  /// Save auto-rotation enabled preference
  Future<Result<void>> saveAutoRotationEnabled(bool enabled) async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }
      await _configRepository!
          .setValue(_keyAutoRotationEnabled, enabled.toString());
      autoRotationEnabled.value = enabled;
      return Result.success(null);
    } catch (e) {
      logger.e('Error saving auto-rotation enabled: $e');
      return Result.failure('Failed to save auto-rotation setting: $e', e);
    }
  }

  /// Save auto-rotation threshold preference
  Future<Result<void>> saveAutoRotationThreshold(int threshold) async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }
      await _configRepository!
          .setValue(_keyAutoRotationThreshold, threshold.toString());
      autoRotationThreshold.value = threshold;
      return Result.success(null);
    } catch (e) {
      logger.e('Error saving auto-rotation threshold: $e');
      return Result.failure('Failed to save auto-rotation threshold: $e', e);
    }
  }

  /// Add a script name to the registry
  Future<Result<void>> addScript(String scriptName) async {
    if (_configRepository == null) {
      return Result.failure('Config repository not initialized');
    }
    if (scriptRegistry.contains(scriptName)) {
      return Result.failure('Script already exists');
    }
    try {
      scriptRegistry.add(scriptName);
      await _configRepository!
          .setValue(_keyScriptRegistry, jsonEncode(scriptRegistry));
      return Result.success(null);
    } catch (e) {
      scriptRegistry.remove(scriptName);
      logger.e('Error saving script registry: $e');
      return Result.failure('Failed to save script registry: $e', e);
    }
  }

  /// Remove a script name from the registry
  Future<Result<void>> removeScript(String scriptName) async {
    if (_configRepository == null) {
      return Result.failure('Config repository not initialized');
    }
    if (!scriptRegistry.contains(scriptName)) {
      return Result.failure('Script not found');
    }
    try {
      scriptRegistry.remove(scriptName);
      await _configRepository!
          .setValue(_keyScriptRegistry, jsonEncode(scriptRegistry));
      return Result.success(null);
    } catch (e) {
      scriptRegistry.add(scriptName);
      logger.e('Error saving script registry: $e');
      return Result.failure('Failed to save script registry: $e', e);
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
