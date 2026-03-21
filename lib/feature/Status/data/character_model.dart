import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:equatable/equatable.dart';

class Character extends Equatable {
  final int? id;
  final bool banned;
  final String name;
  final Skills actualSkills;
  final Skills targetSkills;
  final String? defaultScriptName;

  Character({
    this.id,
    required this.banned,
    required this.name,
    required this.actualSkills,
    required this.targetSkills,
    this.defaultScriptName,
  });

  factory Character.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Character(
        banned: false,
        name: 'Default Character',
        actualSkills: Skills.empty(),
        targetSkills: Skills.empty(),
      );
    }
    return Character(
      id: json['id'] as int?,
      banned: json['banned'] as bool? ?? false,
      name: json['name'] as String? ?? 'John Doe',
      actualSkills:
          Skills.fromJson(json['actualSkills'] as Map<String, dynamic>? ?? {}),
      targetSkills:
          Skills.fromJson(json['targetSkills'] as Map<String, dynamic>? ?? {}),
      defaultScriptName: json['defaultScriptName'] as String?,
    );
  }

  Character copyWith({
    int? id,
    bool? banned,
    String? name,
    Skills? actualSkills,
    Skills? targetSkills,
    String? defaultScriptName,
  }) {
    return Character(
      id: id ?? this.id,
      banned: banned ?? this.banned,
      name: name ?? this.name,
      actualSkills: actualSkills ?? this.actualSkills,
      targetSkills: targetSkills ?? this.targetSkills,
      defaultScriptName: defaultScriptName ?? this.defaultScriptName,
    );
  }

  @override
  List<Object?> get props =>
      [id, banned, name, actualSkills, targetSkills, defaultScriptName];
}
