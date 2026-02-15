import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class MainMenuScreen extends GetView<MainMenuController> {
  const MainMenuScreen({super.key});

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
        // Quick Actions Card
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.lightning_bolt, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: theme.typography.subtitle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildQuickActionButton(
                    context,
                    icon: FluentIcons.refresh,
                    label: 'Sync Proxies',
                    onPressed: () {
                      try {
                        final proxyController = Get.find<ProxyController>();
                        proxyController.loadData();
                      } catch (_) {}
                    },
                  ),
                  _buildQuickActionButton(
                    context,
                    icon: FluentIcons.server,
                    label: 'Refresh Accounts',
                    onPressed: () {
                      try {
                        final statusController = Get.find<StatusController>();
                        statusController.getAccountsData();
                      } catch (_) {}
                    },
                  ),
                  _buildQuickActionButton(
                    context,
                    icon: FluentIcons.play,
                    label: 'Start All Bots',
                    onPressed: () {
                      // TODO: Implement start all bots
                    },
                    isPrimary: true,
                  ),
                  _buildQuickActionButton(
                    context,
                    icon: FluentIcons.stop,
                    label: 'Stop All Bots',
                    onPressed: () {
                      // TODO: Implement stop all bots
                    },
                    isDanger: true,
                  ),
                ],
              ),
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
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            icon: FluentIcons.play,
            label: 'Running',
            value: _getRunningCount(),
            color: Colors.orange,
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

  String _getRunningCount() {
    // TODO: Implement running bots count
    return '--';
  }

  String _getIssuesCount() {
    try {
      final controller = Get.find<ProxyController>();
      return controller.lowScoreCount.toString();
    } catch (_) {
      return '0';
    }
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    if (isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );
    }

    if (isDanger) {
      return Button(
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.red),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    return Button(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
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
  }) {
    final theme = FluentTheme.of(context);

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
  }
}
