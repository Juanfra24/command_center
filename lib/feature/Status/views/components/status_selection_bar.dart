import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/core/widgets/selection_toolbar.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';
import 'package:command_center/feature/Status/views/dialogs/bulk_start_confirmation_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Wraps [SelectionToolbar] with Start/Stop Selected actions for the accounts table.
class StatusSelectionBar extends StatelessWidget {
  final StatusController controller;
  final StatusSelectionController selectionController;

  const StatusSelectionBar({
    super.key,
    required this.controller,
    required this.selectionController,
  });

  @override
  Widget build(BuildContext context) {
    final allIds = controller.accountList
        .expand((a) => a.characters)
        .where((c) => c.id != null)
        .map((c) => c.id!)
        .toList();

    return SelectionToolbar(
      selectedCount: selectionController.selectedCount,
      totalCount: allIds.length,
      allSelected:
          selectionController.selectedCount == allIds.length && allIds.isNotEmpty,
      onSelectAll: () => selectionController.selectAll(allIds),
      onClearSelection: selectionController.clearSelection,
      actions: [
        SelectionAction(
          label: 'Start Selected',
          icon: FluentIcons.play,
          onPressed: () => _onStartSelected(context),
        ),
        SelectionAction(
          label: 'Stop Selected',
          icon: FluentIcons.stop,
          onPressed: () => _onStopSelected(),
        ),
      ],
    );
  }

  Future<void> _onStartSelected(BuildContext context) async {
    final r = controller.getBulkLaunchReadiness(
      selectionController.selectedIds.toSet(),
    );
    if (r.withoutScripts > 0) {
      final ok = await BulkStartConfirmationDialog.show(
        context,
        withScripts: r.withScripts,
        withoutScripts: r.withoutScripts,
      );
      if (ok != true) return;
    }
    await controller.launchWithDefaultScripts(
      selectionController.selectedIds.toSet(),
    );
  }

  Future<void> _onStopSelected() async {
    final watchdog = Get.find<WatchdogService>();
    for (final account in controller.accountList) {
      for (final char in account.characters) {
        if (!selectionController.selectedIds.contains(char.id)) continue;
        if (watchdog.trackedClients.containsKey(char.name)) {
          await controller.stopCharacter(char.name);
        }
      }
    }
  }
}
