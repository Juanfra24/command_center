import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/repositories/account_repository_impl.dart';
import 'package:command_center/data/repositories/proxy_repository_impl.dart';
import 'package:command_center/domain/entities/account.dart';
import 'package:command_center/domain/entities/character.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/entities/skills.dart';

/// Helper to create a test AccountEntity
AccountEntity _makeAccount({
  int? id,
  String accountName = 'Test Account',
  String email = 'test@example.com',
  String password = 'pass123',
  String birthday = '01-01-2000',
  int? proxySlotId,
  List<CharacterEntity> characters = const [],
}) {
  return AccountEntity(
    id: id,
    accountName: accountName,
    email: email,
    password: password,
    birthday: birthday,
    proxySlotId: proxySlotId,
    characters: characters,
    createdAt: DateTime.now(),
    lastUpdated: DateTime.now(),
  );
}

/// Helper to create a test CharacterEntity
CharacterEntity _makeCharacter({
  int? id,
  int accountId = 0,
  String name = 'TestChar',
  bool banned = false,
}) {
  return CharacterEntity(
    id: id,
    accountId: accountId,
    name: name,
    banned: banned,
    defaultScriptName: null,
    actualSkills: SkillsEntity.empty(),
    targetSkills: SkillsEntity.empty(),
  );
}

/// Helper to create a test ProxySlotEntity
ProxySlotEntity _makeSlot({int slotNumber = 1, String webshareId = 'ws-1'}) {
  final now = DateTime.now();
  return ProxySlotEntity(
    webshareId: webshareId,
    slotName: 'Slot $slotNumber',
    slotNumber: slotNumber,
    username: 'user',
    password: 'pass',
    port: 80,
    createdAt: now,
    lastUpdated: now,
    totalIpChanges: 0,
    isActive: true,
  );
}

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl repo;
  late ProxyRepositoryImpl proxyRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AccountRepositoryImpl(db);
    proxyRepo = ProxyRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountRepositoryImpl - CRUD', () {
    test('insertAccount returns generated ID', () async {
      final id = await repo.insertAccount(_makeAccount());
      expect(id, greaterThan(0));
    });

    test('getAccountById returns inserted account', () async {
      final id = await repo.insertAccount(
        _makeAccount(accountName: 'My Account', email: 'a@b.com'),
      );

      final account = await repo.getAccountById(id);
      expect(account, isNotNull);
      expect(account!.accountName, equals('My Account'));
      expect(account.email, equals('a@b.com'));
    });

    test('getAccountById returns null for non-existent ID', () async {
      final account = await repo.getAccountById(999);
      expect(account, isNull);
    });

    test('getAccountByEmail finds account', () async {
      await repo.insertAccount(_makeAccount(email: 'find@me.com'));

      final account = await repo.getAccountByEmail('find@me.com');
      expect(account, isNotNull);
      expect(account!.email, equals('find@me.com'));
    });

    test('getAccountByEmail returns null for non-existent email', () async {
      final account = await repo.getAccountByEmail('nope@nope.com');
      expect(account, isNull);
    });

    test('getAllAccounts returns all accounts', () async {
      await repo.insertAccount(_makeAccount(email: 'a@a.com'));
      await repo.insertAccount(_makeAccount(email: 'b@b.com'));

      final accounts = await repo.getAllAccounts();
      expect(accounts.length, equals(2));
    });

    test('updateAccount modifies fields', () async {
      final id = await repo.insertAccount(
        _makeAccount(accountName: 'Original', email: 'orig@test.com'),
      );

      var account = await repo.getAccountById(id);
      await repo.updateAccount(account!.copyWith(accountName: 'Updated'));

      account = await repo.getAccountById(id);
      expect(account!.accountName, equals('Updated'));
    });

    test('updateAccount throws for account without ID', () async {
      final account = _makeAccount();
      expect(
        () => repo.updateAccount(account),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteAccount removes account and characters', () async {
      final id = await repo.insertAccount(
        _makeAccount(
          email: 'del@test.com',
          characters: [_makeCharacter(name: 'DelChar')],
        ),
      );

      await repo.deleteAccount(id);

      expect(await repo.getAccountById(id), isNull);
    });
  });

  group('AccountRepositoryImpl - Characters', () {
    test('insertAccount with characters stores them', () async {
      final id = await repo.insertAccount(
        _makeAccount(
          email: 'char@test.com',
          characters: [
            _makeCharacter(name: 'Warrior'),
            _makeCharacter(name: 'Mage'),
          ],
        ),
      );

      final account = await repo.getAccountById(id);
      expect(account!.characters.length, equals(2));
      expect(
        account.characters.map((c) => c.name).toSet(),
        containsAll(['Warrior', 'Mage']),
      );
    });

    test('characters have skills populated', () async {
      final skills = SkillsEntity.empty().copyWith(attack: 50, strength: 40);
      final id = await repo.insertAccount(
        _makeAccount(
          email: 'skills@test.com',
          characters: [
            CharacterEntity(
              accountId: 0,
              name: 'Skilled',
              banned: false,
              actualSkills: skills,
              targetSkills: SkillsEntity.empty(),
            ),
          ],
        ),
      );

      final account = await repo.getAccountById(id);
      final char = account!.characters.first;
      expect(char.actualSkills.attack, equals(50));
      expect(char.actualSkills.strength, equals(40));
    });

    test('updateAccount replaces characters', () async {
      final id = await repo.insertAccount(
        _makeAccount(
          email: 'replace@test.com',
          characters: [_makeCharacter(name: 'OldChar')],
        ),
      );

      var account = await repo.getAccountById(id);
      await repo.updateAccount(
        account!.copyWith(characters: [_makeCharacter(name: 'NewChar')]),
      );

      account = await repo.getAccountById(id);
      expect(account!.characters.length, equals(1));
      expect(account.characters.first.name, equals('NewChar'));
    });

    test('updateAccount preserves existing character IDs', () async {
      final id = await repo.insertAccount(
        _makeAccount(
          email: 'preserve@test.com',
          characters: [_makeCharacter(name: 'Keeper')],
        ),
      );

      final original = await repo.getAccountById(id);
      final originalCharId = original!.characters.first.id;
      expect(originalCharId, isNotNull);

      // Update account with same character (has the ID set)
      await repo.updateAccount(
        original.copyWith(
          characters: [original.characters.first.copyWith(name: 'Renamed')],
        ),
      );

      final updated = await repo.getAccountById(id);
      expect(updated!.characters.first.id, equals(originalCharId),
          reason: 'Character ID must be preserved across updates');
      expect(updated.characters.first.name, equals('Renamed'));
    });

    test('updateAccount adds new characters alongside existing ones', () async {
      final id = await repo.insertAccount(
        _makeAccount(
          email: 'addchar@test.com',
          characters: [_makeCharacter(name: 'Original')],
        ),
      );

      final original = await repo.getAccountById(id);
      final existingChar = original!.characters.first;

      // Update with existing + new character
      await repo.updateAccount(
        original.copyWith(
          characters: [
            existingChar, // keep existing
            _makeCharacter(name: 'NewChar'), // add new (no ID)
          ],
        ),
      );

      final updated = await repo.getAccountById(id);
      expect(updated!.characters.length, equals(2));
      expect(updated.characters.any((c) => c.name == 'Original'), isTrue);
      expect(updated.characters.any((c) => c.name == 'NewChar'), isTrue);
      // Existing character ID preserved
      expect(
        updated.characters.firstWhere((c) => c.name == 'Original').id,
        equals(existingChar.id),
      );
    });
  });

  group('AccountRepositoryImpl - Proxy relationship', () {
    test('getAccountsByProxySlot returns matching accounts', () async {
      final slotId = await proxyRepo.insertSlot(_makeSlot());

      await repo.insertAccount(
        _makeAccount(email: 'p1@test.com', proxySlotId: slotId),
      );
      await repo.insertAccount(
        _makeAccount(email: 'p2@test.com', proxySlotId: slotId),
      );
      await repo.insertAccount(
        _makeAccount(email: 'other@test.com'),
      );

      final accounts = await repo.getAccountsByProxySlot(slotId);
      expect(accounts.length, equals(2));
    });

    test('getAccountsByProxySlot returns empty for unlinked slot', () async {
      final accounts = await repo.getAccountsByProxySlot(999);
      expect(accounts, isEmpty);
    });
  });

  group('AccountRepositoryImpl - watchAllAccounts', () {
    test('emits current accounts', () async {
      await repo.insertAccount(_makeAccount(email: 'w1@test.com'));
      await repo.insertAccount(_makeAccount(email: 'w2@test.com'));

      final accounts = await repo.watchAllAccounts().first;
      expect(accounts.length, equals(2));
    });
  });
}
