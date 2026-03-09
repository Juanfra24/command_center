import 'package:command_center/domain/entities/account.dart';

/// Repository interface for account/character management
/// This is the domain layer - defines WHAT operations are available
abstract class AccountRepository {
  /// Get all accounts
  Future<List<AccountEntity>> getAllAccounts();

  /// Get an account by ID
  Future<AccountEntity?> getAccountById(int id);

  /// Get an account by email
  Future<AccountEntity?> getAccountByEmail(String email);

  /// Insert a new account, returns the generated ID
  Future<int> insertAccount(AccountEntity account);

  /// Update an existing account
  Future<void> updateAccount(AccountEntity account);

  /// Delete an account by ID
  Future<void> deleteAccount(int id);

  /// Watch all accounts (stream)
  Stream<List<AccountEntity>> watchAllAccounts();

  /// Get accounts by proxy slot ID
  Future<List<AccountEntity>> getAccountsByProxySlot(int proxySlotId);
}
