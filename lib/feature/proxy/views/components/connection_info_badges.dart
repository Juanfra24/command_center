import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Displays location, provider, connection-type, and age badges for a proxy IP.
class ConnectionInfoBadges extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const ConnectionInfoBadges({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final locationParts = [
      if (ip.cityName.isNotEmpty) ip.cityName,
      if ((ip.region ?? '').isNotEmpty) ip.region!,
      if (ip.countryCode.isNotEmpty) ip.countryCode,
    ];
    final location = locationParts.join(', ');
    final provider = ip.isp ?? ip.asnName;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (location.isNotEmpty)
          _buildBadge(FluentIcons.location, location, theme),
        if (provider.isNotEmpty)
          _buildBadge(FluentIcons.network_tower, provider, theme),
        if ((ip.connectionType ?? '').isNotEmpty)
          _buildConnectionTypeBadge(ip.connectionType!, theme),
        _buildBadge(FluentIcons.clock, _relativeTime(ip.assignedAt), theme),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: theme.resources.textFillColorSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTypeBadge(String type, FluentThemeData theme) {
    final color = _connectionTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _connectionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'residential':
        return const Color(0xFF4ade80);
      case 'mobile':
        return const Color(0xFF60a5fa);
      case 'corporate':
        return const Color(0xFFa78bfa);
      case 'datacenter':
        return const Color(0xFFf87171);
      default:
        return const Color(0xFF94a3b8);
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
