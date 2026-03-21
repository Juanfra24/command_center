import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class CreateAccountButton extends StatelessWidget {
  final ValueNotifier<bool> isValidating;
  final ValueNotifier<AutomationResult?> validationResult;
  final ValueNotifier<int?> selectedSlot;

  const CreateAccountButton({
    super.key,
    required this.isValidating,
    required this.validationResult,
    required this.selectedSlot,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isValidating,
      builder: (context, validating, _) {
        return ValueListenableBuilder<AutomationResult?>(
          valueListenable: validationResult,
          builder: (context, result, _) {
            return FilledButton(
              onPressed: validating || selectedSlot.value == null
                  ? null
                  : () => _handleCreateAccount(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (validating)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  else
                    const Icon(FluentIcons.add_friend, size: 14),
                  const SizedBox(width: 8),
                  Text(validating ? 'Creating...' : 'Create Account'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCreateAccount(BuildContext context) async {
    isValidating.value = true;
    validationResult.value = null;

    try {
      final proxyController = Get.find<ProxyController>();
      final slot = proxyController.proxySlots
          .firstWhere((s) => s.id == selectedSlot.value);

      final automationService = Get.find<AutomationService>();
      final statusController = Get.find<StatusController>();

      final createResult = await automationService.createAccount(slot: slot);

      validationResult.value = createResult;
      isValidating.value = false;

      if (createResult.isAccountCreated) {
        await statusController.getAccountsData();

        // ignore: use_build_context_synchronously
        Navigator.pop(context);

        final data = createResult.data ?? {};
        final accountName = data['accountName'] ?? 'Unknown';
        final createdEmail = data['email'] ?? 'Unknown';
        final password = (data['password'] ?? '') as String;
        final maskedPass = password.length > 4
            ? '${password.substring(0, 2)}${'*' * (password.length - 4)}${password.substring(password.length - 2)}'
            : '****';
        displayInfoBar(
          // ignore: use_build_context_synchronously
          context,
          duration: const Duration(seconds: 10),
          builder: (ctx, close) {
            return InfoBar(
              title: Text('Account Created: $accountName'),
              content: Text('Email: $createdEmail\nPassword: $maskedPass'),
              severity: InfoBarSeverity.success,
              isLong: true,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } catch (e) {
      isValidating.value = false;
      validationResult.value = AutomationResult.error('Error: $e');
    }
  }
}
