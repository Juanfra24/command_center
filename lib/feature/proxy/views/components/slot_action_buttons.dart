import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Action buttons for a proxy slot: Replace, Launch Browser, Change IP.
class SlotActionButtons extends StatelessWidget {
  final ProxySlotEntity slot;
  final RxBool isReplacing;
  final ProxyIpAddressEntity? Function(ProxySlotEntity) getCurrentIpForSlot;
  final void Function(
          BuildContext context, ProxySlotEntity slot, ProxyIpAddressEntity ip)
      onShowReplaceDialog;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onLaunchBrowser;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onShowChangeIpDialog;
  final AutomationService automationService;

  const SlotActionButtons({
    super.key,
    required this.slot,
    required this.isReplacing,
    required this.getCurrentIpForSlot,
    required this.onShowReplaceDialog,
    required this.onLaunchBrowser,
    required this.onShowChangeIpDialog,
    required this.automationService,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
    );
  }

  Widget _buildReplaceButton(BuildContext context) {
    return Obx(() {
      final replacing = isReplacing.value;
      return Builder(
        builder: (context) {
          final ip = getCurrentIpForSlot(slot);
          if (ip != null && ip.hasBeenScored && ip.fraudScore > 60) {
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
                          child: ProgressRing(strokeWidth: 2))
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
      final isRunning = automationService.isRunning.value;
      return Button(
        onPressed: isRunning ? null : () => onLaunchBrowser(context, slot),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRunning)
              const SizedBox(
                  width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
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
