import 'package:command_center/config/services/automation_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class StatusScreen extends GetView<StatusController> {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Accounts & Characters'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Character'),
              onPressed: _canCreateCharacter()
                  ? () => _showCreateCharacterDialog(context)
                  : null,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () async {
                await controller.getAccountsData();
                await controller.updateRunningProcesses();
              },
            ),
          ],
        ),
      ),
      content: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: ProgressRing(),
          );
        }

        if (controller.accountList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    FluentIcons.people,
                    size: 40,
                    color: theme.accentColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Accounts Yet',
                  style: theme.typography.subtitle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first character to get started.',
                  style: theme.typography.body,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _canCreateCharacter()
                      ? () => _showCreateCharacterDialog(context)
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 16),
                        SizedBox(width: 8),
                        Text('New Character'),
                      ],
                    ),
                  ),
                ),
                if (!_canCreateCharacter()) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Connect Webshare first to sync proxy slots',
                    style: theme.typography.caption
                        ?.copyWith(color: Colors.orange),
                  ),
                ],
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummaryCards(context),
              const SizedBox(height: 24),
              // Accounts Table
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account List',
                      style: theme.typography.subtitle,
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildAccountsTable(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final totalAccounts = controller.accountList.length;
    final totalCharacters = controller.accountList
        .fold<int>(0, (sum, account) => sum + account.characters.length);
    final runningProcesses = controller.processClients.length;

    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context,
            icon: FluentIcons.contact,
            title: 'Total Accounts',
            value: totalAccounts.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: FluentIcons.people,
            title: 'Characters',
            value: totalCharacters.toString(),
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: FluentIcons.play,
            title: 'Running',
            value: runningProcesses.toString(),
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required AccentColor color,
  }) {
    final theme = FluentTheme.of(context);

    return Card(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.typography.title?.copyWith(
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: theme.typography.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsTable(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(
        color: theme.resources.dividerStrokeColorDefault,
        width: 1,
        borderRadius: BorderRadius.circular(4),
      ),
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.1),
          ),
          children: [
            _buildTableHeader('Account Name'),
            _buildTableHeader('Email'),
            _buildTableHeader('Password'),
            _buildTableHeader('Character'),
            _buildTableHeader('Proxy'),
            _buildTableHeader('Status'),
            _buildTableHeader('Actions'),
          ],
        ),
        // Data Rows
        ...controller.accountList.expand((account) {
          if (account.characters.isEmpty) {
            // Show account row even without characters
            return [
              TableRow(
                children: [
                  _buildTableCell(account.accountName),
                  _buildTableCellWithCopy(context, account.email),
                  _buildTableCellWithCopy(context, account.password),
                  _buildTableCell('—'),
                  _buildTableCell(account.proxyAddress),
                  _buildStatusCell(context, false),
                  _buildTableCell(''),
                ],
              ),
            ];
          }
          return account.characters.map((character) {
            final isRunning =
                controller.processClients.containsKey(character.name);
            return TableRow(
              children: [
                _buildTableCell(account.accountName),
                _buildTableCellWithCopy(context, account.email),
                _buildTableCellWithCopy(context, account.password),
                _buildTableCell(character.name),
                _buildTableCell(account.proxyAddress),
                _buildStatusCell(context, isRunning),
                _buildActionsCell(context, account, character, isRunning),
              ],
            );
          });
        }),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text),
    );
  }

  Widget _buildTableCellWithCopy(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(FluentIcons.copy, size: 14),
            onPressed: () => _copyToClipboard(context, text),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(BuildContext context, bool isRunning) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isRunning
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isRunning ? 'Running' : 'Stopped',
              style: TextStyle(
                color: isRunning ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCell(
    BuildContext context,
    dynamic account,
    dynamic character,
    bool isRunning,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            Tooltip(
              message: 'Stop',
              child: IconButton(
                icon: Icon(FluentIcons.stop, color: Colors.red),
                onPressed: () async {
                  await controller.stopGameClient(
                    controller.processClients[character.name],
                  );
                },
              ),
            )
          else
            Tooltip(
              message: 'Start',
              child: IconButton(
                icon: Icon(FluentIcons.play, color: Colors.green),
                onPressed: () async {
                  await controller.runGameClient(account);
                },
              ),
            ),
          const SizedBox(width: 4),
          // Browser automation is available via the Proxy Management screen
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    controller.copyToClipboard(text, context);
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Copied!'),
          content: const Text('Text copied to clipboard'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }

  /// Check if we can create a new character (requires available proxy slots)
  bool _canCreateCharacter() {
    try {
      final onboardingService = Get.find<OnboardingService>();
      return onboardingService.canCreateCharacter;
    } catch (_) {
      return false;
    }
  }

  /// Show dialog to create a new character
  void _showCreateCharacterDialog(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Get available proxy slots
    List<int?> availableSlots = [];
    int? selectedSlotId;

    try {
      final proxyController = Get.find<ProxyController>();
      final statusController = Get.find<StatusController>();

      // Get slots that are not already assigned
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

    // State for the dialog
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
            // Info about the process
            Container(
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
            ),
            const SizedBox(height: 20),

            // Proxy slot selection
            InfoLabel(
              label: 'Select Proxy Slot',
              child: ValueListenableBuilder<int?>(
                valueListenable: selectedSlot,
                builder: (context, value, _) {
                  return ComboBox<int>(
                    value: value,
                    isExpanded: true,
                    items:
                        availableSlots.where((id) => id != null).map((slotId) {
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
                                  color:
                                      theme.accentColor.withValues(alpha: 0.2),
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
            ),
            const SizedBox(height: 16),

            // Validation status
            ValueListenableBuilder<bool>(
              valueListenable: isValidating,
              builder: (context, validating, _) {
                return ValueListenableBuilder<AutomationResult?>(
                  valueListenable: validationResult,
                  builder: (context, result, _) {
                    if (validating) {
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
                                final automationService =
                                    Get.find<AutomationService>();
                                automationService.cancelCurrentTask();
                                isValidating.value = false;
                                validationResult.value = AutomationResult.error(
                                    'Validation cancelled');
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (result != null) {
                      final isSuccess = result.isSuccess;
                      final isAccountCreated = result.isAccountCreated;
                      final color = isSuccess ? Colors.green : Colors.red;
                      final icon = isSuccess
                          ? FluentIcons.check_mark
                          : FluentIcons.error_badge;

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
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
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
                                    style: theme.typography.bodyStrong
                                        ?.copyWith(color: color),
                                  ),
                                  if (result.actualIp != null)
                                    Text(
                                      'IP: ${result.actualIp}',
                                      style: theme.typography.caption,
                                    ),
                                  if (isAccountCreated &&
                                      result.data != null) ...[
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

                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isValidating,
            builder: (context, validating, _) {
              return ValueListenableBuilder<AutomationResult?>(
                valueListenable: validationResult,
                builder: (context, result, _) {
                  // Single "Create Account" button — does proxy validation + account creation
                  return FilledButton(
                    onPressed: validating || selectedSlot.value == null
                        ? null
                        : () async {
                            final slotId = selectedSlot.value;
                            if (slotId == null) return;

                            isValidating.value = true;
                            validationResult.value = null;

                            try {
                              final proxyController =
                                  Get.find<ProxyController>();
                              final slot = proxyController.proxySlots
                                  .firstWhere((s) => s.id == slotId);

                              final automationService =
                                  Get.find<AutomationService>();

                              final createResult =
                                  await automationService.createAccount(
                                slot: slot,
                              );

                              validationResult.value = createResult;
                              isValidating.value = false;

                              if (createResult.isAccountCreated) {
                                // Refresh accounts list
                                await controller.getAccountsData();

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
                              validationResult.value = AutomationResult.error(
                                'Error: $e',
                              );
                            }
                          },
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
          ),
        ],
      ),
    );
  }
}
