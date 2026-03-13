import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/views/components/process_status_badge.dart';
import 'package:command_center/feature/Status/views/dialogs/create_character_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AccountListSection extends StatelessWidget {
  final StatusController controller;

  const AccountListSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
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
        ...controller.accountList.expand((account) {
          if (account.characters.isEmpty) {
            return [
              TableRow(
                children: [
                  _buildTableCell(account.accountName),
                  _buildTableCellWithCopy(context, account.email),
                  _buildTableCellWithCopy(context, account.password),
                  _buildTableCell('\u2014'),
                  _buildTableCell(account.proxyAddress),
                  const ProcessStatusBadge(isRunning: false),
                  _buildEmptyAccountActions(context, account),
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
                ProcessStatusBadge(isRunning: isRunning),
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

  Widget _buildEmptyAccountActions(BuildContext context, JagexAccount account) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Create Character',
            child: IconButton(
              icon: Icon(FluentIcons.add, color: Colors.green),
              onPressed: () => CreateCharacterDialog.show(context),
            ),
          ),
          if (account.id != null)
            Tooltip(
              message: 'Delete Account',
              child: IconButton(
                icon: Icon(FluentIcons.delete, size: 14, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => ContentDialog(
                      title: const Text('Delete Account'),
                      content: Text(
                        'Delete "${account.email}"? This cannot be undone.',
                      ),
                      actions: [
                        Button(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await controller.deleteAccount(account.id!);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsCell(
    BuildContext context,
    JagexAccount account,
    Character character,
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
}
