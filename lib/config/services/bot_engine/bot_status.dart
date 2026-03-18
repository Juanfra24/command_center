/// Parsed response from the Microbot Status API (/status endpoint).
/// Tolerates unknown fields — additive-only schema per spec.
class BotStatus {
  final int version;
  final String status;
  final String? scriptName;
  final bool scriptRunning;
  final int scriptRuntime;
  final int? world;
  final int hitpoints;
  final int prayer;
  final int runEnergy;
  final int totalXpGained;
  final int xpPerHour;
  final Map<String, int> skillXpGained;
  final int uptime;
  final bool loggedIn;

  const BotStatus({
    required this.version,
    required this.status,
    this.scriptName,
    this.scriptRunning = false,
    this.scriptRuntime = 0,
    this.world,
    this.hitpoints = 0,
    this.prayer = 0,
    this.runEnergy = 0,
    this.totalXpGained = 0,
    this.xpPerHour = 0,
    this.skillXpGained = const {},
    this.uptime = 0,
    this.loggedIn = false,
  });

  factory BotStatus.fromJson(Map<String, dynamic> json) {
    final script = _asMap(json['script']);
    final player = _asMap(json['player']);
    final xp = _asMap(json['xp']);
    final skills = _asMap(xp['skills']);

    return BotStatus(
      version: json['version'] as int? ?? 1,
      status: json['status'] as String? ?? 'unknown',
      scriptName: script['name'] as String?,
      scriptRunning: script['running'] as bool? ?? false,
      scriptRuntime: script['runtime'] as int? ?? 0,
      world: player['world'] as int?,
      hitpoints: player['hitpoints'] as int? ?? 0,
      prayer: player['prayer'] as int? ?? 0,
      runEnergy: player['runEnergy'] as int? ?? 0,
      totalXpGained: xp['totalGained'] as int? ?? 0,
      xpPerHour: xp['perHour'] as int? ?? 0,
      skillXpGained: {
        for (final entry in skills.entries)
          if (entry.value is Map)
            entry.key: (entry.value as Map)['gained'] as int? ?? 0,
      },
      uptime: json['uptime'] as int? ?? 0,
      loggedIn: json['loggedIn'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}
