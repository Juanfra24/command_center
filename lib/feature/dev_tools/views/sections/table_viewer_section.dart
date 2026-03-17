import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/components/result_data_table.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class TableViewerSection extends StatelessWidget {
  final DevToolsController controller;

  const TableViewerSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.table, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('Table Viewer', style: theme.typography.bodyLarge),
            ],
          ),
          const SizedBox(height: 12),
          _buildControls(),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.isLoading.value &&
                controller.selectedTable.isNotEmpty) {
              return const Center(child: ProgressRing());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ResultDataTable(
                    columns: controller.tableColumns.toList(),
                    rows: controller.tableRows.toList(),
                  ),
                ),
                if (controller.tableRows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing ${controller.tableRows.length} rows (limited to 500)',
                      style: theme.typography.caption,
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Obx(() => Row(
          children: [
            SizedBox(
              width: 250,
              child: ComboBox<String>(
                value: controller.selectedTable.value.isEmpty
                    ? null
                    : controller.selectedTable.value,
                placeholder: const Text('Select a table...'),
                items: controller.tables
                    .map((t) => ComboBoxItem<String>(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.selectTable(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: controller.selectedTable.value.isEmpty
                  ? null
                  : () =>
                      controller.loadTableData(controller.selectedTable.value),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 14),
                  SizedBox(width: 4),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ));
  }
}
