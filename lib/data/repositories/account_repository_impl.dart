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
    return await _db.transaction(() async {
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
    });
  }

  @override
  Future<void> updateAccount(AccountEntity account) async {
    if (account.id == null) {
      throw ArgumentError('Cannot update account without an id');
    }

    await _db.transaction(() async {
      // Update account fields
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

      // Upsert characters: update existing (have ID), insert new (no ID)
      final incomingIds = account.characters
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toSet();

      // Delete characters that are no longer in the list
      final existingChars = await (_db.select(_db.charactersTable)
            ..where((tbl) => tbl.accountId.equals(account.id!)))
          .get();
      for (final existing in existingChars) {
        if (!incomingIds.contains(existing.id)) {
          await (_db.delete(_db.charactersTable)
                ..where((tbl) => tbl.id.equals(existing.id)))
              .go();
        }
      }

      // Update existing characters, insert new ones
      for (final character in account.characters) {
        if (character.id != null) {
          await (_db.update(_db.charactersTable)
                ..where((tbl) => tbl.id.equals(character.id!)))
              .write(CharactersTableCompanion(
            name: Value(character.name),
            banned: Value(character.banned),
            defaultScriptName: Value(character.defaultScriptName),
            actualSkillsJson:
                Value(jsonEncode(character.actualSkills.toJson())),
            targetSkillsJson:
                Value(jsonEncode(character.targetSkills.toJson())),
            lastUpdated: Value(DateTime.now()),
          ));
        } else {
          await _insertCharacter(character.copyWith(accountId: account.id));
        }
      }
    });
  }

  @override
  Future<void> deleteAccount(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.charactersTable)
            ..where((tbl) => tbl.accountId.equals(id)))
          .go();
      await (_db.delete(_db.accountsTable)..where((tbl) => tbl.id.equals(id)))
          .go();
    });
  }

  @override
  Stream<List<AccountEntity>> watchAllAccounts() {
    // React to changes in BOTH accounts and characters tables. Watching
    // only accountsTable misses character-only updates (e.g. banning a
    // character, updating skills), leaving the UI with stale character
    // data until the next account-level write.
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.accountsTable, _db.charactersTable},
        )
        .watch()
        .asyncMap((_) => getAllAccounts());
  }

  @override
  Future<List<AccountEntity>> getAccountsByProxySlot(int proxySlotId) async {
    final query = _db.select(_db.accountsTable)
      ..where((tbl) => tbl.proxySlotId.equals(proxySlotId));
    final accounts = await query.get();

    if (accounts.isEmpty) return [];

    final accountIds = accounts.map((a) => a.id).toList();
    final charQuery = _db.select(_db.charactersTable)
      ..where((tbl) => tbl.accountId.isIn(accountIds));
    final scopedChars = await charQuery.get();
    final charsByAccountId = <int, List<CharacterEntity>>{};
    for (final charRow in scopedChars) {
      charsByAccountId
          .putIfAbsent(charRow.accountId, () => [])
          .add(_mapCharacterRow(charRow));
    }

    return accounts
        .map((a) => _mapAccountRow(a, charsByAccountId[a.id] ?? []))
        .toList();
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

  @override
  Future<void> updateJagexToken({
    required int accountId,
    required String refreshToken,
    required String characterId,
    required String displayName,
  }) async {
    await (_db.update(_db.accountsTable)
          ..where((tbl) => tbl.id.equals(accountId)))
        .write(AccountsTableCompanion(
      jagexRefreshToken: Value(refreshToken),
      jagexCharacterId: Value(characterId),
      jagexDisplayName: Value(displayName),
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
      jagexRefreshToken: row.jagexRefreshToken,
      jagexCharacterId: row.jagexCharacterId,
      jagexDisplayName: row.jagexDisplayName,
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
