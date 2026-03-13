import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ScoreFlags extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const ScoreFlags({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              FluentIcons.info,
              size: 12,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'IP Quality Flags (hover for details)',
              style: TextStyle(
                fontSize: 11,
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFlagChip('VPN', ip.isVpn, tooltip: _getFlagTooltip('VPN')),
            _buildFlagChip('Proxy', ip.isProxy,
                tooltip: _getFlagTooltip('Proxy')),
            _buildFlagChip('Datacenter', ip.isDatacenter,
                tooltip: _getFlagTooltip('Datacenter')),
            _buildFlagChip('Tor', ip.isTor, tooltip: _getFlagTooltip('Tor')),
          ],
        ),
      ],
    );
  }

  Widget _buildFlagChip(String label, bool isActive, {String? tooltip}) {
    final color = isActive ? Colors.red : Colors.green;
    final icon = isActive ? FluentIcons.warning : FluentIcons.check_mark;
    final statusText = isActive ? 'Detected' : 'Not detected';

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        style: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 300),
        ),
        child: chip,
      );
    }

    return chip;
  }

  String _getFlagTooltip(String flag) {
    switch (flag) {
      case 'VPN':
        return 'VPN Detection\n'
            'Indicates if this IP is from a VPN service.\n'
            'Red = VPN detected (may be flagged by websites)\n'
            'Green = No VPN detected (appears as regular connection)';
      case 'Proxy':
        return 'Proxy Detection\n'
            'Indicates if this IP is identified as a proxy server.\n'
            'Red = Proxy detected (higher risk of blocks)\n'
            'Green = No proxy detected (better for automation)';
      case 'Datacenter':
        return 'Datacenter IP\n'
            'Indicates if this IP originates from a datacenter.\n'
            'Red = Datacenter IP (often blocked by anti-bot systems)\n'
            'Green = Residential/ISP IP (more trusted)';
      case 'Tor':
        return 'Tor Network\n'
            'Indicates if this IP is a known Tor exit node.\n'
            'Red = Tor detected (highest risk, often blocked)\n'
            'Green = Not Tor (normal network connection)';
      default:
        return flag;
    }
  }
}
