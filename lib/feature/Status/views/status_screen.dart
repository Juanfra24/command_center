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
          Tooltip(
            message: 'Launch Browser',
            child: IconButton(
              icon: const Icon(FluentIcons.open_in_new_window),
              onPressed: () async {
                await controller.runPythonScript(account.proxyAddress);
              },
            ),
          ),
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
    final accountNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final characterNameController = TextEditingController();

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

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Create New Character'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Account Name',
              child: TextBox(
                controller: accountNameController,
                placeholder: 'e.g., Main Account',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Email',
              child: TextBox(
                controller: emailController,
                placeholder: 'account@example.com',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Password',
              child: TextBox(
                controller: passwordController,
                placeholder: 'Account password',
                obscureText: true,
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Character Name',
              child: TextBox(
                controller: characterNameController,
                placeholder: 'In-game character name',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Assign Proxy Slot',
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ComboBox<int>(
                    value: selectedSlotId,
                    items:
                        availableSlots.where((id) => id != null).map((slotId) {
                      String slotName = 'Slot $slotId';
                      try {
                        final proxyController = Get.find<ProxyController>();
                        final slot = proxyController.proxySlots
                            .firstWhere((s) => s.id == slotId);
                        slotName = slot.slotName;
                      } catch (_) {}

                      return ComboBoxItem(
                        value: slotId!,
                        child: Text(slotName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedSlotId = value);
                    },
                    placeholder: const Text('Select a proxy slot'),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.info, size: 16, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Each character must have a dedicated proxy slot assigned.',
                      style: theme.typography.caption,
                    ),
                  ),
                ],
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
              if (accountNameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  characterNameController.text.isEmpty ||
                  selectedSlotId == null) {
                displayInfoBar(
                  context,
                  builder: (context, close) {
                    return InfoBar(
                      title: const Text('Validation Error'),
                      content: const Text('Please fill in all fields'),
                      severity: InfoBarSeverity.error,
                      action: IconButton(
                        icon: const Icon(FluentIcons.clear),
                        onPressed: close,
                      ),
                    );
                  },
                );
                return;
              }

              // TODO: Implement actual character creation in Firestore
              // For now, show a success message
              Navigator.pop(context);

              displayInfoBar(
                context,
                builder: (context, close) {
                  return InfoBar(
                    title: const Text('Character Created'),
                    content: Text(
                        '${characterNameController.text} has been created'),
                    severity: InfoBarSeverity.success,
                    action: IconButton(
                      icon: const Icon(FluentIcons.clear),
                      onPressed: close,
                    ),
                  );
                },
              );

              // Refresh account list
              await controller.getAccountsData();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
