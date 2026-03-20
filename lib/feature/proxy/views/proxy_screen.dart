import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_replacement_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/feature/proxy/views/helpers/proxy_screen_actions.dart';
import 'package:command_center/feature/proxy/views/sections/integration_required_view.dart';
import 'package:command_center/feature/proxy/views/sections/proxy_command_bar.dart';
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

class _ProxyScreenState extends State<ProxyScreen>
    with ProxyScreenActions<ProxyScreen> {
  late final ProxyController _controller;
  final searchController = TextEditingController();

  late final ProxyScoringController _scoringController;
  late final ProxyReplacementController _replacementController;
  late final AutomationService _automationService;

  @override
  ProxyController get controller => _controller;
  @override
  ProxyScoringController get scoringController => _scoringController;
  @override
  ProxyReplacementController get replacementController =>
      _replacementController;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ProxyController>();
    _scoringController = Get.find<ProxyScoringController>();
    _replacementController = Get.find<ProxyReplacementController>();
    _automationService = Get.find<AutomationService>();
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
        commandBar: ProxyCommandBar(
          controller: _controller,
          scoringController: _scoringController,
          onScoreAllIps: scoreAllIps,
        ),
      ),
      content: Obx(() {
        if (!_controller.isWebshareConfigured.value) {
          return IntegrationRequiredView(
            controller: _controller,
            onNavigateToSettings: widget.onNavigateToSettings,
          );
        }

        if (_controller.isLoading.value) {
          return const Center(child: ProgressRing());
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: ProxyListSection(
                controller: _controller,
                scoringController: _scoringController,
                searchController: searchController,
                onAddSlot: () => showAddSlotDialog(context),
              ),
            ),
            Expanded(
              flex: 3,
              child: ProxyDetailSection(
                controller: _controller,
                automationService: _automationService,
                isReplacing: _replacementController.isReplacing,
                onShowReplaceDialog: (
                  BuildContext ctx,
                  ProxySlotEntity slot,
                  ProxyIpAddressEntity ip,
                ) =>
                    showReplaceProxyDialog(ctx, slot, ip),
                onLaunchBrowser: launchBrowserWithProxy,
                onShowChangeIpDialog: showChangeIpDialog,
                onRefreshIpScore: refreshIpScore,
              ),
            ),
          ],
        );
      }),
    );
  }
}
