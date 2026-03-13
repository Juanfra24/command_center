import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/repositories/config_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ConfigRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ConfigRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ConfigRepositoryImpl', () {
    group('getValue / setValue', () {
      test('returns null for non-existent key', () async {
        final value = await repo.getValue('nonexistent');
        expect(value, isNull);
      });

      test('stores and retrieves a value', () async {
        await repo.setValue('api_key', 'abc123');
        final value = await repo.getValue('api_key');
        expect(value, equals('abc123'));
      });

      test('overwrites an existing value', () async {
        await repo.setValue('key', 'first');
        await repo.setValue('key', 'second');
        final value = await repo.getValue('key');
        expect(value, equals('second'));
      });

      test('stores multiple different keys independently', () async {
        await repo.setValue('key_a', 'value_a');
        await repo.setValue('key_b', 'value_b');

        expect(await repo.getValue('key_a'), equals('value_a'));
        expect(await repo.getValue('key_b'), equals('value_b'));
      });
    });

    group('deleteValue', () {
      test('removes an existing key', () async {
        await repo.setValue('to_delete', 'value');
        await repo.deleteValue('to_delete');

        final value = await repo.getValue('to_delete');
        expect(value, isNull);
      });

      test('does not throw when deleting non-existent key', () async {
        // Should not throw
        await repo.deleteValue('does_not_exist');
      });

      test('does not affect other keys', () async {
        await repo.setValue('keep', 'kept_value');
        await repo.setValue('remove', 'removed_value');
        await repo.deleteValue('remove');

        expect(await repo.getValue('keep'), equals('kept_value'));
        expect(await repo.getValue('remove'), isNull);
      });
    });

    group('getAllConfig', () {
      test('returns empty map when no config exists', () async {
        final config = await repo.getAllConfig();
        expect(config, isEmpty);
      });

      test('returns all stored key-value pairs', () async {
        await repo.setValue('key1', 'value1');
        await repo.setValue('key2', 'value2');
        await repo.setValue('key3', 'value3');

        final config = await repo.getAllConfig();
        expect(
            config,
            equals({
              'key1': 'value1',
              'key2': 'value2',
              'key3': 'value3',
            }));
      });
    });

    group('clearAll', () {
      test('removes all configuration entries', () async {
        await repo.setValue('a', '1');
        await repo.setValue('b', '2');
        await repo.clearAll();

        final config = await repo.getAllConfig();
        expect(config, isEmpty);
      });

      test('does not throw on empty table', () async {
        // Should not throw
        await repo.clearAll();
        final config = await repo.getAllConfig();
        expect(config, isEmpty);
      });
    });

    group('watchValue', () {
      test('emits current value and updates', () async {
        await repo.setValue('watched', 'initial');

        // Listen to the first emission
        final firstValue = await repo.watchValue('watched').first;
        expect(firstValue, equals('initial'));
      });

      test('emits null for non-existent key', () async {
        final firstValue = await repo.watchValue('missing').first;
        expect(firstValue, isNull);
      });
    });
  });
}
