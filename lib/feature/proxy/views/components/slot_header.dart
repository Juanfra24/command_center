import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
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
              _buildConnectionInfoRow(context, ip, theme),
            ],
            if (highFraud) ...[
              const SizedBox(height: 10),
              InfoBar(
                title: Text(
                  'High fraud risk: ${ip!.fraudScore.round()} — consider replacing this IP',
                ),
                severity: InfoBarSeverity.warning,
                isLong: false,
              ),
            ],
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

  Widget _buildConnectionInfoRow(
    BuildContext context,
    ProxyIpAddressEntity ip,
    FluentThemeData theme,
  ) {
    final locationParts = [
      if (ip.cityName.isNotEmpty) ip.cityName,
      if ((ip.region ?? '').isNotEmpty) ip.region!,
      if (ip.countryCode.isNotEmpty) ip.countryCode,
    ];
    final location = locationParts.join(', ');
    final provider = ip.isp ?? ip.asnName;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (location.isNotEmpty) _buildBadge(FluentIcons.location, location, theme),
        if (provider.isNotEmpty) _buildBadge(FluentIcons.network_tower, provider, theme),
        if ((ip.connectionType ?? '').isNotEmpty)
          _buildConnectionTypeBadge(ip.connectionType!, theme),
        _buildBadge(
          FluentIcons.clock,
          _relativeTime(ip.assignedAt),
          theme,
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11,
              color: theme.resources.textFillColorSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTypeBadge(String type, FluentThemeData theme) {
    final color = _connectionTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _connectionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'residential':
        return const Color(0xFF4ade80);
      case 'mobile':
        return const Color(0xFF60a5fa);
      case 'corporate':
        return const Color(0xFFa78bfa);
      case 'datacenter':
        return const Color(0xFFf87171);
      default:
        return const Color(0xFF94a3b8);
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
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
