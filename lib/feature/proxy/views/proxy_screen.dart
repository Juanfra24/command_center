import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

// Extension to convert ShadedColor to AccentColor
extension ShadedColorToAccent on ShadedColor {
  AccentColor toAccentColor() {
    return AccentColor.swatch({
      'darkest': this,
      'darker': this,
      'dark': this,
      'normal': this,
      'light': this,
      'lighter': this,
      'lightest': this,
    });
  }
}

class ProxyScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;

  const ProxyScreen({super.key, this.onNavigateToSettings});

  @override
  State<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends State<ProxyScreen> {
  late ProxyController controller;
  final searchController = TextEditingController();

  // Slot name editing state
  int? _editingSlotId;
  final _editingNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(ProxyController());
  }

  @override
  void dispose() {
    searchController.dispose();
    _editingNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Proxy Management'),
        commandBar: Obx(() => CommandBar(
              mainAxisAlignment: MainAxisAlignment.end,
              primaryItems: [
                // Show score all button if IPQS is configured
                if (controller.isIpqsConfigured.value)
                  CommandBarButton(
                    icon: controller.isScoring.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Icon(FluentIcons.shield),
                    label: Text(controller.isScoring.value
                        ? 'Scoring...'
                        : 'Score All IPs'),
                    onPressed: controller.isScoring.value
                        ? null
                        : () => _scoreAllIps(),
                  ),
                // Show sync button if Webshare is configured
                if (controller.isWebshareConfigured.value)
                  CommandBarButton(
                    icon:
                        controller.isSyncing.value || controller.isLoading.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : const Icon(FluentIcons.sync),
                    label: Text(controller.isSyncing.value
                        ? 'Syncing...'
                        : 'Sync & Refresh'),
                    onPressed:
                        controller.isSyncing.value || controller.isLoading.value
                            ? null
                            : () async {
                                await controller.syncWithWebshare();
                                await controller.loadData();
                              },
                  ),
              ],
            )),
      ),
      content: Obx(() {
        // Show integration required message if Webshare is not configured
        if (!controller.isWebshareConfigured.value) {
          return _buildIntegrationRequiredView(context);
        }

        if (controller.isLoading.value) {
          return const Center(child: ProgressRing());
        }

        return Row(
          children: [
            // Left panel - Slot list
            Expanded(
              flex: 2,
              child: _buildSlotListPanel(context),
            ),
            // Right panel - Slot details
            Expanded(
              flex: 3,
              child: _buildDetailsPanel(context),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildIntegrationRequiredView(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Card(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                FluentIcons.plug_connected,
                size: 40,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Webshare Integration Required',
              style: theme.typography.subtitle,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                'To manage your proxy slots, you need to connect your Webshare account. '
                'Go to Settings > Integrations to configure your API key.',
                textAlign: TextAlign.center,
                style: theme.typography.body,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.onNavigateToSettings,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.settings),
                  SizedBox(width: 8),
                  Text('Go to Settings'),
                ],
              ),
            ),
            // Show error if any
            Obx(() {
              if (controller.lastSyncError.value != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: InfoBar(
                    title: const Text('Error'),
                    content: Text(controller.lastSyncError.value!),
                    severity: InfoBarSeverity.error,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotListPanel(BuildContext context) {
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
          // Summary stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSummaryStats(context),
          ),
          // Search and filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(context),
          ),
          const SizedBox(height: 16),
          // Slot list
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
              value: controller.averageIpScore.toStringAsFixed(1),
              color: _getScoreColor(controller.averageIpScore),
            ),
            if (controller.lowScoreCount > 0)
              _buildStatChip(
                context,
                label: 'Low Score',
                value: controller.lowScoreCount.toString(),
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
                  checked: controller.sortByScore.value,
                  onChanged: (value) =>
                      controller.sortByScore.value = value ?? false,
                  content: const Text('Sort by score'),
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotList(BuildContext context) {
    return Obx(() {
      final slots = controller.filteredSlots;
      // Force rebuild when selectedSlot changes
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
                onPressed: () => _showAddSlotDialog(context),
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
          return _buildSlotCard(context, slot);
        },
      );
    });
  }

  Widget _buildSlotCard(BuildContext context, ProxySlotEntity slot) {
    final theme = FluentTheme.of(context);
    final currentIp = controller.getCurrentIpForSlot(slot);
    final isSelected = controller.selectedSlot.value?.id == slot.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => controller.selectSlot(slot),
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

  /// Builds the slot name row with optional inline editing
  Widget _buildSlotNameRow(
      ProxySlotEntity slot, bool isSelected, FluentThemeData theme) {
    final isEditing = _editingSlotId == slot.id;

    if (isEditing) {
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
                onSubmitted: (_) => _saveSlotName(slot),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.check_mark, size: 14),
            onPressed: () => _saveSlotName(slot),
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
          onPressed: () => _startEditingSlotName(slot),
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

  void _startEditingSlotName(ProxySlotEntity slot) {
    setState(() {
      _editingSlotId = slot.id;
      _editingNameController.text = slot.slotName;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingSlotId = null;
      _editingNameController.clear();
    });
  }

  Future<void> _saveSlotName(ProxySlotEntity slot) async {
    final newName = _editingNameController.text.trim();
    if (newName.isEmpty) {
      _cancelEditing();
      return;
    }

    final success = await controller.updateSlotName(slot, newName);
    if (success) {
      setState(() {
        _editingSlotId = null;
        _editingNameController.clear();
      });
    }
  }

  Widget _buildScoreBadge(ProxyIpAddressEntity ip) {
    final color = _getScoreColor(ip.ipScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        ip.ipScore > 0 ? ip.ipScore.toStringAsFixed(0) : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSlotInfoChip({required IconData icon, required String label}) {
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

  Widget _buildDetailsPanel(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Obx(() {
      final selectedSlot = controller.selectedSlot.value;

      if (selectedSlot == null) {
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

      final currentIp = controller.getCurrentIpForSlot(selectedSlot);
      final ipHistory = controller.selectedSlotIpHistory;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slot header
            _buildSlotHeader(context, selectedSlot, currentIp),
            const SizedBox(height: 24),
            // Current IP details
            if (currentIp != null) ...[
              Text('Current IP Details', style: theme.typography.subtitle),
              const SizedBox(height: 12),
              _buildCurrentIpCard(context, currentIp),
              const SizedBox(height: 24),
            ],
            // IP Score Analysis
            if (currentIp != null) ...[
              Text('IP Score Analysis', style: theme.typography.subtitle),
              const SizedBox(height: 12),
              _buildScoreAnalysis(context, currentIp),
              const SizedBox(height: 24),
            ],
            // IP History
            Text('IP History', style: theme.typography.subtitle),
            const SizedBox(height: 12),
            _buildIpHistory(context, ipHistory),
          ],
        ),
      );
    });
  }

  Widget _buildSlotHeader(
    BuildContext context,
    ProxySlotEntity slot,
    ProxyIpAddressEntity? currentIp,
  ) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Row(
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
                Row(
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
                    const SizedBox(width: 8),
                    Text(
                      '${slot.totalIpChanges} IP changes',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _showChangeIpDialog(context, slot),
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
    );
  }

  Widget _buildCurrentIpCard(BuildContext context, ProxyIpAddressEntity ip) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSimpleInfoRow('IP Address', ip.ipAddress),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Location', '${ip.cityName}, ${ip.countryCode}'),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Timezone', ip.ipTimezone),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Provider', ip.asnName),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('ASN', ip.asnNumber.toString()),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Assigned', _formatDate(ip.assignedAt)),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildScoreAnalysis(BuildContext context, ProxyIpAddressEntity ip) {
    final theme = FluentTheme.of(context);

    // If IP hasn't been scored yet, show a prompt to score it
    if (!ip.hasBeenScored) {
      return Card(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.grey, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not Scored Yet',
                        style: theme.typography.subtitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click "Refresh Score" to analyze this IP address for VPN, proxy, and fraud detection.',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: () => _refreshIpScore(ip),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.shield, size: 14),
                      SizedBox(width: 8),
                      Text('Score IP'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final scoreColor = _getScoreColor(ip.ipScore);

    return Card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score gauge
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scoreColor,
                    width: 4,
                  ),
                  color: scoreColor.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ip.ipScore > 0 ? ip.ipScore.toStringAsFixed(0) : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        ip.scoreLevel.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Score details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreRow('Fraud Score', ip.fraudScore, Colors.red),
                    const SizedBox(height: 8),
                    _buildScoreRow(
                      'Abuse Confidence',
                      ip.abuseConfidence.toDouble(),
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFlagChip('VPN', ip.isVpn),
                        _buildFlagChip('Proxy', ip.isProxy),
                        _buildFlagChip('Datacenter', ip.isDatacenter),
                        _buildFlagChip('Tor', ip.isTor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Last checked: ${ip.lastScoreCheck != null ? _formatDate(ip.lastScoreCheck!) : 'Never'}',
                style: theme.typography.caption,
              ),
              const Spacer(),
              Button(
                onPressed: () => _refreshIpScore(ip),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.refresh, size: 14),
                    SizedBox(width: 8),
                    Text('Refresh Score'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, AccentColor color) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label),
        ),
        Expanded(
          child: ProgressBar(
            value: value,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            activeColor: color,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlagChip(String label, bool isActive) {
    final color = isActive ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? FluentIcons.warning : FluentIcons.check_mark,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildIpHistory(
      BuildContext context, List<ProxyIpAddressEntity> history) {
    final theme = FluentTheme.of(context);

    if (history.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(FluentIcons.history, size: 32),
                const SizedBox(height: 8),
                Text('No IP history yet', style: theme.typography.body),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: history.take(10).map((ip) {
          final scoreColor = _getScoreColor(ip.ipScore);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ip.isActive ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ip.ipAddress,
                        style: theme.typography.bodyStrong,
                      ),
                      Text(
                        '${ip.cityName}, ${ip.countryCode}',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ip.ipScore > 0 ? ip.ipScore.toStringAsFixed(0) : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: Text(
                    _formatDate(ip.assignedAt),
                    style: theme.typography.caption,
                    textAlign: TextAlign.right,
                  ),
                ),
                if (!ip.isActive && ip.removedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '→ ${_formatDate(ip.removedAt!)}',
                    style: theme.typography.caption,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  AccentColor _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.teal;
    if (score >= 50) return Colors.orange;
    if (score >= 30) return Colors.red;
    if (score > 0) return Colors.red;
    return Colors.grey.toAccentColor();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddSlotDialog(BuildContext context) {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final portController = TextEditingController(text: '8080');

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Add Proxy Slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoLabel(
              label: 'Slot Name',
              child: TextBox(
                controller: nameController,
                placeholder: 'e.g., US Proxy 1',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Username',
              child: TextBox(
                controller: usernameController,
                placeholder: 'Webshare username',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Password',
              child: TextBox(
                controller: passwordController,
                placeholder: 'Webshare password',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Port',
              child: TextBox(
                controller: portController,
                placeholder: '8080',
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newSlot = ProxySlotEntity(
                id: null,
                slotName: nameController.text,
                slotNumber: controller.totalSlots + 1,
                username: usernameController.text,
                password: passwordController.text,
                port: int.tryParse(portController.text) ?? 8080,
                createdAt: DateTime.now(),
                lastUpdated: DateTime.now(),
                totalIpChanges: 0,
                isActive: true,
              );
              await controller.addProxySlot(newSlot);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showChangeIpDialog(BuildContext context, ProxySlotEntity slot) {
    // IP rotation is now handled via Webshare API
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Rotate IP Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will request a new IP address from Webshare for this proxy slot.',
            ),
            const SizedBox(height: 16),
            InfoBar(
              title: const Text('Note'),
              content: const Text(
                'The new IP will be automatically synced after the rotation is complete.',
              ),
              severity: InfoBarSeverity.info,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await controller.rotateSlotIp(slot);

              if (context.mounted) {
                displayInfoBar(
                  context,
                  builder: (context, close) {
                    return InfoBar(
                      title: Text(success ? 'Success' : 'Error'),
                      content: Text(
                        success
                            ? 'IP rotation initiated. Syncing...'
                            : controller.lastSyncError.value ??
                                'Failed to rotate IP',
                      ),
                      severity: success
                          ? InfoBarSeverity.success
                          : InfoBarSeverity.error,
                      action: IconButton(
                        icon: const Icon(FluentIcons.clear),
                        onPressed: close,
                      ),
                    );
                  },
                );
              }
            },
            child: const Text('Rotate IP'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshIpScore(ProxyIpAddressEntity ip) async {
    // Check if IPQS is configured
    if (!controller.isIpqsConfigured.value) {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('IPQualityScore Not Configured'),
            content: const Text(
              'Go to Settings > Integrations to configure IPQualityScore for IP scoring.',
            ),
            severity: InfoBarSeverity.warning,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
      return;
    }

    // Show scoring in progress
    displayInfoBar(
      context,
      builder: (ctx, close) {
        return InfoBar(
          title: const Text('Scoring IP...'),
          content: Text('Checking score for ${ip.ipAddress}'),
          severity: InfoBarSeverity.info,
          action: const SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(strokeWidth: 2),
          ),
        );
      },
    );

    final success = await controller.scoreIpWithIpqs(ip);

    if (!mounted) return;

    if (success) {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('Score Updated'),
            content: Text('IP ${ip.ipAddress} score has been refreshed.'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    } else {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('Scoring Failed'),
            content:
                const Text('Failed to refresh IP score. Please try again.'),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    }
  }

  Future<void> _scoreAllIps() async {
    displayInfoBar(
      context,
      builder: (ctx, close) {
        return InfoBar(
          title: const Text('Scoring All IPs...'),
          content: const Text('This may take a moment.'),
          severity: InfoBarSeverity.info,
          action: const SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(strokeWidth: 2),
          ),
        );
      },
    );

    final count = await controller.scoreAllCurrentIps();

    if (!mounted) return;

    displayInfoBar(
      context,
      builder: (ctx, close) {
        return InfoBar(
          title: const Text('Scoring Complete'),
          content: Text('Successfully scored $count IP addresses.'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }
}
