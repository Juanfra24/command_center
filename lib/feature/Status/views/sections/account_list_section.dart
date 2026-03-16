import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';
import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/views/components/account_table_cells.dart';
import 'package:command_center/feature/Status/views/components/bot_status_badge.dart';
import 'package:command_center/feature/Status/views/components/script_chip.dart';
import 'package:command_center/feature/Status/views/components/script_picker_flyout.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

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
          Text('Account List', style: theme.typography.subtitle),
          const SizedBox(height: 16),
          Expanded(child: _buildAccountsTable(context)),
        ],
      ),
    );
  }

  List<_AccountRow> _buildFilteredRows() {
    final selectionCtrl = Get.find<StatusSelectionController>();
    final watchdog = Get.find<WatchdogService>();
    final query = selectionCtrl.searchQuery.value.toLowerCase();
    final statusF = selectionCtrl.statusFilter.value;
    final scriptF = selectionCtrl.scriptFilter.value;

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

    return rows.where((row) {
      // Search filter
      if (query.isNotEmpty) {
        final match = row.account.accountName.toLowerCase().contains(query) ||
            row.account.email.toLowerCase().contains(query) ||
            (row.character?.name.toLowerCase().contains(query) ?? false);
        if (!match) return false;
      }
      // Status filter
      if (statusF != 'all' && row.character != null) {
        final tracked = watchdog.trackedClients[row.character!.name];
        final status = tracked?.status;
        switch (statusF) {
          case 'running':
            if (status != ClientStatus.running) return false;
          case 'stopped':
            if (status != null && status != ClientStatus.stopped) return false;
          case 'banned':
            if (status != ClientStatus.banned && !row.character!.banned) {
              return false;
            }
        }
      }
      // Script filter
      if (scriptF != 'all') {
        if (row.character?.defaultScriptName != scriptF) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildAccountsTable(BuildContext context) {
    final theme = FluentTheme.of(context);
    final selectionCtrl = Get.find<StatusSelectionController>();

    const columns = [
      '',            // Checkbox
      'Account',
      'Credentials',
      'Character',
      'Script',
      'Proxy',
      'Status',
      'Actions',
    ];
    const flexes = [1, 3, 4, 3, 3, 3, 3, 2];

    return Obx(() {
      final rows = _buildFilteredRows();

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
              children: [
                for (int i = 0; i < columns.length; i++)
                  Expanded(
                    flex: flexes[i],
                    child: _buildTableHeader(columns[i]),
                  ),
              ],
            ),
          ),
          // Virtualized rows
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final isBanned = row.character?.banned == true;
                return Container(
                  decoration: BoxDecoration(
                    color: isBanned
                        ? Colors.red.withValues(alpha: 0.06)
                        : null,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.resources.dividerStrokeColorDefault,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      Expanded(
                        flex: flexes[0],
                        child: row.character != null
                            ? Obx(() => Checkbox(
                                  checked: selectionCtrl
                                      .isSelected(row.character!.id!),
                                  onChanged: (_) => selectionCtrl
                                      .toggleSelection(row.character!.id!),
                                ))
                            : const SizedBox.shrink(),
                      ),
                      // Account
                      Expanded(
                        flex: flexes[1],
                        child: _buildTableCell(row.account.accountName),
                      ),
                      // Credentials
                      Expanded(
                        flex: flexes[2],
                        child: CredentialsCell(
                          email: row.account.email,
                          password: row.account.password,
                        ),
                      ),
                      // Character
                      Expanded(
                        flex: flexes[3],
                        child: _buildTableCell(
                            row.character?.name ?? '\u2014'),
                      ),
                      // Script
                      Expanded(
                        flex: flexes[4],
                        child: _buildScriptCell(row.character),
                      ),
                      // Proxy
                      Expanded(
                        flex: flexes[5],
                        child: ProxyCell(
                            proxyAddress: row.account.proxyAddress),
                      ),
                      // Status
                      Expanded(
                        flex: flexes[6],
                        child: Obx(() {
                          final tracked = Get.find<WatchdogService>()
                              .trackedClients[row.character?.name];
                          return BotStatusBadge(
                            status: tracked?.status,
                            retryCount: tracked?.retryCount ?? 0,
                          );
                        }),
                      ),
                      // Actions
                      Expanded(
                        flex: flexes[7],
                        child: ActionsCell(
                          controller: controller,
                          account: row.account,
                          character: row.character,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildScriptCell(Character? character) {
    if (character == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ScriptPickerFlyout(
        currentScript: character.defaultScriptName ?? '',
        onScriptSelected: (scriptName) {
          if (character.id != null) {
            controller.updateDefaultScript(character.id!, scriptName);
          }
        },
        child: ScriptChip(
          scriptName: character.defaultScriptName,
          banned: character.banned,
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AccountRow {
  final JagexAccount account;
  final Character? character;
  const _AccountRow({required this.account, this.character});
}
