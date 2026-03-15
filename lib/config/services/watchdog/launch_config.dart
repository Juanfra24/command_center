/// Presentation model for DreamBot launch parameters.
/// Session-scoped — not persisted to DB (future work: script profiles).
class LaunchConfig {
  final String scriptName;
  final String world;
  final bool covert;
  final String render;
  final String scriptParams;
  final String advancedFlags;

  const LaunchConfig({
    required this.scriptName,
    this.world = 'auto',
    this.covert = true,
    this.render = 'NONE',
    this.scriptParams = '',
    this.advancedFlags = '',
  });
}
