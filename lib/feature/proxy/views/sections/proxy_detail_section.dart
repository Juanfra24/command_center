import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/views/components/ip_history_list.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_analysis.dart';
import 'package:command_center/feature/proxy/views/components/current_ip_card.dart';
import 'package:command_center/feature/proxy/views/components/slot_header.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxyDetailSection extends StatelessWidget {
  final ProxyController controller;
  final RxBool isReplacing;
  final void Function(
          BuildContext context, ProxySlotEntity slot, ProxyIpAddressEntity ip)
      onShowReplaceDialog;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onLaunchBrowser;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onShowChangeIpDialog;
  final void Function(ProxyIpAddressEntity ip) onRefreshIpScore;

  const ProxyDetailSection({
    super.key,
    required this.controller,
    required this.isReplacing,
    required this.onShowReplaceDialog,
    required this.onLaunchBrowser,
    required this.onShowChangeIpDialog,
    required this.onRefreshIpScore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Obx(() {
      final selectedSlot = controller.selectedSlot.value;

      if (selectedSlot == null) {
        return _buildEmptyState(theme);
      }

      final currentIp = controller.getCurrentIpForSlot(selectedSlot);
      final ipHistory = controller.selectedSlotIpHistory;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SlotHeader(
              slot: selectedSlot,
              currentIp: currentIp,
              isReplacing: isReplacing,
              getCurrentIpForSlot: controller.getCurrentIpForSlot,
              onShowReplaceDialog: onShowReplaceDialog,
              onLaunchBrowser: onLaunchBrowser,
              onShowChangeIpDialog: onShowChangeIpDialog,
            ),
            const SizedBox(height: 24),
            if (currentIp != null) ...[
              Text('Current IP Details', style: theme.typography.subtitle),
              const SizedBox(height: 12),
              CurrentIpCard(ip: currentIp),
              const SizedBox(height: 24),
            ],
            if (currentIp != null) ...[
              Text('IP Score Analysis', style: theme.typography.subtitle),
              const SizedBox(height: 12),
              IpScoreAnalysis(
                ip: currentIp,
                isReplacing: isReplacing,
                onRefreshScore: () => onRefreshIpScore(currentIp),
                onReplaceProxy: () {
                  onShowReplaceDialog(context, selectedSlot, currentIp);
                },
              ),
              const SizedBox(height: 24),
            ],
            Text('IP History', style: theme.typography.subtitle),
            const SizedBox(height: 12),
            IpHistoryList(history: ipHistory),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.info,
            size: 64,
            color: theme.accentColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a proxy slot',
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Click on a slot from the list to view its details',
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }
}
