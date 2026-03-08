import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class MainMenuScreen extends GetView<MainMenuController> {
  final void Function(int index)? onNavigateToIndex;

  const MainMenuScreen({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Overview')),
      children: [
        // System Overview Card - Main focus
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.view_dashboard, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'System Overview',
                    style: theme.typography.subtitle,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildOverviewStats(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Characters Status Card
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.people, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Characters Status',
                    style: theme.typography.subtitle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCharacterStatusSection(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Recent Activity Card
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.history, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Activity',
                    style: theme.typography.subtitle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRecentActivityPlaceholder(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterStatusSection(BuildContext context) {
    final counts = _getCharacterCounts();

    return Row(
      children: [
        Expanded(
          child: _buildCharacterStatusCard(
            context,
            icon: FluentIcons.play_solid,
            label: 'Running',
            count: counts['running'] ?? 0,
            total: counts['total'] ?? 0,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCharacterStatusCard(
            context,
            icon: FluentIcons.pause,
            label: 'Stopped',
            count: counts['stopped'] ?? 0,
            total: counts['total'] ?? 0,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCharacterStatusCard(
            context,
            icon: FluentIcons.people,
            label: 'Total',
            count: counts['total'] ?? 0,
            total: counts['total'] ?? 0,
            color: Colors.blue,
            showProgress: false,
          ),
        ),
      ],
    );
  }

  Map<String, int> _getCharacterCounts() {
    try {
      final statusController = Get.find<StatusController>();
      final accounts = statusController.accountList;
      final total = accounts.length;

      // Count running processes
      final runningProcesses = statusController.processClients;
      int running = 0;

      for (final account in accounts) {
        // Check if any of this account's characters have a running process
        for (final character in account.characters) {
          if (runningProcesses.containsKey(character.name)) {
            final processInfo = runningProcesses[character.name];
            if (processInfo != null && processInfo.processId > 0) {
              running++;
            }
          }
        }
      }

      return {
        'total': total,
        'running': running,
        'stopped': total - running,
      };
    } catch (_) {
      return {'total': 0, 'running': 0, 'stopped': 0};
    }
  }

  Widget _buildCharacterStatusCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required int total,
    required AccentColor color,
    bool showProgress = true,
  }) {
    final theme = FluentTheme.of(context);
    final percentage =
        total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.typography.bodyStrong?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count.toString(),
                style: theme.typography.title?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showProgress) ...[
                Text(
                  ' / $total',
                  style: theme.typography.body?.copyWith(
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Text(
                  '$percentage%',
                  style: theme.typography.caption?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ProgressBar(
              value: total > 0 ? (count / total * 100) : 0,
              backgroundColor: color.withValues(alpha: 0.2),
              activeColor: color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewStats(BuildContext context) {
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
      return scoringController.lowScoreCount.toString();
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

  Widget _buildRecentActivityPlaceholder(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              FluentIcons.history,
              size: 32,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'No recent activity',
              style: theme.typography.caption,
            ),
          ],
        ),
      ),
    );
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
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.typography.title?.copyWith(color: color),
          ),
          Text(
            label,
            style: theme.typography.caption,
          ),
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
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}
