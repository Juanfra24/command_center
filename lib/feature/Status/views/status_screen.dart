import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';
import 'package:command_center/feature/Status/views/components/bot_farm_summary_bar.dart';
import 'package:command_center/feature/Status/views/components/search_filter_bar.dart';
import 'package:command_center/feature/Status/views/components/status_selection_bar.dart';
import 'package:command_center/feature/Status/views/components/summary_cards.dart';
import 'package:command_center/feature/Status/views/dialogs/create_character_dialog.dart';
import 'package:command_center/feature/Status/views/dialogs/launch_dialog.dart';
import 'package:command_center/feature/Status/views/sections/account_list_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class StatusScreen extends GetView<StatusController> {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Accounts & Characters'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Character'),
              onPressed: CreateCharacterDialog.canCreate()
                  ? () => CreateCharacterDialog.show(context)
                  : null,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () => controller.getAccountsData(),
            ),
          ],
        ),
      ),
      content: Obx(() {
        if (controller.isLoading.value) return const Center(child: ProgressRing());
        if (controller.accountList.isEmpty) return _buildEmptyState(context);
        return _buildAccountsContent(context);
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = FluentTheme.of(context);
    final canCreate = CreateCharacterDialog.canCreate();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(FluentIcons.people, size: 40, color: theme.accentColor),
          ),
          const SizedBox(height: 24),
          Text('No Accounts Yet', style: theme.typography.subtitle),
          const SizedBox(height: 8),
          Text('Create your first character to get started.', style: theme.typography.body),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canCreate ? () => CreateCharacterDialog.show(context) : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(FluentIcons.add, size: 16), SizedBox(width: 8), Text('New Character')],
              ),
            ),
          ),
          if (!canCreate) ...[
            const SizedBox(height: 12),
            Text('Connect Webshare first to sync proxy slots',
                style: theme.typography.caption?.copyWith(color: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountsContent(BuildContext context) {
    final sel = Get.find<StatusSelectionController>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final w = Get.find<WatchdogService>();
            w.trackedClients.length;
            final chars = controller.accountList.fold<int>(0, (s, a) => s + a.characters.length);
            return SummaryCards(
              totalAccounts: controller.accountList.length,
              totalCharacters: chars,
              runningProcesses: w.runningCount,
            );
          }),
          const SizedBox(height: 16),
          Obx(() {
            final chars = controller.accountList.fold<int>(0, (s, a) => s + a.characters.length);
            return SearchFilterBar(showingCount: chars, totalCount: chars);
          }),
          const SizedBox(height: 8),
          Obx(() => sel.hasSelection
              ? StatusSelectionBar(controller: controller, selectionController: sel)
              : BotFarmSummaryBar(
                  onStartAll: () async {
                    final c = await LaunchDialog.show(context);
                    if (c != null) await controller.launchAll(c);
                  },
                  onStopAll: () => controller.stopAll(),
                )),
          const SizedBox(height: 8),
          Expanded(child: AccountListSection(controller: controller)),
        ],
      ),
    );
  }
}
