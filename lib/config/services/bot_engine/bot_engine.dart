import 'package:command_center/config/services/watchdog/launch_config.dart';

/// Contract for bot engine implementations.
/// The app interacts only with this interface — never concrete engines directly.
abstract class BotEngine {
  /// Launch a bot instance. Returns the OS process ID.
  Future<int> launch({
    required int characterId,
    required String characterName,
    required String email,
    required String password,
    required String? proxyUrl,
    required LaunchConfig config,
  });

  /// Stop a running bot instance by PID. Kills process and cleans up artifacts.
  Future<void> stop(int pid);

  /// Human-readable engine name (for logs/notifications).
  String get engineName;
}
