import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
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
                    Text(
                      'Not Scored Yet',
                      style: theme.typography.subtitle,
                    ),
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
    final scoreColor = getScoreColor(ip.ipScore);

    return Card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildScoreGauge(scoreColor),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreRow('Fraud Score', ip.fraudScore, Colors.red),
                    const SizedBox(height: 8),
                    _buildScoreRow(
                      'Abuse Confidence',
                      ip.abuseConfidence.toDouble(),
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildFlagsSection(theme),
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

  Widget _buildScoreGauge(AccentColor scoreColor) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scoreColor, width: 4),
        color: scoreColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ip.ipScore > 0 ? ip.ipScore.toStringAsFixed(0) : '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            Text(
              ip.scoreLevel.name.toUpperCase(),
              style: TextStyle(fontSize: 10, color: scoreColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagsSection(FluentThemeData theme) {
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

  Widget _buildBottomActions(BuildContext context, FluentThemeData theme) {
    return Row(
      children: [
        Text(
          'Last checked: ${ip.lastScoreCheck != null ? formatDate(ip.lastScoreCheck!) : 'Never'}',
          style: theme.typography.caption,
        ),
        const Spacer(),
        if (ip.ipScore > 0 && ip.ipScore < 50)
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

  Widget _buildScoreRow(String label, double value, AccentColor color) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: ProgressBar(
            value: value,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            activeColor: color,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
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
