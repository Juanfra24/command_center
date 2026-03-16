import 'package:fluent_ui/fluent_ui.dart';
import 'package:command_center/core/widgets/loading_button.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/detection_flag_chips.dart';

class FraudAnalysis extends StatelessWidget {
  final ProxyIpAddressEntity ip;
  final Future<void> Function() onRefreshScore;
  final Future<void> Function() onScoreIp;

  const FraudAnalysis({
    super.key,
    required this.ip,
    required this.onRefreshScore,
    required this.onScoreIp,
  });

  @override
  Widget build(BuildContext context) {
    if (!ip.hasBeenScored) return _buildNotScored(context);
    return _buildScored(context);
  }

  Widget _buildNotScored(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
                width: 3,
              ),
            ),
            child: Center(
              child: Text('?',
                  style: theme.typography.title?.copyWith(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Not Scored Yet', style: theme.typography.bodyStrong),
          const SizedBox(height: 4),
          Text(
            'Run an IPQS fraud check to analyze this IP',
            style: theme.typography.caption,
          ),
          const SizedBox(height: 12),
          LoadingButton(
            label: 'Score IP',
            loadingLabel: 'Scoring...',
            successLabel: 'Scored',
            onPressed: onScoreIp,
          ),
        ],
      ),
    );
  }

  Widget _buildScored(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFraudCircle(theme),
            const SizedBox(width: 20),
            Expanded(child: DetectionFlagChips(ip: ip)),
          ],
        ),
        const SizedBox(height: 14),
        Divider(
          style: DividerThemeData(
            horizontalMargin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Last checked: ${_formatDate(ip.lastScoreCheck)}',
              style: theme.typography.caption,
            ),
            LoadingButton(
              label: 'Refresh Score',
              loadingLabel: 'Refreshing...',
              successLabel: 'Refreshed',
              style: LoadingButtonStyle.outline,
              onPressed: onRefreshScore,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFraudCircle(FluentThemeData theme) {
    final color = _fraudScoreColor(ip.fraudScore);

    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ip.fraudScore.round().toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'FRAUD RISK',
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '0 = clean, 100 = fraud',
          style: TextStyle(
            fontSize: 9,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ],
    );
  }

  Color _fraudScoreColor(double score) {
    if (score <= 30) return const Color(0xFF4ade80);
    if (score <= 60) return const Color(0xFFfbbf24);
    if (score <= 80) return const Color(0xFFfb923c);
    return const Color(0xFFf87171);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
