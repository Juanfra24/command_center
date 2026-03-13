import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SystemOverviewSection extends StatelessWidget {
  final void Function(int)? onNavigateToIndex;

  const SystemOverviewSection({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: FluentIcons.server,
            label: 'Total Accounts',
            value: _getAccountCount(),
            color: Colors.blue,
            onTap: () => onNavigateToIndex?.call(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            icon: FluentIcons.globe,
            label: 'Proxy Slots',
            value: _getProxyCount(),
            color: Colors.green,
            onTap: () => onNavigateToIndex?.call(2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            icon: FluentIcons.warning,
            label: 'Issues',
            value: _getIssuesCount(),
            color: Colors.red,
            onTap: () => onNavigateToIndex?.call(2),
            tooltip: _getIssuesTooltip(),
          ),
        ),
      ],
    );
  }

  String _getAccountCount() {
    try {
      final controller = Get.find<StatusController>();
      return controller.accountList.length.toString();
    } catch (_) {
      return '--';
    }
  }

  String _getProxyCount() {
    try {
      final controller = Get.find<ProxyController>();
      return controller.totalSlots.toString();
    } catch (_) {
      return '--';
    }
  }

  String _getIssuesCount() {
    try {
      final scoringController = Get.find<ProxyScoringController>();
      return scoringController.lowScoreCount.value.toString();
    } catch (_) {
      return '0';
    }
  }

  String? _getIssuesTooltip() {
    try {
      final scoringController = Get.find<ProxyScoringController>();
      final details = scoringController.getLowScoreSlotDetails();
      if (details.isEmpty) return null;
      return 'Low score proxies:\n${details.join('\n')}';
    } catch (_) {
      return null;
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required AccentColor color,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final theme = FluentTheme.of(context);

    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: theme.typography.title?.copyWith(color: color)),
          Text(label, style: theme.typography.caption),
        ],
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      card = Tooltip(
        message: tooltip,
        style: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 300),
        ),
        child: card,
      );
    }

    if (onTap != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }

    return card;
  }
}
