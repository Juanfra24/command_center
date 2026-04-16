import 'package:command_center/config/theme/status_colors.dart';
import 'package:command_center/core/widgets/loading_button.dart';
import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/main_menu/views/components/bot_status_tile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class BotStatusGridSection extends StatelessWidget {
  final VoidCallback? onNavigateToAccounts;
  final Future<void> Function() onStartAll;
  final Future<void> Function() onStopAll;

  const BotStatusGridSection({
    super.key,
    this.onNavigateToAccounts,
    required this.onStartAll,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainMenuController>();
    final theme = FluentTheme.of(context);

    return Obx(() {
      final tiles = controller.botTiles;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, theme, controller),
          const SizedBox(height: 12),
          if (tiles.isEmpty)
            _buildEmptyState(theme)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tile in tiles)
                  BotStatusTile(
                    tile: tile,
                    onTap: onNavigateToAccounts,
                  ),
              ],
            ),
        ],
      );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    FluentThemeData theme,
    MainMenuController controller,
  ) {
    final colors = StatusColors.of(context);
    return Row(
      children: [
        Text('Bot Farm Status', style: theme.typography.subtitle),
        const SizedBox(width: 12),
        _buildCountBadge(
          theme,
          label: 'Running',
          count: controller.botTiles.where((t) => t.status == 'running').length,
          color: colors.success,
        ),
        const SizedBox(width: 6),
        _buildCountBadge(
          theme,
          label: 'Stopped',
          count: controller.botTiles.where((t) => t.status == 'stopped').length,
          color: colors.muted,
        ),
        const SizedBox(width: 6),
        _buildCountBadge(
          theme,
          label: 'Banned',
          count: controller.botTiles.where((t) => t.status == 'banned').length,
          color: colors.error,
        ),
        const Spacer(),
        LoadingButton(
          label: 'Start All',
          loadingLabel: 'Starting…',
          icon: FluentIcons.play_solid,
          onPressed: onStartAll,
          style: LoadingButtonStyle.filled,
        ),
        const SizedBox(width: 8),
        LoadingButton(
          label: 'Stop All',
          loadingLabel: 'Stopping…',
          icon: FluentIcons.stop_solid,
          onPressed: () => _confirmStopAll(context),
          style: LoadingButtonStyle.outline,
        ),
      ],
    );
  }

  Future<void> _confirmStopAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Stop All Characters'),
        content: const Text(
          'This will stop all running bot processes. Are you sure?',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          Button(
            style: ButtonStyle(
              foregroundColor:
                  WidgetStatePropertyAll(StatusColors.of(ctx).error),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop All'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onStopAll();
  }

  Widget _buildCountBadge(
    FluentThemeData theme, {
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: theme.typography.caption?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              FluentIcons.people,
              size: 32,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'No characters found',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create characters in the Accounts page to see them here.',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            if (onNavigateToAccounts != null) ...[
              const SizedBox(height: 12),
              HyperlinkButton(
                onPressed: onNavigateToAccounts,
                child: const Text('Go to Accounts'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
