import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/resource/result.dart';

void main() {
  late WebshareService service;

  setUp(() {
    Get.testMode = true;
    service = WebshareService();
  });

  tearDown(() {
    Get.reset();
  });

  group('WebshareService - testAndConnect', () {
    test('returns failure for empty API key', () async {
      final result = await service.testAndConnect('');
      expect(result, isA<Failure<void>>());
      expect(
        (result as Failure).message,
        equals('API key cannot be empty'),
      );
    });
  });

  group('WebshareService - observable states', () {
    test('initial states are correct', () {
      expect(service.isConfigured.value, isFalse);
      expect(service.isLoading.value, isFalse);
      expect(service.isSyncing.value, isFalse);
      expect(service.lastSyncTime.value, isNull);
      expect(service.lastError.value, isNull);
    });
  });

  group('WebshareService - saveApiKey without AppConfigService', () {
    test('saveApiKey fails gracefully when AppConfigService not registered',
        () async {
      // No AppConfigService is registered in GetX, so Get.find will throw.
      // The service should catch this and return a failure.
      final result = await service.saveApiKey('test-key');
      expect(result, isA<Failure<void>>());
    });

    test('clearApiKey fails gracefully when AppConfigService not registered',
        () async {
      final result = await service.clearApiKey();
      expect(result, isA<Failure<void>>());
    });
  });

  group('WebshareService - saveApiKey with real AppConfigService', () {
    late AppConfigService configService;

    setUp(() {
      // Use a real AppConfigService (not mocked) to avoid GetX lifecycle issues.
      // Its _configRepository will be null, so operations will return failures.
      configService = Get.put(AppConfigService());
    });

    test('saveApiKey returns failure when config repo not initialized',
        () async {
      final result = await service.saveApiKey('test-key');
      // The config service's _configRepository is null, so saveWebshareApiKey
      // returns Failure('Config repository not initialized')
      expect(result, isA<Failure<void>>());
    });

    test('clearApiKey returns failure when config repo not initialized',
        () async {
      final result = await service.clearApiKey();
      expect(result, isA<Failure<void>>());
    });
  });

  group('WebshareService - testConnection', () {
    test('delegates to testAndConnect with empty key', () async {
      // _apiKey is null, so testConnection without arg uses empty string
      final result = await service.testConnection();
      expect(result, isA<Failure<void>>());
      expect(
        (result as Failure).message,
        equals('API key cannot be empty'),
      );
    });

    test('delegates to testAndConnect with provided key', () async {
      final result = await service.testConnection('');
      expect(result, isA<Failure<void>>());
    });
  });
}
