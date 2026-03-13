import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_replacement_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:command_center/feature/proxy/views/dialogs/add_slot_dialog.dart';
import 'package:command_center/feature/proxy/views/dialogs/change_ip_dialog.dart';
import 'package:command_center/feature/proxy/views/dialogs/replace_proxy_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

mixin ProxyScreenActions<T extends StatefulWidget> on State<T> {
  ProxyController get controller;
  ProxyScoringController get scoringController;
  ProxyReplacementController get replacementController;

  void showAddSlotDialog(BuildContext context) {
    AddSlotDialog.show(context, controller: controller);
  }

  void showChangeIpDialog(BuildContext context, ProxySlotEntity slot) {
    ChangeIpDialog.show(context, slot: slot, controller: replacementController);
  }

  void showReplaceProxyDialog(
    BuildContext context,
    ProxySlotEntity slot,
    ProxyIpAddressEntity currentIp,
  ) {
    ReplaceProxyDialog.show(
      context,
      slot: slot,
      currentIp: currentIp,
      controller: replacementController,
    );
  }

  Future<void> launchBrowserWithProxy(
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
            content: Text('Slot #${slot.slotNumber} has no IP address assigned.'),
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

    if (context.mounted) {
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

  Future<void> refreshIpScore(ProxyIpAddressEntity ip) async {
    if (!scoringController.isIpqsConfigured.value) {
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
            content: const Text('Failed to refresh IP score. Please try again.'),
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

  Future<void> scoreAllIps() async {
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
