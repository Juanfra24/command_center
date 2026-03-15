import 'package:command_center/config/services/watchdog/launch_config.dart';

/// Mutable in-memory model tracking a running bot client.
/// Not a domain entity — lives in the watchdog service directory.
enum ClientStatus { running, restarting, stopped, failed, banned, awaitingAccount }

class TrackedClient {
  final String characterName;
  final int characterId;
  final int accountId;
  final int? proxySlotId;
  String? proxyAddress;
  final LaunchConfig launchConfig;
  int? pid;
  ClientStatus status;
  DateTime? launchedAt;
  int retryCount;
  int consecutiveQuickDeaths;
  DateTime? lastDeathAt;
  int _discoveryMisses;

  TrackedClient({
    required this.characterName,
    required this.characterId,
    required this.accountId,
    this.proxySlotId,
    this.proxyAddress,
    required this.launchConfig,
    this.pid,
    this.status = ClientStatus.running,
    this.launchedAt,
    this.retryCount = 0,
    this.consecutiveQuickDeaths = 0,
    this.lastDeathAt,
  }) : _discoveryMisses = 0;

  int get discoveryMisses => _discoveryMisses;
  void incrementDiscoveryMisses() => _discoveryMisses++;
  void resetDiscoveryMisses() => _discoveryMisses = 0;
}
