import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/repositories/account_repository_impl.dart';
import 'package:command_center/domain/entities/account.dart';

void main() {
  test('updateJagexToken stores refresh token, character id and display name',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = AccountRepositoryImpl(db);

    final accountId = await repo.insertAccount(AccountEntity(
      accountName: 'TestBot',
      birthday: '01-01-2000',
      email: 'test@example.com',
      password: 'pass',
      characters: const [],
    ));

    await repo.updateJagexToken(
      accountId: accountId,
      refreshToken: 'rt_abc123',
      characterId: 'char_456',
      displayName: 'TestBotName',
    );

    final updated = await repo.getAccountById(accountId);
    expect(updated!.jagexRefreshToken, 'rt_abc123');
    expect(updated.jagexCharacterId, 'char_456');
    expect(updated.jagexDisplayName, 'TestBotName');

    await db.close();
  });
}
