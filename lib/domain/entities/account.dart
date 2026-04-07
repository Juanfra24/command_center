import 'package:equatable/equatable.dart';

import 'character.dart';

/// Domain entity for a Jagex account
/// This is a pure Dart class with no database dependencies
class AccountEntity extends Equatable {
  final int? id;
  final String accountName;
  final String birthday;
  final String email;
  final String password;
  final int? proxySlotId;
  final List<CharacterEntity> characters;
  final DateTime? createdAt;
  final DateTime? lastUpdated;
  final String? jagexRefreshToken;
  final String? jagexCharacterId;
  final String? jagexDisplayName;

  const AccountEntity({
    this.id,
    required this.accountName,
    required this.birthday,
    required this.email,
    required this.password,
    this.proxySlotId,
    required this.characters,
    this.createdAt,
    this.lastUpdated,
    this.jagexRefreshToken,
    this.jagexCharacterId,
    this.jagexDisplayName,
  });

  factory AccountEntity.empty() {
    return AccountEntity(
      id: null,
      accountName: 'Default Name',
      birthday: '01-01-2000',
      email: 'default@example.com',
      password: 'defaultPassword123',
      proxySlotId: null,
      characters: const [],
      createdAt: null,
      lastUpdated: null,
    );
  }

  /// Get proxy address string (for backwards compatibility)
  /// This will need to be resolved from the proxy slot
  String get proxyAddress => '';

  AccountEntity copyWith({
    int? id,
    String? accountName,
    String? birthday,
    String? email,
    String? password,
    int? proxySlotId,
    List<CharacterEntity>? characters,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? jagexRefreshToken,
    String? jagexCharacterId,
    String? jagexDisplayName,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      birthday: birthday ?? this.birthday,
      email: email ?? this.email,
      password: password ?? this.password,
      proxySlotId: proxySlotId ?? this.proxySlotId,
      characters: characters ?? this.characters,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      jagexRefreshToken: jagexRefreshToken ?? this.jagexRefreshToken,
      jagexCharacterId: jagexCharacterId ?? this.jagexCharacterId,
      jagexDisplayName: jagexDisplayName ?? this.jagexDisplayName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountName,
        birthday,
        email,
        password,
        proxySlotId,
        characters,
        createdAt,
        lastUpdated,
        jagexRefreshToken,
        jagexCharacterId,
        jagexDisplayName,
      ];
}
