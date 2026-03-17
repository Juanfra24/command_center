import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/dev_tools/views/components/result_data_table.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SqlRunnerSection extends StatefulWidget {
  final DevToolsController controller;

  const SqlRunnerSection({super.key, required this.controller});

  @override
  State<SqlRunnerSection> createState() => _SqlRunnerSectionState();
}

class _SqlRunnerSectionState extends State<SqlRunnerSection> {
  final _sqlController = TextEditingController();

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.code, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('SQL Runner', style: theme.typography.bodyLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextBox(
            controller: _sqlController,
            placeholder: 'Enter SQL query...',
            maxLines: 4,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: () =>
                    widget.controller.executeQuery(_sqlController.text),
                child: const Text('Execute'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () {
                  _sqlController.clear();
                  widget.controller.queryResult.clear();
                  widget.controller.queryColumns.clear();
                  widget.controller.queryStatus.value = '';
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (widget.controller.isLoading.value &&
                widget.controller.queryStatus.isEmpty) {
              return const Center(child: ProgressRing());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.controller.queryColumns.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ResultDataTable(
                      columns: widget.controller.queryColumns.toList(),
                      rows: widget.controller.queryResult.toList(),
                    ),
                  ),
                if (widget.controller.queryStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.controller.queryStatus.value,
                      style: TextStyle(
                        color: widget.controller.queryStatus.value
                                .startsWith('Error')
                            ? Colors.red
                            : theme.resources.textFillColorSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
