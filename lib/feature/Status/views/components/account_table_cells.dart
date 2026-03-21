import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/data/character_model.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/views/dialogs/create_character_dialog.dart';
import 'package:command_center/feature/Status/views/dialogs/launch_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Stacked email + password with copy icons.
class CredentialsCell extends StatelessWidget {
  final String email;
  final String password;

  const CredentialsCell({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CopyRow(label: email),
          const SizedBox(height: 2),
          _CopyRow(label: password, obscure: true),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final bool obscure;

  const _CopyRow({required this.label, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            obscure ? '\u2022' * 8 : label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(FluentIcons.copy, size: 12),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: label));
            displayInfoBar(
              context,
              builder: (context, close) => InfoBar(
                title: const Text('Copied!'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Proxy slot name + country code display.
class ProxyCell extends StatelessWidget {
  final String proxyAddress;

  const ProxyCell({super.key, required this.proxyAddress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        proxyAddress,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// Contextual action buttons: start/stop + delete.
class ActionsCell extends StatelessWidget {
  final StatusController controller;
  final JagexAccount account;
  final Character? character;

  const ActionsCell({
    super.key,
    required this.controller,
    required this.account,
    this.character,
  });

  @override
  Widget build(BuildContext context) {
    if (character == null) {
      return _buildEmptyAccountActions(context);
    }
    return Obx(() {
      final tracked =
          Get.find<WatchdogService>().trackedClients[character?.name];
      final isRunning =
          tracked != null && tracked.status == ClientStatus.running;
      return _buildCharacterActions(context, isRunning);
    });
  }

  Widget _buildCharacterActions(BuildContext context, bool isRunning) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: isRunning
          ? Tooltip(
              message: 'Stop',
              child: IconButton(
                icon: Icon(FluentIcons.stop, size: 14, color: Colors.red),
                onPressed: () => controller.stopCharacter(character!.name),
              ),
            )
          : Tooltip(
              message: 'Start',
              child: IconButton(
                icon: Icon(FluentIcons.play, size: 14, color: Colors.green),
                onPressed: () async {
                  final config = await LaunchDialog.show(context);
                  if (config != null) {
                    try {
                      await controller.launchCharacter(
                          account, character!, config);
                    } catch (_) {}
                  }
                },
              ),
            ),
    );
  }

  Widget _buildEmptyAccountActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Create Character',
            child: IconButton(
              icon: Icon(FluentIcons.add, size: 14, color: Colors.green),
              onPressed: () => CreateCharacterDialog.show(context),
            ),
          ),
          if (account.id != null)
            Tooltip(
              message: 'Delete Account',
              child: IconButton(
                icon: Icon(FluentIcons.delete, size: 14, color: Colors.red),
                onPressed: () => _confirmDelete(context),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Delete Account'),
        content: Text('Delete "${account.email}"? This cannot be undone.'),
        actions: [
          Button(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAccount(account.id!);
  }
}
