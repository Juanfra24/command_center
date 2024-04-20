import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:equatable/equatable.dart';

class JagexAccount extends Equatable {
  final String accountName;
  final String birthday;
  final String email;
  final String password;
  final String proxyAddress;
  final List<Character> characters;

  const JagexAccount({
    required this.accountName,
    required this.birthday,
    required this.email,
    required this.password,
    required this.proxyAddress,
    required this.characters,
  });

  factory JagexAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const JagexAccount(
        accountName: 'Default Name',
        birthday: '01-01-2000',
        email: 'default@example.com',
        password: 'defaultPassword123',
        proxyAddress: '0.0.0.0',
        characters: [],
      );
    }
    return JagexAccount(
      accountName: json['accountName'] ?? 'Default Name',
      birthday: json['birthday'] ?? '01-01-2000',
      email: json['email'] ?? 'default@example.com',
      password: json['password'] ?? 'defaultPassword123',
      proxyAddress: json['proxyAddress'] ?? '0.0.0.0',
      characters: (json['characters'] as List? ?? [])
          .map((characterJson) => Character.fromJson(characterJson))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [accountName, birthday, email, password, proxyAddress, characters];
}
