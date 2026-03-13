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
          Expanded(
            child: _buildAccountsTable(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTable(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Flatten accounts into displayable rows
    final rows = <_AccountRow>[];
    for (final account in controller.accountList) {
      if (account.characters.isEmpty) {
        rows.add(_AccountRow(account: account, character: null));
      } else {
        for (final character in account.characters) {
          rows.add(_AccountRow(account: account, character: character));
        }
      }
    }

    const columns = [
      'Account Name',
      'Email',
      'Password',
      'Character',
      'Proxy',
      'Status',
      'Actions',
    ];

    return Column(
      children: [
        // Fixed header
        Container(
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.1),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
          child: Row(
            children: columns
                .map((c) => Expanded(child: _buildTableHeader(c)))
                .toList(),
          ),
        ),
        // Virtualized rows
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final isRunning = row.character != null &&
                  controller.processClients.containsKey(row.character!.name);
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.resources.dividerStrokeColorDefault,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildTableCell(row.account.accountName)),
                    Expanded(
                      child: _buildTableCellWithCopy(
                        context,
                        row.account.email,
                      ),
                    ),
                    Expanded(
                      child: _buildTableCellWithCopy(
                        context,
                        row.account.password,
                      ),
                    ),
                    Expanded(
                      child: _buildTableCell(
                        row.character?.name ?? '\u2014',
                      ),
                    ),
                    Expanded(
                      child: _buildTableCell(row.account.proxyAddress),
                    ),
                    Expanded(
                      child: ProcessStatusBadge(isRunning: isRunning),
                    ),
                    Expanded(
                      child: row.character != null
                          ? _buildActionsCell(
                              context,
                              row.account,
                              row.character!,
                              isRunning,
                            )
                          : _buildEmptyAccountActions(context, row.account),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
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

class _AccountRow {
  final JagexAccount account;
  final Character? character;

  const _AccountRow({required this.account, this.character});
}
