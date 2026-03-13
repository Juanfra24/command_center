import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/views/components/proxy_slot_card_body.dart';
import 'package:command_center/feature/proxy/views/components/proxy_slot_card_header.dart';
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
                ProxySlotCardHeader(
                  slot: widget.slot,
                  currentIp: widget.currentIp,
                  isSelected: isSelected,
                  isEditing: _isEditing,
                  editingNameController: _editingNameController,
                  onStartEditing: _startEditing,
                  onSaveSlotName: _saveSlotName,
                  onCancelEditing: _cancelEditing,
                ),
                const SizedBox(height: 8),
                ProxySlotCardBody(
                  slot: widget.slot,
                  currentIp: widget.currentIp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
