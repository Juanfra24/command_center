import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:equatable/equatable.dart';

// ignore: must_be_immutable
class Character extends Equatable {
  bool banned = false;
  String name = 'Default Character';
  Skills actualSkills = Skills.empty();
  Skills targetSkills = Skills.empty();

  Character({
    required this.banned,
    required this.name,
    required this.actualSkills,
    required this.targetSkills,
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
      banned: json['banned'] ?? false,
      name: json['name'] ?? 'Jhon Doe',
      actualSkills:
          Skills.fromJson(json['actualSkills'] as Map<String, dynamic>? ?? {}),
      targetSkills:
          Skills.fromJson(json['targetSkills'] as Map<String, dynamic>? ?? {}),
    );
  }

  @override
  List<Object?> get props => [banned, name, actualSkills, targetSkills];
}
