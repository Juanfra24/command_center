import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/feature/Status/views/components/script_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class LaunchDialog extends StatefulWidget {
  const LaunchDialog({super.key});

  /// Show the dialog and return a LaunchConfig, or null if cancelled.
  static Future<LaunchConfig?> show(BuildContext context) {
    return showDialog<LaunchConfig>(
      context: context,
      builder: (_) => const LaunchDialog(),
    );
  }

  /// Session-scoped last used config for pre-filling.
  static LaunchConfig? _lastConfig;

  @override
  State<LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<LaunchDialog> {
  late String _selectedScript;
  late String _selectedWorld;
  late bool _covert;
  late String _selectedRender;
  final _worldNumberController = TextEditingController();
  final _scriptParamsController = TextEditingController();
  final _advancedFlagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final configService = Get.find<AppConfigService>();
    final last = LaunchDialog._lastConfig;
    _selectedScript = last?.scriptName ?? configService.scriptRegistry.first;
    _selectedWorld = _worldFromConfig(last);
    _covert = last?.covert ?? true;
    _selectedRender = last?.render ?? 'NONE';
    _scriptParamsController.text = last?.scriptParams ?? '';
    _advancedFlagsController.text = last?.advancedFlags ?? '';
  }

  String _worldFromConfig(LaunchConfig? config) {
    if (config == null) return 'auto';
    final w = config.world;
    if (w == 'auto' || w == 'f2p' || w == 'members') return w;
    return 'specific';
  }

  @override
  void dispose() {
    _worldNumberController.dispose();
    _scriptParamsController.dispose();
    _advancedFlagsController.dispose();
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
            _buildCovertToggle(),
            const SizedBox(height: 12),
            _buildRenderSelector(),
            const SizedBox(height: 12),
            _buildScriptParams(),
            const SizedBox(height: 12),
            _buildAdvancedFlags(),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onLaunch,
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

  Widget _buildCovertToggle() {
    return Row(
      children: [
        const Text('Covert mode'),
        const Spacer(),
        ToggleSwitch(
          checked: _covert,
          onChanged: (v) => setState(() => _covert = v),
        ),
      ],
    );
  }

  Widget _buildRenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Render mode'),
        const SizedBox(height: 4),
        ComboBox<String>(
          value: _selectedRender,
          items: const [
            ComboBoxItem(value: 'NONE', child: Text('None')),
            ComboBoxItem(value: 'ALL', child: Text('All')),
            ComboBoxItem(value: 'GAME', child: Text('Game')),
            ComboBoxItem(value: 'SCRIPT', child: Text('Script')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _selectedRender = v);
          },
        ),
      ],
    );
  }

  Widget _buildScriptParams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Script parameters'),
        const SizedBox(height: 4),
        TextBox(
          controller: _scriptParamsController,
          placeholder: 'e.g. tree oak',
        ),
      ],
    );
  }

  Widget _buildAdvancedFlags() {
    return Expander(
      header: const Text('Advanced flags'),
      content: TextBox(
        controller: _advancedFlagsController,
        placeholder: 'e.g. -fps 15',
      ),
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
      covert: _covert,
      render: _selectedRender,
      scriptParams: _scriptParamsController.text.trim(),
      advancedFlags: _advancedFlagsController.text.trim(),
    );

    LaunchDialog._lastConfig = config;
    Navigator.pop(context, config);
  }
}
