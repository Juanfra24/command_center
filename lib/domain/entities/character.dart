import 'package:equatable/equatable.dart';

import 'skills.dart';

/// Domain entity for a game character
/// This is a pure Dart class with no database dependencies
class CharacterEntity extends Equatable {
  final int? id;
  final int accountId;
  final String name;
  final bool banned;
  final String? defaultScriptName;
  final SkillsEntity actualSkills;
  final SkillsEntity targetSkills;

  const CharacterEntity({
    this.id,
    required this.accountId,
    required this.name,
    required this.banned,
    this.defaultScriptName,
    required this.actualSkills,
    required this.targetSkills,
  });

  factory CharacterEntity.empty() {
    return CharacterEntity(
      id: null,
      accountId: 0,
      name: 'Default Character',
      banned: false,
      defaultScriptName: null,
      actualSkills: SkillsEntity.empty(),
      targetSkills: SkillsEntity.empty(),
    );
  }

  CharacterEntity copyWith({
    int? id,
    int? accountId,
    String? name,
    bool? banned,
    String? defaultScriptName,
    SkillsEntity? actualSkills,
    SkillsEntity? targetSkills,
  }) {
    return CharacterEntity(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      banned: banned ?? this.banned,
      defaultScriptName: defaultScriptName ?? this.defaultScriptName,
      actualSkills: actualSkills ?? this.actualSkills,
      targetSkills: targetSkills ?? this.targetSkills,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountId,
        name,
        banned,
        defaultScriptName,
        actualSkills,
        targetSkills,
      ];
}
