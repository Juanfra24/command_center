import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
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
    final theme = FluentTheme.of(context);

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
            _buildInfoBanner(theme),
            const SizedBox(height: 20),
            _buildSlotSelector(
              theme: theme,
              availableSlots: availableSlots,
              selectedSlot: selectedSlot,
              validationResult: validationResult,
            ),
            const SizedBox(height: 16),
            _buildValidationStatus(
              theme: theme,
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
          _buildCreateButton(
            context: context,
            isValidating: isValidating,
            validationResult: validationResult,
            selectedSlot: selectedSlot,
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoBanner(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.info, color: theme.accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Creation Process',
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a proxy slot. The system will validate the IP '
                  'and open a browser session connected through that proxy '
                  'for account registration.',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSlotSelector({
    required FluentThemeData theme,
    required List<int?> availableSlots,
    required ValueNotifier<int?> selectedSlot,
    required ValueNotifier<AutomationResult?> validationResult,
  }) {
    return InfoLabel(
      label: 'Select Proxy Slot',
      child: ValueListenableBuilder<int?>(
        valueListenable: selectedSlot,
        builder: (context, value, _) {
          return ComboBox<int>(
            value: value,
            isExpanded: true,
            items: availableSlots.where((id) => id != null).map((slotId) {
              String slotName = 'Slot $slotId';
              String ipAddress = 'No IP';

              try {
                final proxyController = Get.find<ProxyController>();
                final slot = proxyController.proxySlots
                    .firstWhere((s) => s.id == slotId);
                slotName = slot.slotName;

                final currentIp =
                    proxyController.getCurrentIpForSlot(slot);
                if (currentIp != null) {
                  ipAddress = currentIp.ipAddress;
                }
              } catch (_) {}

              return ComboBoxItem(
                value: slotId!,
                child: SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '#$slotId',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$slotName - $ipAddress',
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body
                              ?.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              selectedSlot.value = value;
              validationResult.value = null;
            },
            placeholder: const Text('Select a proxy slot'),
          );
        },
      ),
    );
  }

  static Widget _buildValidationStatus({
    required FluentThemeData theme,
    required ValueNotifier<bool> isValidating,
    required ValueNotifier<AutomationResult?> validationResult,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isValidating,
      builder: (context, validating, _) {
        return ValueListenableBuilder<AutomationResult?>(
          valueListenable: validationResult,
          builder: (context, result, _) {
            if (validating) {
              return _buildValidatingIndicator(theme, isValidating,
                  validationResult);
            }

            if (result != null) {
              return _buildResultIndicator(theme, result);
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  static Widget _buildValidatingIndicator(
    FluentThemeData theme,
    ValueNotifier<bool> isValidating,
    ValueNotifier<AutomationResult?> validationResult,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validating Proxy Connection...',
                  style: theme.typography.bodyStrong,
                ),
                Text(
                  'Opening browser and checking IP address',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          HyperlinkButton(
            onPressed: () {
              final automationService = Get.find<AutomationService>();
              automationService.cancelCurrentTask();
              isValidating.value = false;
              validationResult.value =
                  AutomationResult.error('Validation cancelled');
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static Widget _buildResultIndicator(
    FluentThemeData theme,
    AutomationResult result,
  ) {
    final isSuccess = result.isSuccess;
    final isAccountCreated = result.isAccountCreated;
    final color = isSuccess ? Colors.green : Colors.red;
    final icon =
        isSuccess ? FluentIcons.check_mark : FluentIcons.error_badge;

    String title;
    if (isAccountCreated) {
      title = 'Account Created Successfully';
    } else if (isSuccess) {
      title = 'Proxy Validated Successfully';
    } else {
      title = 'Operation Failed';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      theme.typography.bodyStrong?.copyWith(color: color),
                ),
                if (result.actualIp != null)
                  Text(
                    'IP: ${result.actualIp}',
                    style: theme.typography.caption,
                  ),
                if (isAccountCreated && result.data != null) ...[
                  if (result.data!['accountName'] != null)
                    Text(
                      'Name: ${result.data!['accountName']}',
                      style: theme.typography.caption,
                    ),
                  if (result.data!['email'] != null)
                    Text(
                      'Email: ${result.data!['email']}',
                      style: theme.typography.caption,
                    ),
                  if (result.data!['password'] != null)
                    Text(
                      'Password: ${result.data!['password']}',
                      style: theme.typography.caption,
                    ),
                ],
                if (!isSuccess)
                  Text(
                    result.message,
                    style: theme.typography.caption
                        ?.copyWith(color: color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCreateButton({
    required BuildContext context,
    required ValueNotifier<bool> isValidating,
    required ValueNotifier<AutomationResult?> validationResult,
    required ValueNotifier<int?> selectedSlot,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isValidating,
      builder: (context, validating, _) {
        return ValueListenableBuilder<AutomationResult?>(
          valueListenable: validationResult,
          builder: (context, result, _) {
            return FilledButton(
              onPressed: validating || selectedSlot.value == null
                  ? null
                  : () => _handleCreateAccount(
                        context: context,
                        slotId: selectedSlot.value!,
                        isValidating: isValidating,
                        validationResult: validationResult,
                      ),
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

  static Future<void> _handleCreateAccount({
    required BuildContext context,
    required int slotId,
    required ValueNotifier<bool> isValidating,
    required ValueNotifier<AutomationResult?> validationResult,
  }) async {
    isValidating.value = true;
    validationResult.value = null;

    try {
      final proxyController = Get.find<ProxyController>();
      final slot =
          proxyController.proxySlots.firstWhere((s) => s.id == slotId);

      final automationService = Get.find<AutomationService>();
      final statusController = Get.find<StatusController>();

      final createResult = await automationService.createAccount(
        slot: slot,
      );

      validationResult.value = createResult;
      isValidating.value = false;

      if (createResult.isAccountCreated) {
        await statusController.getAccountsData();

        // ignore: use_build_context_synchronously
        Navigator.pop(context);

        final data = createResult.data ?? {};
        final accountName = data['accountName'] ?? 'Unknown';
        final createdEmail = data['email'] ?? 'Unknown';
        final password = data['password'] ?? '';
        // ignore: use_build_context_synchronously
        displayInfoBar(
          context,
          duration: const Duration(seconds: 10),
          builder: (ctx, close) {
            return InfoBar(
              title: Text('Account Created: $accountName'),
              content: Text(
                  'Email: $createdEmail\nPassword: $password'),
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
