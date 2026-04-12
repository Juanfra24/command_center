import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImapConfigService - without DB (null repository)', () {
    late ImapConfigService service;

    setUp(() async {
      Get.reset();
      service = await ImapConfigService().init();
    });

    tearDown(() => Get.reset());

    test('init without DatabaseService sets isConfigured false', () {
      expect(service.isConfigured.value, isFalse);
      expect(service.cachedHost, isNull);
    });

    test('saveConfig fails when repository not initialized', () async {
      final result = await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );
      expect(result, isA<Failure>());
      expect(service.isConfigured.value, isFalse);
    });

    test('clearConfig fails when repository not initialized', () async {
      final result = await service.clearConfig();
      expect(result, isA<Failure>());
    });

    test('saveConfig rejects empty fields', () async {
      final result = await service.saveConfig(host: '', user: 'u', pass: 'p');
      expect(result, isA<Failure>());
    });
  });

  group('ImapConfigService - with in-memory DB', () {
    late AppDatabase db;
    late ImapConfigService service;

    setUp(() async {
      Get.reset();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      Get.put<DatabaseService>(
        DatabaseService.forTesting(db),
        permanent: true,
      );
      service = await ImapConfigService().init();
    });

    tearDown(() async {
      Get.reset();
      await db.close();
    });

    test('init seeds default host and sets isConfigured false', () {
      expect(service.isConfigured.value, isFalse);
      expect(service.cachedHost, 'imap.gmail.com');
    });

    test('getHost returns seeded default', () async {
      expect(await service.getHost(), 'imap.gmail.com');
    });

    test('getUser returns null when not configured', () async {
      expect(await service.getUser(), isNull);
    });

    test('getPass returns null when not configured', () async {
      expect(await service.getPass(), isNull);
    });

    test('saveConfig stores all 3 values and sets isConfigured true', () async {
      final result = await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );

      expect(result, isA<Success>());
      expect(service.isConfigured.value, isTrue);
      expect(service.cachedHost, 'imap.example.com');
      expect(await service.getHost(), 'imap.example.com');
      expect(await service.getUser(), 'user@example.com');
      expect(await service.getPass(), 'secret');
    });

    test('clearConfig removes user/pass and resets host to default', () async {
      await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );

      final result = await service.clearConfig();

      expect(result, isA<Success>());
      expect(service.isConfigured.value, isFalse);
      expect(service.cachedHost, 'imap.gmail.com');
      expect(await service.getUser(), isNull);
      expect(await service.getPass(), isNull);
      expect(await service.getHost(), 'imap.gmail.com');
    });

    test('isConfigured persists across re-init', () async {
      await service.saveConfig(
        host: 'imap.example.com',
        user: 'user@example.com',
        pass: 'secret',
      );

      final service2 = await ImapConfigService().init();
      expect(service2.isConfigured.value, isTrue);
      expect(service2.cachedHost, 'imap.example.com');
    });
  });
}
