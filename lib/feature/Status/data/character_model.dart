import 'package:command_center/feature/Status/data/skills_model.dart';
import 'package:equatable/equatable.dart';

class Character extends Equatable {
  final bool banned;
  final String name;
  final Skills actualSkills;
  final Skills targetSkills;

  const Character({
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
        actualSkills: Skills.defaultSkills(),
        targetSkills: Skills.defaultSkills(),
      );
    }
    return Character(
      banned: json['banned'] ?? false,
      name: json['name'] ?? 'Default Character',
      actualSkills:
          Skills.fromJson(json['actualSkills'] as Map<String, dynamic>?),
      targetSkills:
          Skills.fromJson(json['targetSkills'] as Map<String, dynamic>?),
    );
  }

  @override
  List<Object?> get props => [banned, name, actualSkills, targetSkills];
}
