import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ProxySlotCardHeader extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity? currentIp;
  final bool isSelected;
  final bool isEditing;
  final TextEditingController editingNameController;
  final VoidCallback onStartEditing;
  final VoidCallback onSaveSlotName;
  final VoidCallback onCancelEditing;

  const ProxySlotCardHeader({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.isSelected,
    required this.isEditing,
    required this.editingNameController,
    required this.onStartEditing,
    required this.onSaveSlotName,
    required this.onCancelEditing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentColor.withValues(alpha: 0.3)
                : (slot.isActive
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: theme.accentColor, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              '#${slot.slotNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.accentColor
                    : (slot.isActive ? Colors.green : Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSlotNameRow(theme),
              Text(
                currentIp?.ipAddress ?? 'No IP assigned',
                style: theme.typography.caption,
              ),
            ],
          ),
        ),
        if (currentIp != null) _buildScoreBadge(currentIp!),
      ],
    );
  }

  Widget _buildSlotNameRow(FluentThemeData theme) {
    if (isEditing) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextBox(
                controller: editingNameController,
                autofocus: true,
                placeholder: 'Slot name',
                style: theme.typography.bodyStrong,
                onSubmitted: (_) => onSaveSlotName(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.check_mark, size: 14),
            onPressed: onSaveSlotName,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Colors.green.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(FluentIcons.cancel, size: 14),
            onPressed: onCancelEditing,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Colors.red.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          slot.slotName,
          style: theme.typography.bodyStrong?.copyWith(
            color: isSelected ? theme.accentColor : null,
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(FluentIcons.edit, size: 12, color: theme.inactiveColor),
          onPressed: onStartEditing,
        ),
        if (isSelected) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Selected',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScoreBadge(ProxyIpAddressEntity ip) {
    final color = getScoreColor(ip.fraudScore, hasBeenScored: ip.hasBeenScored);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        ip.hasBeenScored ? ip.fraudScore.toStringAsFixed(0) : '?',
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
