import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';

class ScoredIpResult {
  final ProxyIpAddressEntity ip;
  final ProxySlotEntity slot;

  /// Raw IPQS fraud score (0-100, lower is better).
  /// Higher values indicate greater fraud risk.
  final double score;

  const ScoredIpResult({
    required this.ip,
    required this.slot,
    required this.score,
  });
}
