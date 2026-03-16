import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/core/widgets/collapsible_section.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/views/components/fraud_analysis.dart';
import 'package:command_center/feature/proxy/views/components/ip_history_list.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:command_center/feature/proxy/views/components/linked_characters_section.dart';
import 'package:command_center/feature/proxy/views/components/slot_header.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxyDetailSection extends StatelessWidget {
  final ProxyController controller;
  final AutomationService automationService;
  final RxBool isReplacing;
  final void Function(
          BuildContext context, ProxySlotEntity slot, ProxyIpAddressEntity ip)
      onShowReplaceDialog;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onLaunchBrowser;
  final void Function(BuildContext context, ProxySlotEntity slot)
      onShowChangeIpDialog;
  final Future<void> Function(ProxyIpAddressEntity ip) onRefreshIpScore;

  const ProxyDetailSection({
    super.key,
    required this.controller,
    required this.automationService,
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
      final characters = controller.linkedCharacters;

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
              automationService: automationService,
            ),
            const SizedBox(height: 16),
            if (currentIp != null)
              CollapsibleSection(
                title: 'Fraud Analysis',
                badge: _buildScoreBadge(currentIp, theme),
                initiallyExpanded: true,
                content: FraudAnalysis(
                  ip: currentIp,
                  onRefreshScore: () => onRefreshIpScore(currentIp),
                  onScoreIp: () => onRefreshIpScore(currentIp),
                ),
              ),
            const SizedBox(height: 8),
            CollapsibleSection(
              title: 'IP History',
              badge: _buildHistoryBadge(ipHistory, theme),
              initiallyExpanded: false,
              content: IpHistoryList(history: ipHistory),
            ),
            const SizedBox(height: 8),
            CollapsibleSection(
              title: 'Linked Characters',
              badge: _buildCharactersBadge(characters, theme),
              initiallyExpanded: false,
              content: LinkedCharactersSection(characters: characters),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildScoreBadge(
    ProxyIpAddressEntity ip,
    FluentThemeData theme,
  ) {
    if (!ip.hasBeenScored) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Not scored',
          style: TextStyle(fontSize: 11),
        ),
      );
    }
    return IpScoreIndicator(ip: ip);
  }

  Widget _buildHistoryBadge(
    List<ProxyIpAddressEntity> history,
    FluentThemeData theme,
  ) {
    final rotations = history.length;
    String avgLabel = '';
    if (history.length > 1) {
      // Average days between IP assignments (difference between consecutive)
      final sorted = [...history]
        ..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
      int totalDays = 0;
      for (int i = 1; i < sorted.length; i++) {
        totalDays +=
            sorted[i].assignedAt.difference(sorted[i - 1].assignedAt).inDays;
      }
      final avg = totalDays ~/ (sorted.length - 1);
      avgLabel = ' · Avg: ${avg}d';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$rotations rotation${rotations == 1 ? '' : 's'}$avgLabel',
        style: TextStyle(fontSize: 11, color: theme.accentColor),
      ),
    );
  }

  Widget _buildCharactersBadge(
    List characters,
    FluentThemeData theme,
  ) {
    final count = characters.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count character${count == 1 ? '' : 's'}',
        style: TextStyle(fontSize: 11, color: theme.accentColor),
      ),
    );
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
