import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/feature/Status/views/components/script_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class LaunchDialog extends StatefulWidget {
  const LaunchDialog({super.key});

  static Future<LaunchConfig?> show(BuildContext context) =>
      showDialog<LaunchConfig>(
          context: context, builder: (_) => const LaunchDialog());

  static LaunchConfig? _lastConfig;

  @override
  State<LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<LaunchDialog> {
  late String _selectedScript;
  late String _selectedWorld;
  final _worldNumberController = TextEditingController();
  final _scriptParamsController = TextEditingController();
  final _advancedFlagsController = TextEditingController();
  final _jvmArgsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final configService = Get.find<AppConfigService>();
    final last = LaunchDialog._lastConfig;
    final registry = configService.scriptRegistry;
    final lastScript = last?.scriptName;
    _selectedScript = (lastScript != null && registry.contains(lastScript))
        ? lastScript
        : (registry.isNotEmpty ? registry.first : '');
    final w = last?.world ?? 'auto';
    _selectedWorld =
        const {'auto', 'f2p', 'members'}.contains(w) ? w : 'specific';
    if (_selectedWorld == 'specific') {
      _worldNumberController.text = w;
    }
    _scriptParamsController.text = last?.scriptParams ?? '';
    _advancedFlagsController.text = last?.advancedFlags ?? '';
    _jvmArgsController.text = last?.jvmArgs ?? '';
  }

  @override
  void dispose() {
    _worldNumberController.dispose();
    _scriptParamsController.dispose();
    _advancedFlagsController.dispose();
    _jvmArgsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Launch Configuration'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ScriptSelector(
              selectedScript: _selectedScript,
              onChanged: (v) => setState(() => _selectedScript = v),
            ),
            const SizedBox(height: 12),
            _buildWorldSelector(),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'JVM Arguments',
              child: TextBox(
                controller: _jvmArgsController,
                placeholder: '-Xmx512m (default)',
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Script parameters'),
                const SizedBox(height: 4),
                TextBox(
                  controller: _scriptParamsController,
                  placeholder: 'e.g. tree oak',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expander(
              header: const Text('Advanced flags'),
              content: TextBox(
                controller: _advancedFlagsController,
                placeholder: 'e.g. -fps 15',
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedScript.isNotEmpty ? _onLaunch : null,
          child: const Text('Launch'),
        ),
      ],
    );
  }

  Widget _buildWorldSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('World'),
        const SizedBox(height: 4),
        Row(
          children: [
            ComboBox<String>(
              value: _selectedWorld,
              items: const [
                ComboBoxItem(value: 'auto', child: Text('Auto')),
                ComboBoxItem(value: 'f2p', child: Text('F2P')),
                ComboBoxItem(value: 'members', child: Text('Members')),
                ComboBoxItem(value: 'specific', child: Text('World #')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedWorld = v);
              },
            ),
            if (_selectedWorld == 'specific') ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: NumberBox<int>(
                  value: int.tryParse(_worldNumberController.text),
                  onChanged: (v) {
                    _worldNumberController.text = v?.toString() ?? '';
                  },
                  min: 1,
                  max: 999,
                  placeholder: '#',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _onLaunch() {
    String world = _selectedWorld;
    if (world == 'specific') {
      world = _worldNumberController.text.isNotEmpty
          ? _worldNumberController.text
          : 'auto';
    }

    final config = LaunchConfig(
      scriptName: _selectedScript,
      world: world,
      scriptParams: _scriptParamsController.text.trim(),
      advancedFlags: _advancedFlagsController.text.trim(),
      jvmArgs: _jvmArgsController.text.trim().isEmpty
          ? null
          : _jvmArgsController.text.trim(),
    );

    LaunchDialog._lastConfig = config;
    Navigator.pop(context, config);
  }
}
