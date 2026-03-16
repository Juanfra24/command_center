class LaunchConfig {
  final String scriptName;
  final String world;
  final String scriptParams;
  final String advancedFlags;
  final String? jvmArgs;

  const LaunchConfig({
    required this.scriptName,
    this.world = 'auto',
    this.scriptParams = '',
    this.advancedFlags = '',
    this.jvmArgs,
  });
}
