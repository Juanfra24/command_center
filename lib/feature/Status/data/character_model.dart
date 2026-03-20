import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:equatable/equatable.dart';

// ignore: must_be_immutable
class Character extends Equatable {
  int? id;
  bool banned = false;
  String name = 'Default Character';
  Skills actualSkills = Skills.empty();
  Skills targetSkills = Skills.empty();
  String? defaultScriptName;

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
      banned: json['banned'] ?? false,
      name: json['name'] ?? 'Jhon Doe',
      actualSkills:
          Skills.fromJson(json['actualSkills'] as Map<String, dynamic>? ?? {}),
      targetSkills:
          Skills.fromJson(json['targetSkills'] as Map<String, dynamic>? ?? {}),
      defaultScriptName: json['defaultScriptName'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, banned, name, actualSkills, targetSkills, defaultScriptName];
}
