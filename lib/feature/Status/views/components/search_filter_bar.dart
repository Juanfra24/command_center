import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/helper/debouncer.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SearchFilterBar extends StatefulWidget {
  final int showingCount;
  final int totalCount;

  const SearchFilterBar({
    super.key,
    required this.showingCount,
    required this.totalCount,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 300);
  late final StatusSelectionController _selectionController;
  late final AppConfigService _configService;

  @override
  void initState() {
    super.initState();
    _selectionController = Get.find<StatusSelectionController>();
    _configService = Get.find<AppConfigService>();
    _searchController.text = _selectionController.searchQuery.value;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: TextBox(
            controller: _searchController,
            placeholder: 'Search accounts...',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search, size: 14),
            ),
            onChanged: (text) {
              _debouncer.run(
                () => _selectionController.searchQuery.value = text,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        _StatusFilterComboBox(selectionController: _selectionController),
        const SizedBox(width: 8),
        _ScriptFilterComboBox(
          selectionController: _selectionController,
          configService: _configService,
        ),
        const Spacer(),
        Obx(
          () => Text(
            'Showing ${widget.showingCount} of ${widget.totalCount}',
            style: FluentTheme.of(context).typography.caption,
          ),
        ),
      ],
    );
  }
}

class _StatusFilterComboBox extends StatelessWidget {
  final StatusSelectionController selectionController;

  const _StatusFilterComboBox({required this.selectionController});

  @override
  Widget build(BuildContext context) {
    return Obx(() => ComboBox<String>(
          value: selectionController.statusFilter.value,
          items: const [
            ComboBoxItem(value: 'all', child: Text('All statuses')),
            ComboBoxItem(value: 'running', child: Text('Running')),
            ComboBoxItem(value: 'stopped', child: Text('Stopped')),
            ComboBoxItem(value: 'banned', child: Text('Banned')),
          ],
          onChanged: (v) {
            if (v != null) selectionController.statusFilter.value = v;
          },
        ));
  }
}

class _ScriptFilterComboBox extends StatelessWidget {
  final StatusSelectionController selectionController;
  final AppConfigService configService;

  const _ScriptFilterComboBox({
    required this.selectionController,
    required this.configService,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final scripts = configService.scriptRegistry.toList();
      final items = [
        const ComboBoxItem<String>(value: 'all', child: Text('All scripts')),
        ...scripts.map(
          (s) => ComboBoxItem<String>(value: s, child: Text(s)),
        ),
      ];
      final currentFilter = selectionController.scriptFilter.value;
      final validValue =
          items.any((i) => i.value == currentFilter) ? currentFilter : 'all';

      return ComboBox<String>(
        value: validValue,
        items: items,
        onChanged: (v) {
          if (v != null) selectionController.scriptFilter.value = v;
        },
      );
    });
  }
}
