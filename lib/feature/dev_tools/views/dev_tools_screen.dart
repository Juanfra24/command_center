import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/sections/sql_runner_section.dart';
import 'package:command_center/feature/dev_tools/views/sections/table_viewer_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class DevToolsScreen extends StatelessWidget {
  const DevToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DevToolsController>();

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Dev Tools'),
        commandBar: Button(
          onPressed: controller.openDbFolder,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.open_folder_horizontal, size: 14),
              SizedBox(width: 4),
              Text('Open DB Folder'),
            ],
          ),
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
