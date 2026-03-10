import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ProxySlotCard extends StatefulWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity? currentIp;
  final bool isSelected;
  final VoidCallback onSelect;
  final Future<bool> Function(ProxySlotEntity slot, String newName)
      onUpdateSlotName;

  const ProxySlotCard({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.isSelected,
    required this.onSelect,
    required this.onUpdateSlotName,
  });

  @override
  State<ProxySlotCard> createState() => _ProxySlotCardState();
}

class _ProxySlotCardState extends State<ProxySlotCard> {
  bool _isEditing = false;
  final _editingNameController = TextEditingController();

  @override
  void dispose() {
    _editingNameController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editingNameController.text = widget.slot.slotName;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingNameController.clear();
    });
  }

  Future<void> _saveSlotName() async {
    final newName = _editingNameController.text.trim();
    if (newName.isEmpty) {
      _cancelEditing();
      return;
    }

    final success = await widget.onUpdateSlotName(widget.slot, newName);
    if (success) {
      setState(() {
        _isEditing = false;
        _editingNameController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final slot = widget.slot;
    final currentIp = widget.currentIp;
    final isSelected = widget.isSelected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accentColor.withValues(alpha: 0.15)
                  : theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? theme.accentColor
                    : theme.resources.dividerStrokeColorDefault,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          _buildSlotNameRow(slot, isSelected, theme),
                          Text(
                            currentIp?.ipAddress ?? 'No IP assigned',
                            style: theme.typography.caption,
                          ),
                        ],
                      ),
                    ),
                    if (currentIp != null) _buildScoreBadge(currentIp),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSlotInfoChip(
                      icon: FluentIcons.refresh,
                      label: '${slot.totalIpChanges} changes',
                    ),
                    const SizedBox(width: 8),
                    if (currentIp != null)
                      _buildSlotInfoChip(
                        icon: FluentIcons.globe,
                        label: currentIp.countryCode,
                      ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotNameRow(
      ProxySlotEntity slot, bool isSelected, FluentThemeData theme) {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextBox(
                controller: _editingNameController,
                autofocus: true,
                placeholder: 'Slot name',
                style: theme.typography.bodyStrong,
                onSubmitted: (_) => _saveSlotName(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.check_mark, size: 14),
            onPressed: _saveSlotName,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Colors.green.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(FluentIcons.cancel, size: 14),
            onPressed: _cancelEditing,
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
          icon: Icon(
            FluentIcons.edit,
            size: 12,
            color: theme.inactiveColor,
          ),
          onPressed: _startEditing,
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
    final color =
        getScoreColor(ip.ipScore, hasBeenScored: ip.hasBeenScored);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        ip.hasBeenScored ? ip.ipScore.toStringAsFixed(0) : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSlotInfoChip(
      {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
