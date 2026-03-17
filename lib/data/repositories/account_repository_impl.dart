import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/helper/logger.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/skills.dart';
import '../../domain/repositories/account_repository.dart';
import '../database/app_database.dart';

/// Drift implementation of the AccountRepository
class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _db;

  AccountRepositoryImpl(this._db);

  // ============ Account Operations ============

  @override
  Future<List<AccountEntity>> getAllAccounts() async {
    final accounts = await _db.select(_db.accountsTable).get();
    final allCharacters = await _db.select(_db.charactersTable).get();

    // Group characters by accountId for O(1) lookup
    final charsByAccountId = <int, List<CharacterEntity>>{};
    for (final charRow in allCharacters) {
      final entity = _mapCharacterRow(charRow);
      charsByAccountId.putIfAbsent(charRow.accountId, () => []).add(entity);
    }

    return accounts
        .map((a) => _mapAccountRow(a, charsByAccountId[a.id] ?? []))
        .toList();
  }

  @override
  Future<AccountEntity?> getAccountById(int id) async {
    final query = _db.select(_db.accountsTable)
      ..where((tbl) => tbl.id.equals(id));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    final characters = await _getCharactersForAccount(id);
    return _mapAccountRow(result, characters);
  }

  @override
  Future<AccountEntity?> getAccountByEmail(String email) async {
    final query = _db.select(_db.accountsTable)
      ..where((tbl) => tbl.email.equals(email));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    final characters = await _getCharactersForAccount(result.id);
    return _mapAccountRow(result, characters);
  }

  @override
  Future<int> insertAccount(AccountEntity account) async {
    final accountId = await _db.into(_db.accountsTable).insert(
          AccountsTableCompanion.insert(
            accountName: account.accountName,
            birthday: Value(account.birthday),
            email: account.email,
            password: account.password,
            proxySlotId: Value(account.proxySlotId),
            createdAt: Value(account.createdAt ?? DateTime.now()),
            lastUpdated: Value(account.lastUpdated ?? DateTime.now()),
          ),
        );

    // Insert characters
    for (final character in account.characters) {
      await _insertCharacter(character.copyWith(accountId: accountId));
    }

    return accountId;
  }

  @override
  Future<void> updateAccount(AccountEntity account) async {
    if (account.id == null) {
      throw ArgumentError('Cannot update account without an id');
    }

    await (_db.update(_db.accountsTable)
          ..where((tbl) => tbl.id.equals(account.id!)))
        .write(
      AccountsTableCompanion(
        accountName: Value(account.accountName),
        birthday: Value(account.birthday),
        email: Value(account.email),
        password: Value(account.password),
        proxySlotId: Value(account.proxySlotId),
        lastUpdated: Value(DateTime.now()),
      ),
    );

    // Update characters - delete existing and re-insert
    await (_db.delete(_db.charactersTable)
          ..where((tbl) => tbl.accountId.equals(account.id!)))
        .go();

    for (final character in account.characters) {
      await _insertCharacter(character.copyWith(accountId: account.id));
    }
  }

  @override
  Future<void> deleteAccount(int id) async {
    // Delete characters first
    await (_db.delete(_db.charactersTable)
          ..where((tbl) => tbl.accountId.equals(id)))
        .go();

    // Delete account
    await (_db.delete(_db.accountsTable)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  @override
  Stream<List<AccountEntity>> watchAllAccounts() {
    return _db.select(_db.accountsTable).watch().asyncMap((accounts) async {
      final result = <AccountEntity>[];
      for (final account in accounts) {
        final characters = await _getCharactersForAccount(account.id);
        result.add(_mapAccountRow(account, characters));
      }
      return result;
    });
  }

  @override
  Future<List<AccountEntity>> getAccountsByProxySlot(int proxySlotId) async {
    final query = _db.select(_db.accountsTable)
      ..where((tbl) => tbl.proxySlotId.equals(proxySlotId));
    final accounts = await query.get();

    final result = <AccountEntity>[];
    for (final account in accounts) {
      final characters = await _getCharactersForAccount(account.id);
      result.add(_mapAccountRow(account, characters));
    }

    return result;
  }

  @override
  Future<void> updateCharacterBanned(int characterId, bool banned) async {
    await (_db.update(_db.charactersTable)
          ..where((tbl) => tbl.id.equals(characterId)))
        .write(CharactersTableCompanion(
      banned: Value(banned),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  // ============ Character Operations (Private) ============

  Future<List<CharacterEntity>> _getCharactersForAccount(int accountId) async {
    final query = _db.select(_db.charactersTable)
      ..where((tbl) => tbl.accountId.equals(accountId));
    final results = await query.get();
    return results.map(_mapCharacterRow).toList();
  }

  Future<int> _insertCharacter(CharacterEntity character) async {
    return await _db.into(_db.charactersTable).insert(
          CharactersTableCompanion.insert(
            accountId: character.accountId,
            name: character.name,
            banned: Value(character.banned),
            defaultScriptName: Value(character.defaultScriptName),
            actualSkillsJson:
                Value(jsonEncode(character.actualSkills.toJson())),
            targetSkillsJson:
                Value(jsonEncode(character.targetSkills.toJson())),
            createdAt: Value(DateTime.now()),
            lastUpdated: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> updateCharacterDefaultScript(
    int characterId,
    String? scriptName,
  ) async {
    await (_db.update(_db.charactersTable)
          ..where((t) => t.id.equals(characterId)))
        .write(CharactersTableCompanion(
      defaultScriptName: Value(scriptName),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  // ============ Mapping Helpers ============

  AccountEntity _mapAccountRow(
    AccountsTableData row,
    List<CharacterEntity> characters,
  ) {
    return AccountEntity(
      id: row.id,
      accountName: row.accountName,
      birthday: row.birthday,
      email: row.email,
      password: row.password,
      proxySlotId: row.proxySlotId,
      characters: characters,
      createdAt: row.createdAt,
      lastUpdated: row.lastUpdated,
    );
  }

  CharacterEntity _mapCharacterRow(CharactersTableData row) {
    SkillsEntity actualSkills;
    SkillsEntity targetSkills;

    try {
      actualSkills = SkillsEntity.fromJson(
        jsonDecode(row.actualSkillsJson) as Map<String, dynamic>,
      );
    } catch (e) {
      logger.e('Failed to parse actualSkillsJson for character ${row.id}: $e');
      actualSkills = SkillsEntity.empty();
    }

    try {
      targetSkills = SkillsEntity.fromJson(
        jsonDecode(row.targetSkillsJson) as Map<String, dynamic>,
      );
    } catch (e) {
      logger.e('Failed to parse targetSkillsJson for character ${row.id}: $e');
      targetSkills = SkillsEntity.empty();
    }

    return CharacterEntity(
      id: row.id,
      accountId: row.accountId,
      name: row.name,
      banned: row.banned,
      defaultScriptName: row.defaultScriptName,
      actualSkills: actualSkills,
      targetSkills: targetSkills,
    );
  }
}
