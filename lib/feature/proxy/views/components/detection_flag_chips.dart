import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Displays detection flag chips (VPN, Proxy, Tor, etc.) for a proxy IP.
class DetectionFlagChips extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const DetectionFlagChips({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final flags = [
      _Flag('VPN', ip.isVpn),
      _Flag('Proxy', ip.isProxy),
      _Flag('Tor', ip.isTor),
      _Flag('Datacenter', ip.isDatacenter),
      _Flag('Crawler', ip.isCrawler ?? false),
      _Flag('Recent Abuse', ip.recentAbuse ?? false),
    ]..sort((a, b) {
        if (a.detected == b.detected) return 0;
        return a.detected ? -1 : 1;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETECTION FLAGS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: flags.map((f) => _buildFlagChip(f, theme)).toList(),
        ),
      ],
    );
  }

  Widget _buildFlagChip(_Flag flag, FluentThemeData theme) {
    if (flag.detected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFf87171).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFFf87171).withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.status_error_full,
                size: 12, color: Color(0xFFf87171)),
            const SizedBox(width: 6),
            Text(
              '${flag.name} Detected',
              style: const TextStyle(
                color: Color(0xFFf87171),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.completed, size: 12, color: Color(0xFF4ade80)),
          const SizedBox(width: 6),
          Text(
            'Not ${flag.name}',
            style: TextStyle(
              color: theme.resources.textFillColorPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Flag {
  final String name;
  final bool detected;
  const _Flag(this.name, this.detected);
}
