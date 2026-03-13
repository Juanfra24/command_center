import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:command_center/feature/proxy/views/components/score_detail_table.dart';
import 'package:command_center/feature/proxy/views/components/score_flags.dart';
import 'package:command_center/feature/proxy/views/components/score_summary.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class IpScoreAnalysis extends StatelessWidget {
  final ProxyIpAddressEntity ip;
  final RxBool isReplacing;
  final VoidCallback onRefreshScore;
  final VoidCallback? onReplaceProxy;

  const IpScoreAnalysis({
    super.key,
    required this.ip,
    required this.isReplacing,
    required this.onRefreshScore,
    this.onReplaceProxy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (!ip.hasBeenScored) {
      return _buildNotScoredCard(theme);
    }

    return _buildScoredCard(context, theme);
  }

  Widget _buildNotScoredCard(FluentThemeData theme) {
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.grey, width: 2),
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Not Scored Yet', style: theme.typography.subtitle),
                    const SizedBox(height: 8),
                    Text(
                      'Click "Refresh Score" to analyze this IP address for VPN, proxy, and fraud detection.',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: onRefreshScore,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.shield, size: 14),
                    SizedBox(width: 8),
                    Text('Score IP'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoredCard(BuildContext context, FluentThemeData theme) {
    return Card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScoreSummary(ip: ip),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScoreDetailTable(ip: ip),
                    const SizedBox(height: 16),
                    ScoreFlags(ip: ip),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBottomActions(context, theme),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, FluentThemeData theme) {
    return Row(
      children: [
        Text(
          'Last checked: ${ip.lastScoreCheck != null ? formatDate(ip.lastScoreCheck!) : 'Never'}',
          style: theme.typography.caption,
        ),
        const Spacer(),
        if (ip.hasBeenScored && ip.ipScore < 50)
          Obx(() {
            final replacing = isReplacing.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.orange),
                ),
                onPressed: replacing ? null : onReplaceProxy,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replacing)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    else
                      const Icon(FluentIcons.switch_widget, size: 14),
                    const SizedBox(width: 8),
                    Text(replacing ? 'Replacing...' : 'Replace Proxy'),
                  ],
                ),
              ),
            );
          }),
        Button(
          onPressed: onRefreshScore,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 14),
              SizedBox(width: 8),
              Text('Refresh Score'),
            ],
          ),
        ),
      ],
    );
  }
}
