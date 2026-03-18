import 'dart:math';

Map<String, int> generateOsrsStats() {
  var rng = Random();
  var totalLevel =
      rng.nextInt(201) + 1000; // Random total level between 800 and 1000

  var skillNames = [
    "Attack", "Defence", "Strength", "Hitpoints", "Range", "Prayer", "Magic",
    "Cooking",
    "Woodcutting", "Fletching", "Fishing", "Firemaking", "Crafting", "Mining",
    "Smithing",
    "Agility", "Herblore", "Thieving", "Slayer", "Farming", "Runecrafting",
    "Construction",
    "Hunter"
  ];

  var numSkills = skillNames.length;
  var meanLevel = totalLevel ~/ numSkills;
  var skillLevels = {for (var skill in skillNames) skill: meanLevel};

  // Set combat skills to 40 initially
  var combatSkills = ["Attack", "Defence", "Strength"];
  for (var skill in combatSkills) {
    skillLevels[skill] = 40;
  }

  // Apply a varied range of adjustments to each skill
  for (var skill in skillNames) {
    // Adjust each skill by a random amount multiple times
    for (var i = 0; i < 5; i++) {
      if (combatSkills.contains(skill)) {
        // Ensure only positive adjustments for combat skills
        skillLevels[skill] = skillLevels[skill]! + rng.nextInt(4); // 0 to 3
      } else {
        // Apply more varied adjustments to non-combat skills
        skillLevels[skill] =
            skillLevels[skill]! + rng.nextInt(15) - 7; // -7 to +7
        skillLevels[skill] =
            max(1, skillLevels[skill]!); // Ensure no skill level falls below 1
      }
    }
  }

  // Normalize the total levels to meet the specified total level
  int currentTotal = skillLevels.values.reduce((a, b) => a + b);
  int adjustment = totalLevel - currentTotal;

  while (adjustment != 0) {
    for (var skill in skillNames) {
      if (adjustment > 0) {
        skillLevels[skill] = skillLevels[skill]! + 1;
        adjustment--;
      } else if (adjustment < 0 && skillLevels[skill]! > 1) {
        skillLevels[skill] = skillLevels[skill]! - 1;
        adjustment++;
      }
      if (adjustment == 0) break;
    }
  }

  // Ensure combat skills remain above 40
  for (var skill in combatSkills) {
    skillLevels[skill] = max(40, skillLevels[skill]!);
  }

  // Recalculate the total level after all adjustments
  var totalLevelAchieved = skillLevels.values.reduce((a, b) => a + b);

  return {'totalLevelAchieved': totalLevelAchieved, ...skillLevels};
}

/*
void main() {
  var stats = generateOsrsStats();
  print('Total Level Achieved: ${stats['totalLevelAchieved']}');
  stats.remove('totalLevelAchieved');  // Remove the total from the dictionary to print only skills
  stats.forEach((skill, level) {
    print('$skill: $level');
  });
}
*/
