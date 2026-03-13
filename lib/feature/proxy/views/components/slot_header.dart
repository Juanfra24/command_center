import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SlotHeader extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity? currentIp;
  final RxBool isReplacing;
  final ProxyIpAddressEntity? Function(ProxySlotEntity) getCurrentIpForSlot;
  final void Function(
          BuildContext context, ProxySlotEntity slot, ProxyIpAddressEntity ip)
      onShowReplaceDialog;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onLaunchBrowser;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onShowChangeIpDialog;

  const SlotHeader({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.isReplacing,
    required this.getCurrentIpForSlot,
    required this.onShowReplaceDialog,
    required this.onLaunchBrowser,
    required this.onShowChangeIpDialog,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '#${slot.slotNumber}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot.slotName, style: theme.typography.title),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: slot.isActive
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slot.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              color: slot.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                        Text(
                          '${slot.totalIpChanges} IP changes',
                          style: theme.typography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _buildReplaceButton(context),
              _buildLaunchBrowserButton(context),
              FilledButton(
                onPressed: () => onShowChangeIpDialog(context, slot),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.switch_widget, size: 16),
                    SizedBox(width: 8),
                    Text('Change IP'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplaceButton(BuildContext context) {
    return Obx(() {
      final replacing = isReplacing.value;
      return Builder(
        builder: (context) {
          final ip = getCurrentIpForSlot(slot);
          if (ip != null && ip.hasBeenScored && ip.ipScore < 50) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.orange),
                ),
                onPressed: replacing
                    ? null
                    : () => onShowReplaceDialog(context, slot, ip),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replacing)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    else
                      const Icon(FluentIcons.switch_widget, size: 16),
                    const SizedBox(width: 8),
                    Text(replacing ? 'Replacing...' : 'Replace'),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    });
  }

  Widget _buildLaunchBrowserButton(BuildContext context) {
    return Obx(() {
      final automationService = Get.find<AutomationService>();
      final isRunning = automationService.isRunning.value;
      return Button(
        onPressed: isRunning ? null : () => onLaunchBrowser(context, slot),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRunning)
              const SizedBox(
                width: 14,
                height: 14,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              const Icon(FluentIcons.globe, size: 16),
            const SizedBox(width: 8),
            Text(isRunning ? 'Launching...' : 'Launch Browser'),
          ],
        ),
      );
    });
  }
}

