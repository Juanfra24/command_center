import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:command_center/feature/proxy/views/components/proxy_slot_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxyListSection extends StatelessWidget {
  final ProxyController controller;
  final ProxyScoringController scoringController;
  final TextEditingController searchController;
  final VoidCallback onAddSlot;

  const ProxyListSection({
    super.key,
    required this.controller,
    required this.scoringController,
    required this.searchController,
    required this.onAddSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSummaryStats(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(context),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildSlotList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context) {
    return Obx(() => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatChip(
              context,
              label: 'Total Slots',
              value: controller.totalSlots.toString(),
              color: Colors.blue,
            ),
            _buildStatChip(
              context,
              label: 'Active',
              value: controller.activeSlots.toString(),
              color: Colors.green,
            ),
            _buildStatChip(
              context,
              label: 'IP Changes',
              value: controller.totalIpChanges.toString(),
              color: Colors.orange,
            ),
            _buildStatChip(
              context,
              label: 'Avg Score',
              value: scoringController.averageIpScore.toStringAsFixed(1),
              color: getScoreColor(scoringController.averageIpScore,
                  hasBeenScored: scoringController.hasScoredIps),
            ),
            if (scoringController.lowScoreCount > 0)
              _buildStatChip(
                context,
                label: 'Low Score',
                value: scoringController.lowScoreCount.toString(),
                color: Colors.red,
                isWarning: true,
              ),
          ],
        ));
  }

  Widget _buildStatChip(
    BuildContext context, {
    required String label,
    required String value,
    required AccentColor color,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: isWarning ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      children: [
        TextBox(
          controller: searchController,
          placeholder: 'Search slots, IPs, locations...',
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(FluentIcons.search, size: 16),
          ),
          onChanged: (value) => controller.searchQuery.value = value,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Obx(() => Checkbox(
                  checked: controller.showOnlyActive.value,
                  onChanged: (value) =>
                      controller.showOnlyActive.value = value ?? true,
                  content: const Text('Active only'),
                )),
            const SizedBox(width: 16),
            Obx(() => Checkbox(
                  checked: scoringController.sortByScore.value,
                  onChanged: (value) =>
                      scoringController.sortByScore.value = value ?? false,
                  content: const Text('Sort by score'),
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotList(BuildContext context) {
    return Obx(() {
      final slots = controller.getFilteredSlots(
        sortByScore: scoringController.sortByScore.value,
      );
      final _ = controller.selectedSlot.value;

      if (slots.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FluentIcons.globe, size: 48),
              const SizedBox(height: 16),
              Text(
                'No proxy slots found',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onAddSlot,
                child: const Text('Add First Slot'),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: slots.length,
        itemBuilder: (context, index) {
          final slot = slots[index];
          final currentIp = controller.getCurrentIpForSlot(slot);
          final isSelected = controller.selectedSlot.value?.id == slot.id;
          return ProxySlotCard(
            slot: slot,
            currentIp: currentIp,
            isSelected: isSelected,
            onSelect: () => controller.selectSlot(slot),
            onUpdateSlotName: (s, name) => controller.updateSlotName(s, name),
          );
        },
      );
    });
  }
}
