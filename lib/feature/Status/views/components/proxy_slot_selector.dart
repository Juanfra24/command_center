import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxySlotSelector extends StatelessWidget {
  final List<int?> availableSlots;
  final ValueNotifier<int?> selectedSlot;
  final ValueNotifier<AutomationResult?> validationResult;

  const ProxySlotSelector({
    super.key,
    required this.availableSlots,
    required this.selectedSlot,
    required this.validationResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return InfoLabel(
      label: 'Select Proxy Slot',
      child: ValueListenableBuilder<int?>(
        valueListenable: selectedSlot,
        builder: (context, value, _) {
          return ComboBox<int>(
            value: value,
            isExpanded: true,
            items: availableSlots
                .where((id) => id != null)
                .map((slotId) => _buildSlotItem(theme, slotId!))
                .toList(),
            onChanged: (value) {
              selectedSlot.value = value;
              validationResult.value = null;
            },
            placeholder: const Text('Select a proxy slot'),
          );
        },
      ),
    );
  }

  ComboBoxItem<int> _buildSlotItem(FluentThemeData theme, int slotId) {
    String slotName = 'Slot $slotId';
    String ipAddress = 'No IP';

    try {
      final proxyController = Get.find<ProxyController>();
      final slot =
          proxyController.proxySlots.firstWhere((s) => s.id == slotId);
      slotName = slot.slotName;

      final currentIp = proxyController.getCurrentIpForSlot(slot);
      if (currentIp != null) {
        ipAddress = currentIp.ipAddress;
      }
    } catch (_) {}

    return ComboBoxItem(
      value: slotId,
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '#$slotId',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: theme.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$slotName - $ipAddress',
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body?.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
