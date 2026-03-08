import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/feature/proxy/views/dialogs/add_slot_dialog.dart';
import 'package:command_center/feature/proxy/views/dialogs/change_ip_dialog.dart';
import 'package:command_center/feature/proxy/views/dialogs/replace_proxy_dialog.dart';
import 'package:command_center/feature/proxy/views/sections/proxy_detail_section.dart';
import 'package:command_center/feature/proxy/views/sections/proxy_list_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxyScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;

  const ProxyScreen({super.key, this.onNavigateToSettings});

  @override
  State<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends State<ProxyScreen> {
  late ProxyController controller;
  final searchController = TextEditingController();

  late final ProxyScoringController scoringController;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ProxyController());
    scoringController = Get.find<ProxyScoringController>();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Proxy Management'),
        commandBar: _buildCommandBar(),
      ),
      content: Obx(() {
        if (!controller.isWebshareConfigured.value) {
          return _buildIntegrationRequiredView(context);
        }

        if (controller.isLoading.value) {
          return const Center(child: ProgressRing());
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: ProxyListSection(
                controller: controller,
                searchController: searchController,
                onAddSlot: () => _showAddSlotDialog(context),
              ),
            ),
            Expanded(
              flex: 3,
              child: ProxyDetailSection(
                controller: controller,
                onShowReplaceDialog: _showReplaceProxyDialog,
                onLaunchBrowser: _launchBrowserWithProxy,
                onShowChangeIpDialog: _showChangeIpDialog,
                onRefreshIpScore: _refreshIpScore,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCommandBar() {
    return Obx(() => CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            if (controller.isIpqsConfigured.value)
              CommandBarButton(
                icon: scoringController.isScoring.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.shield),
                label: Text(scoringController.isScoring.value
                    ? 'Scoring...'
                    : 'Score All IPs'),
                onPressed: scoringController.isScoring.value
                    ? null
                    : () => _scoreAllIps(),
              ),
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
        ));
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

  // --- Dialog & action delegates ---

  void _showAddSlotDialog(BuildContext context) {
    AddSlotDialog.show(context, controller: controller);
  }

  void _showChangeIpDialog(BuildContext context, ProxySlotEntity slot) {
    ChangeIpDialog.show(context, slot: slot, controller: controller);
  }

  void _showReplaceProxyDialog(
    BuildContext context,
    ProxySlotEntity slot,
    ProxyIpAddressEntity currentIp,
  ) {
    ReplaceProxyDialog.show(
      context,
      slot: slot,
      currentIp: currentIp,
      controller: controller,
    );
  }

  Future<void> _launchBrowserWithProxy(
    BuildContext context,
    ProxySlotEntity slot,
  ) async {
    final automationService = Get.find<AutomationService>();
    final currentIp = controller.getCurrentIpForSlot(slot);

    if (currentIp == null) {
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('No IP assigned'),
            content:
                Text('Slot #${slot.slotNumber} has no IP address assigned.'),
            severity: InfoBarSeverity.warning,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        });
      }
      return;
    }

    final result = await automationService.createAccountSession(slot: slot);

    if (mounted) {
      displayInfoBar(context, builder: (context, close) {
        return InfoBar(
          title: Text(result.isSuccess ? 'Browser launched' : 'Launch failed'),
          content: Text(result.message),
          severity: result.isSuccess
              ? InfoBarSeverity.success
              : InfoBarSeverity.error,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      });
    }
  }

  Future<void> _refreshIpScore(ProxyIpAddressEntity ip) async {
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

    final success = await scoringController.scoreIpWithIpqs(ip);

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

    final count = await scoringController.scoreAllCurrentIps();

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
