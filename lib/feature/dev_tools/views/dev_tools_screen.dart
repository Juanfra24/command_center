import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/sections/sql_runner_section.dart';
import 'package:command_center/feature/dev_tools/views/sections/table_viewer_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class DevToolsScreen extends StatelessWidget {
  const DevToolsScreen({super.key});

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DevToolsController>();

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Dev Tools'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.open_folder_horizontal, size: 14),
              label: const Text('Open DB Folder'),
              onPressed: controller.openDbFolder,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh, size: 14),
              label: const Text('Re-run Setup'),
              onPressed: () => _confirmAction(
                context,
                title: 'Re-run Setup?',
                message: 'This clears Java/JAR config and restarts the app. '
                    'The setup wizard will re-download dependencies.',
                onConfirm: controller.rerunSetup,
              ),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.delete, size: 14),
              label: const Text('Reset Database'),
              onPressed: () => _confirmAction(
                context,
                title: 'Reset Database?',
                message: 'This deletes the database and restarts the app. '
                    'All accounts, proxies, and settings will be lost.',
                onConfirm: controller.resetDatabase,
              ),
            ),
          ],
        ),
      ),
      children: [
        TableViewerSection(controller: controller),
        const SizedBox(height: 16),
        SqlRunnerSection(controller: controller),
      ],
    );
  }
}
