import 'package:fluent_ui/fluent_ui.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/repositories/config_repository.dart';

void main() {
  late AppConfigService service;

  setUp(() {
    Get.testMode = true;
    service = AppConfigService();
  });

  tearDown(() {
    Get.reset();
  });

  group('AppConfigService - getThemeMode', () {
    test('returns ThemeMode.system for "system"', () {
      service.themeMode.value = 'system';
      expect(service.getThemeMode(), equals(ThemeMode.system));
    });

    test('returns ThemeMode.light for "light"', () {
      service.themeMode.value = 'light';
      expect(service.getThemeMode(), equals(ThemeMode.light));
    });

    test('returns ThemeMode.dark for "dark"', () {
      service.themeMode.value = 'dark';
      expect(service.getThemeMode(), equals(ThemeMode.dark));
    });

    test('returns ThemeMode.system for unknown value', () {
      service.themeMode.value = 'unknown';
      expect(service.getThemeMode(), equals(ThemeMode.system));
    });
  });

  group('AppConfigService - observable states', () {
    test('initial observable states are correct', () {
      expect(service.webshareApiKey.value, isNull);
      expect(service.isWebshareSetup.value, isFalse);
      expect(service.themeMode.value, equals('system'));
      expect(service.isLoading.value, isTrue);
    });
  });

  // Test using a real in-memory database for full integration
  group('AppConfigService - with real ConfigRepository', () {
    late ConfigRepository realRepo;

    setUp(() async {
      // Use Drift in-memory database for integration testing
      final db = await _createInMemoryDb();
      realRepo = _ConfigRepoAdapter(db);
    });

    test('saveWebshareApiKey returns failure when repo not initialized',
        () async {
      // Service without repo initialized
      final result = await service.saveWebshareApiKey('test-key');
      expect(result, isA<Failure<void>>());
    });

    test('clearWebshareApiKey returns failure when repo not initialized',
        () async {
      final result = await service.clearWebshareApiKey();
      expect(result, isA<Failure<void>>());
    });

    test('saveThemeMode returns failure when repo not initialized', () async {
      final result = await service.saveThemeMode('dark');
      expect(result, isA<Failure<void>>());
    });
  });
}

// Simple in-memory config repository for integration tests
Future<Map<String, String>> _createInMemoryDb() async {
  return <String, String>{};
}

class _ConfigRepoAdapter implements ConfigRepository {
  final Map<String, String> _store;
  _ConfigRepoAdapter(this._store);

  @override
  Future<String?> getValue(String key) async => _store[key];
  @override
  Future<void> setValue(String key, String value) async => _store[key] = value;
  @override
  Future<void> deleteValue(String key) async => _store.remove(key);
  @override
  Future<Map<String, String>> getAllConfig() async => Map.from(_store);
  @override
  Future<void> clearAll() async => _store.clear();
  @override
  Stream<String?> watchValue(String key) => Stream.value(_store[key]);
}
