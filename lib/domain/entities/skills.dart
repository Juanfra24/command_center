import 'package:equatable/equatable.dart';

/// Domain entity for character skills
/// This is a pure Dart class with no database dependencies
class SkillsEntity extends Equatable {
  final int attack;
  final int defence;
  final int strength;
  final int hitpoints;
  final int range;
  final int prayer;
  final int magic;
  final int cooking;
  final int woodcutting;
  final int fletching;
  final int fishing;
  final int firemaking;
  final int crafting;
  final int mining;
  final int smithing;
  final int agility;
  final int herblore;
  final int thieving;
  final int slayer;
  final int farming;
  final int runecrafting;
  final int construction;
  final int hunter;

  const SkillsEntity({
    required this.attack,
    required this.defence,
    required this.strength,
    required this.hitpoints,
    required this.range,
    required this.prayer,
    required this.magic,
    required this.cooking,
    required this.woodcutting,
    required this.fletching,
    required this.fishing,
    required this.firemaking,
    required this.crafting,
    required this.mining,
    required this.smithing,
    required this.agility,
    required this.herblore,
    required this.thieving,
    required this.slayer,
    required this.farming,
    required this.runecrafting,
    required this.construction,
    required this.hunter,
  });

  factory SkillsEntity.empty() {
    return const SkillsEntity(
      attack: 0,
      defence: 0,
      strength: 0,
      hitpoints: 0,
      range: 0,
      prayer: 0,
      magic: 0,
      cooking: 0,
      woodcutting: 0,
      fletching: 0,
      fishing: 0,
      firemaking: 0,
      crafting: 0,
      mining: 0,
      smithing: 0,
      agility: 0,
      herblore: 0,
      thieving: 0,
      slayer: 0,
      farming: 0,
      runecrafting: 0,
      construction: 0,
      hunter: 0,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'attack': attack,
      'defence': defence,
      'strength': strength,
      'hitpoints': hitpoints,
      'range': range,
      'prayer': prayer,
      'magic': magic,
      'cooking': cooking,
      'woodcutting': woodcutting,
      'fletching': fletching,
      'fishing': fishing,
      'firemaking': firemaking,
      'crafting': crafting,
      'mining': mining,
      'smithing': smithing,
      'agility': agility,
      'herblore': herblore,
      'thieving': thieving,
      'slayer': slayer,
      'farming': farming,
      'runecrafting': runecrafting,
      'construction': construction,
      'hunter': hunter,
    };
  }

  factory SkillsEntity.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SkillsEntity.empty();
    }
    return SkillsEntity(
      attack: json['attack'] ?? 0,
      defence: json['defence'] ?? 0,
      strength: json['strength'] ?? 0,
      hitpoints: json['hitpoints'] ?? 0,
      range: json['range'] ?? 0,
      prayer: json['prayer'] ?? 0,
      magic: json['magic'] ?? 0,
      cooking: json['cooking'] ?? 0,
      woodcutting: json['woodcutting'] ?? 0,
      fletching: json['fletching'] ?? 0,
      fishing: json['fishing'] ?? 0,
      firemaking: json['firemaking'] ?? 0,
      crafting: json['crafting'] ?? 0,
      mining: json['mining'] ?? 0,
      smithing: json['smithing'] ?? 0,
      agility: json['agility'] ?? 0,
      herblore: json['herblore'] ?? 0,
      thieving: json['thieving'] ?? 0,
      slayer: json['slayer'] ?? 0,
      farming: json['farming'] ?? 0,
      runecrafting: json['runecrafting'] ?? 0,
      construction: json['construction'] ?? 0,
      hunter: json['hunter'] ?? 0,
    );
  }

  SkillsEntity copyWith({
    int? attack,
    int? defence,
    int? strength,
    int? hitpoints,
    int? range,
    int? prayer,
    int? magic,
    int? cooking,
    int? woodcutting,
    int? fletching,
    int? fishing,
    int? firemaking,
    int? crafting,
    int? mining,
    int? smithing,
    int? agility,
    int? herblore,
    int? thieving,
    int? slayer,
    int? farming,
    int? runecrafting,
    int? construction,
    int? hunter,
  }) {
    return SkillsEntity(
      attack: attack ?? this.attack,
      defence: defence ?? this.defence,
      strength: strength ?? this.strength,
      hitpoints: hitpoints ?? this.hitpoints,
      range: range ?? this.range,
      prayer: prayer ?? this.prayer,
      magic: magic ?? this.magic,
      cooking: cooking ?? this.cooking,
      woodcutting: woodcutting ?? this.woodcutting,
      fletching: fletching ?? this.fletching,
      fishing: fishing ?? this.fishing,
      firemaking: firemaking ?? this.firemaking,
      crafting: crafting ?? this.crafting,
      mining: mining ?? this.mining,
      smithing: smithing ?? this.smithing,
      agility: agility ?? this.agility,
      herblore: herblore ?? this.herblore,
      thieving: thieving ?? this.thieving,
      slayer: slayer ?? this.slayer,
      farming: farming ?? this.farming,
      runecrafting: runecrafting ?? this.runecrafting,
      construction: construction ?? this.construction,
      hunter: hunter ?? this.hunter,
    );
  }

  @override
  List<Object?> get props => [
        attack,
        defence,
        strength,
        hitpoints,
        range,
        prayer,
        magic,
        cooking,
        woodcutting,
        fletching,
        fishing,
        firemaking,
        crafting,
        mining,
        smithing,
        agility,
        herblore,
        thieving,
        slayer,
        farming,
        runecrafting,
        construction,
        hunter,
      ];
}
