import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/character.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:get/get.dart';

/// Loads characters linked to a proxy slot via their account.
class LinkedCharactersLoader {
  final AccountRepository? _accountRepository;
  final linkedCharacters = <CharacterEntity>[].obs;

  LinkedCharactersLoader(this._accountRepository);

  Future<void> loadForSlot(int slotId) async {
    if (_accountRepository == null) return;
    try {
      final accounts =
          await _accountRepository.getAccountsByProxySlot(slotId);
      linkedCharacters.value =
          accounts.expand((a) => a.characters).toList();
    } catch (e) {
      logger.e('Error loading linked characters for slot $slotId: $e');
      linkedCharacters.clear();
    }
  }

  void clear() => linkedCharacters.clear();
}
