import 'package:command_center/config/services/watchdog/launch_config.dart';

/// Result of a bot engine launch: OS PID and optional Status API port.
typedef LaunchResult = ({int pid, int? statusPort});

/// Contract for bot engine implementations.
/// The app interacts only with this interface — never concrete engines directly.
abstract class BotEngine {
  /// Launch a bot instance. Returns PID and optional Status API port.
  Future<LaunchResult> launch({
    required int characterId,
    required int accountId,
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

  /// Register an externally-discovered PID (e.g. recaptured on startup).
  /// Enables stop() to clean up profiles for processes the engine didn't launch.
  void registerRecapturedPid({required int pid, required int characterId});

  /// True when the engine has detected an out-of-date JAR error.
  /// While true, the watchdog will not restart or track new clients.
  bool get isOutdated;
}
