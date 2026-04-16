import 'package:command_center/config/theme/status_colors.dart';
import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/main_menu/data/proxy_health_data.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxyHealthOverviewSection extends StatelessWidget {
  final VoidCallback? onNavigateToProxies;

  const ProxyHealthOverviewSection({super.key, this.onNavigateToProxies});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainMenuController>();

    return Obx(() {
      final health = controller.proxyHealth.value;

      // Hidden when all proxies are healthy (no poor/bad/unscored)
      if (health.totalCount == 0) return const SizedBox.shrink();
      final hasIssues = health.poorCount > 0 ||
          health.badCount > 0 ||
          health.unscoredCount > 0;
      if (!hasIssues) return const SizedBox.shrink();

      return _buildContent(context, health);
    });
  }

  Widget _buildContent(BuildContext context, ProxyHealthData health) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        const SizedBox(height: 12),
        _buildHealthBar(context, health),
        const SizedBox(height: 8),
        _buildLegend(context, theme, health),
        if (health.attentionItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAttentionCard(context, health),
        ],
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        Text('Proxy Health', style: theme.typography.subtitle),
        const Spacer(),
        if (onNavigateToProxies != null)
          HyperlinkButton(
            onPressed: onNavigateToProxies,
            child: Text(
              'View Proxies →',
              style: theme.typography.caption?.copyWith(
                color: theme.accentColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHealthBar(BuildContext context, ProxyHealthData health) {
    final total = health.totalCount;
    if (total == 0) return const SizedBox.shrink();
    final colors = StatusColors.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (health.excellentCount > 0)
              Expanded(
                flex: health.excellentCount,
                child: Tooltip(
                  message: 'Excellent: ${health.excellentCount}',
                  child: Container(color: colors.success),
                ),
              ),
            if (health.fairCount > 0)
              Expanded(
                flex: health.fairCount,
                child: Tooltip(
                  message: 'Fair: ${health.fairCount}',
                  child: Container(color: colors.fair),
                ),
              ),
            if (health.poorCount > 0)
              Expanded(
                flex: health.poorCount,
                child: Tooltip(
                  message: 'Poor: ${health.poorCount}',
                  child: Container(color: colors.warning),
                ),
              ),
            if (health.badCount > 0)
              Expanded(
                flex: health.badCount,
                child: Tooltip(
                  message: 'Bad: ${health.badCount}',
                  child: Container(color: colors.error),
                ),
              ),
            if (health.unscoredCount > 0)
              Expanded(
                flex: health.unscoredCount,
                child: Tooltip(
                  message: 'Unscored: ${health.unscoredCount}',
                  child: Container(color: colors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(
      BuildContext context, FluentThemeData theme, ProxyHealthData health) {
    final colors = StatusColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (health.excellentCount > 0)
          _legendItem(
              theme, colors.success, 'Excellent', health.excellentCount),
        if (health.fairCount > 0)
          _legendItem(theme, colors.fair, 'Fair', health.fairCount),
        if (health.poorCount > 0)
          _legendItem(theme, colors.warning, 'Poor', health.poorCount),
        if (health.badCount > 0)
          _legendItem(theme, colors.error, 'Bad', health.badCount),
        if (health.unscoredCount > 0)
          _legendItem(theme, colors.muted, 'Unscored', health.unscoredCount),
      ],
    );
  }

  Widget _legendItem(
    FluentThemeData theme,
    Color color,
    String label,
    int count,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: theme.typography.caption,
        ),
      ],
    );
  }

  Widget _buildAttentionCard(BuildContext context, ProxyHealthData health) {
    final theme = FluentTheme.of(context);
    final colors = StatusColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningBg(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.warningBg(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.warning, size: 14, color: colors.warning),
              const SizedBox(width: 6),
              Text(
                'Needs Attention',
                style: theme.typography.bodyStrong?.copyWith(
                  color: colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in health.attentionItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildAttentionItemRow(context, theme, item),
            ),
        ],
      ),
    );
  }

  Widget _buildAttentionItemRow(
    BuildContext context,
    FluentThemeData theme,
    ProxyAttentionItem item,
  ) {
    final colors = StatusColors.of(context);
    final scoreText = item.isUnscored
        ? 'Unscored'
        : item.fraudScore != null
            ? 'Score: ${item.fraudScore!.toStringAsFixed(0)}'
            : '';

    return Row(
      children: [
        Expanded(
          child: Text(
            item.slotName,
            style: theme.typography.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          scoreText,
          style: theme.typography.caption?.copyWith(
            color: item.isUnscored ? colors.muted : colors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (item.connectionType != null) ...[
          const SizedBox(width: 8),
          Text(
            item.connectionType!,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
