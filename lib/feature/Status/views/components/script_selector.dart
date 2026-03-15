import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ScriptSelector extends StatelessWidget {
  final String selectedScript;
  final ValueChanged<String> onChanged;

  const ScriptSelector({
    super.key,
    required this.selectedScript,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final configService = Get.find<AppConfigService>();

    return Obx(() {
      final scripts = configService.scriptRegistry.toList();
      final current = scripts.contains(selectedScript) ? selectedScript : null;
      // Auto-select first script if current selection was removed
      if (current == null && scripts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onChanged(scripts.first);
        });
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Script'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ComboBox<String>(
                  value: current,
                  items: scripts
                      .map((s) => ComboBoxItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                  placeholder: const Text('Select script'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.add, size: 14),
                onPressed: () => _showAddDialog(context, configService),
              ),
            ],
          ),
        ],
      );
    });
  }

  Future<void> _showAddDialog(
      BuildContext context, AppConfigService configService) async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => ContentDialog(
          title: const Text('Add Script'),
          content: TextBox(
            controller: controller,
            placeholder: 'Script name',
            autofocus: true,
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        final result = await configService.addScript(name);
        if (result is Success) {
          onChanged(name);
        }
      }
    } finally {
      controller.dispose();
    }
  }
}
