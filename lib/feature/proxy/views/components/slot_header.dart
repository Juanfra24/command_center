import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/views/components/connection_info_badges.dart';
import 'package:command_center/feature/proxy/views/components/slot_action_buttons.dart';
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
  final AutomationService automationService;

  const SlotHeader({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.isReplacing,
    required this.getCurrentIpForSlot,
    required this.onShowReplaceDialog,
    required this.onLaunchBrowser,
    required this.onShowChangeIpDialog,
    required this.automationService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final ip = currentIp;
    final highFraud = ip != null && ip.hasBeenScored && ip.fraudScore > 60;

    return Container(
      decoration: BoxDecoration(
        border: highFraud
            ? Border(
                left: BorderSide(
                  color: Colors.red.withValues(alpha: 0.8),
                  width: 4,
                ),
              )
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Card(
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
                          _buildStatusBadge(slot),
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
            if (ip != null) ...[
              const SizedBox(height: 10),
              ConnectionInfoBadges(ip: ip),
            ],
            if (highFraud) ...[
              const SizedBox(height: 10),
              InfoBar(
                title: Text(
                  'High fraud risk: ${ip.fraudScore.round()} — consider replacing this IP',
                ),
                severity: InfoBarSeverity.warning,
                isLong: false,
              ),
            ],
            const SizedBox(height: 12),
            SlotActionButtons(
              slot: slot,
              isReplacing: isReplacing,
              getCurrentIpForSlot: getCurrentIpForSlot,
              onShowReplaceDialog: onShowReplaceDialog,
              onLaunchBrowser: onLaunchBrowser,
              onShowChangeIpDialog: onShowChangeIpDialog,
              automationService: automationService,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ProxySlotEntity slot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }
}
