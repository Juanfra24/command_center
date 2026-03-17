import 'package:command_center/feature/main_menu/data/bot_tile_data.dart';
import 'package:fluent_ui/fluent_ui.dart';

class BotStatusTile extends StatelessWidget {
  final BotTileData tile;
  final VoidCallback? onTap;

  const BotStatusTile({super.key, required this.tile, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final borderColor = _statusColor(context);

    Widget card = Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: theme.resources.controlStrokeColorDefault),
          right: BorderSide(color: theme.resources.controlStrokeColorDefault),
          bottom: BorderSide(color: theme.resources.controlStrokeColorDefault),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 6),
          _buildProxyRow(theme),
          const SizedBox(height: 4),
          _buildFooter(theme, borderColor),
        ],
      ),
    );

    if (onTap != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }

    return card;
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tile.characterName,
          style: theme.typography.bodyStrong,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          tile.defaultScriptName ?? 'No script',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildProxyRow(FluentThemeData theme) {
    final parts = <String>[];
    if (tile.proxySlotName != null) parts.add(tile.proxySlotName!);
    if (tile.countryCode != null) parts.add(tile.countryCode!.toUpperCase());

    return Row(
      children: [
        Icon(
          FluentIcons.globe,
          size: 12,
          color: theme.resources.textFillColorSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.isNotEmpty ? parts.join(' · ') : '—',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(FluentThemeData theme, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatusBadge(theme, statusColor),
        Text(
          _formatUptime(),
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(FluentThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusLabel(),
        style: theme.typography.caption?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    return switch (tile.status) {
      'running' => Colors.green,
      'restarting' => Colors.orange,
      'banned' => Colors.red,
      _ => const Color(0xFF888888),
    };
  }

  String _statusLabel() {
    return switch (tile.status) {
      'running' => 'Running',
      'restarting' => 'Restarting',
      'banned' => 'Banned',
      _ => 'Stopped',
    };
  }

  String _formatUptime() {
    final uptime = tile.uptime;
    if (uptime == null) return '—';
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
