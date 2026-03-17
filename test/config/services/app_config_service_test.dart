import 'package:fluent_ui/fluent_ui.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/resource/result.dart';

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
      expect(service.isLoading, isTrue);
    });
  });

  // Test using a real in-memory database for full integration
  group('AppConfigService - with real ConfigRepository', () {
    setUp(() async {
      // An in-memory database could be wired up here for full integration
      // testing, but the current tests verify behaviour when the repository
      // is *not* initialised, so we intentionally leave it disconnected.
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

  group('AppConfigService - GitHub PAT', () {
    test('getGithubPat returns null when repo not initialized', () async {
      final result = await service.getGithubPat();
      expect(result, isNull);
    });

    test('saveGithubPat is no-op when repo not initialized', () async {
      await service.saveGithubPat('ghp_test123');
      final result = await service.getGithubPat();
      expect(result, isNull);
    });
  });
}
