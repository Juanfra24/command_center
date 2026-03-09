import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/views/components/create_account_button.dart';
import 'package:command_center/feature/Status/views/components/info_banner.dart';
import 'package:command_center/feature/Status/views/components/proxy_slot_selector.dart';
import 'package:command_center/feature/Status/views/components/validation_status_indicator.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class CreateCharacterDialog {
  CreateCharacterDialog._();

  static bool canCreate() {
    try {
      final onboardingService = Get.find<OnboardingService>();
      return onboardingService.canCreateCharacter;
    } catch (_) {
      return false;
    }
  }

  static void show(BuildContext context) {
    List<int?> availableSlots = [];
    int? selectedSlotId;

    try {
      final proxyController = Get.find<ProxyController>();
      final statusController = Get.find<StatusController>();

      final assignedProxyIds =
          statusController.accountList.map((a) => a.proxyAddress).toSet();

      availableSlots = proxyController.proxySlots
          .where((slot) {
            final currentIp = proxyController.getCurrentIpForSlot(slot);
            return currentIp == null ||
                !assignedProxyIds.contains(currentIp.ipAddress);
          })
          .map((slot) => slot.id)
          .toList();

      if (availableSlots.isNotEmpty) {
        selectedSlotId = availableSlots.first;
      }
    } catch (_) {}

    if (availableSlots.isEmpty) {
      _showNoProxiesWarning(context);
      return;
    }

    final isValidating = ValueNotifier<bool>(false);
    final validationResult = ValueNotifier<AutomationResult?>(null);
    final selectedSlot = ValueNotifier<int?>(selectedSlotId);

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Create New Character'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoBanner(
              title: 'Account Creation Process',
              description:
                  'Select a proxy slot. The system will validate the IP '
                  'and open a browser session connected through that proxy '
                  'for account registration.',
            ),
            const SizedBox(height: 20),
            ProxySlotSelector(
              availableSlots: availableSlots,
              selectedSlot: selectedSlot,
              validationResult: validationResult,
            ),
            const SizedBox(height: 16),
            ValidationStatusIndicator(
              isValidating: isValidating,
              validationResult: validationResult,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CreateAccountButton(
            isValidating: isValidating,
            validationResult: validationResult,
            selectedSlot: selectedSlot,
          ),
        ],
      ),
    );
  }

  static void _showNoProxiesWarning(BuildContext context) {
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('No Available Proxies'),
          content: const Text(
              'All proxy slots are assigned. Add more slots in Webshare first.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }
}
