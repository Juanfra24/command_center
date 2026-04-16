import 'package:command_center/config/theme/status_colors.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:fluent_ui/fluent_ui.dart';

class IpHistoryList extends StatelessWidget {
  final List<ProxyIpAddressEntity> history;

  const IpHistoryList({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (history.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(FluentIcons.history,
                    size: 32, color: theme.resources.textFillColorSecondary),
                const SizedBox(height: 8),
                Text('No IP history yet', style: theme.typography.body),
                const SizedBox(height: 4),
                Text(
                  'IP changes will appear here after rotation.',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayedHistory = history.take(10).toList();
    final isTruncated = history.length > 10;

    return Card(
      child: Column(
        children: [
          ...displayedHistory.map((ip) {
            final scoreColor =
                getScoreColor(ip.fraudScore, hasBeenScored: ip.hasBeenScored);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Builder(builder: (context) {
                    final colors = StatusColors.of(context);
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ip.isActive ? colors.success : colors.muted,
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ip.ipAddress,
                          style: theme.typography.bodyStrong,
                        ),
                        Text(
                          '${ip.cityName}, ${ip.countryCode}',
                          style: theme.typography.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ip.hasBeenScored ? ip.fraudScore.toStringAsFixed(0) : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: Text(
                      formatDate(ip.assignedAt),
                      style: theme.typography.caption,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  if (!ip.isActive && ip.removedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '→ ${formatDate(ip.removedAt!)}',
                      style: theme.typography.caption,
                    ),
                  ],
                ],
              ),
            );
          }),
          if (isTruncated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing 10 of ${history.length} entries',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
