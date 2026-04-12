import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/repositories/config_repository.dart';
import 'package:get/get.dart';

class ImapConfigService extends GetxService {
  static const String _keyHost = 'imap_host';
  static const String _keyUser = 'imap_user';
  static const String _keyPass = 'imap_pass';
  static const String _defaultHost = 'imap.gmail.com';

  ConfigRepository? _configRepository;

  final isConfigured = false.obs;
  String? cachedHost;

  Future<ImapConfigService> init() async {
    try {
      _configRepository = Get.find<DatabaseService>().configRepository;
      await _seedDefaults();
      await _loadConfig();
    } catch (e) {
      logger.e('Error initializing ImapConfigService: $e');
    }
    return this;
  }

  Future<void> _seedDefaults() async {
    if (_configRepository == null) return;
    final existing = await _configRepository!.getValue(_keyHost);
    if (existing == null) {
      await _configRepository!.setValue(_keyHost, _defaultHost);
    }
  }

  Future<void> _loadConfig() async {
    if (_configRepository == null) return;
    cachedHost = await _configRepository!.getValue(_keyHost);
    final user = await _configRepository!.getValue(_keyUser);
    final pass = await _configRepository!.getValue(_keyPass);
    isConfigured.value = user != null && pass != null;
  }

  Future<Result<void>> saveConfig({
    required String host,
    required String user,
    required String pass,
  }) async {
    if (host.isEmpty || user.isEmpty || pass.isEmpty) {
      return Result.failure('All fields are required');
    }
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }
      await _configRepository!.setValue(_keyHost, host);
      await _configRepository!.setValue(_keyUser, user);
      await _configRepository!.setValue(_keyPass, pass);
      cachedHost = host;
      isConfigured.value = true;
      return Result.success(null);
    } catch (e) {
      logger.e('Error saving IMAP config: $e');
      return Result.failure('Failed to save IMAP config.');
    }
  }

  Future<Result<void>> clearConfig() async {
    try {
      if (_configRepository == null) {
        return Result.failure('Config repository not initialized');
      }
      await _configRepository!.deleteValue(_keyUser);
      await _configRepository!.deleteValue(_keyPass);
      await _configRepository!.setValue(_keyHost, _defaultHost);
      cachedHost = _defaultHost;
      isConfigured.value = false;
      return Result.success(null);
    } catch (e) {
      logger.e('Error clearing IMAP config: $e');
      return Result.failure('Failed to clear IMAP config.');
    }
  }

  Future<String?> getHost() async => _configRepository?.getValue(_keyHost);
  Future<String?> getUser() async => _configRepository?.getValue(_keyUser);
  Future<String?> getPass() async => _configRepository?.getValue(_keyPass);
}
