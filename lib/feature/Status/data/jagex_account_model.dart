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
    this.accountName = 'Default Name',
    this.birthday = '01-01-2000',
    this.email = 'default@example.com',
    this.password = 'defaultPassword123',
    this.proxyAddress = '0.0.0.0',
    this.characters = const <Character>[],
  });

  factory JagexAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return JagexAccount(
        accountName: 'Default Name',
        birthday: '01-01-2000',
        email: 'default@example.com',
        password: 'defaultPassword123',
        proxyAddress: '0.0.0.0',
        characters: const [],
      );
    }
    return JagexAccount(
      accountName: json['accountName'] ?? "Default Name",
      birthday: json['birthday'] ?? "01-01-2000",
      email: json['email'] ?? "default@example.com",
      password: json['password'] ?? "defaultPassword123",
      proxyAddress: json['proxyAddress'] ?? "0.0.0.0",
      characters: (json['characters'] as List? ?? [])
          .map((characterJson) => Character.fromJson(characterJson))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [accountName, birthday, email, password, proxyAddress, characters];
}
