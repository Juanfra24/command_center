class BotTileData {
  final int characterId;
  final String characterName;
  final String? defaultScriptName;
  final String? proxySlotName;
  final String? countryCode;
  final String status; // running, stopped, restarting, banned
  final Duration? uptime; // null if not running or unknown

  const BotTileData({
    required this.characterId,
    required this.characterName,
    this.defaultScriptName,
    this.proxySlotName,
    this.countryCode,
    required this.status,
    this.uptime,
  });
}
