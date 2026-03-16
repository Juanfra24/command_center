import 'package:command_center/feature/Status/views/components/script_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ScriptPickerFlyout extends StatefulWidget {
  final Widget child;
  final String currentScript;
  final ValueChanged<String> onScriptSelected;

  const ScriptPickerFlyout({
    super.key,
    required this.child,
    required this.currentScript,
    required this.onScriptSelected,
  });

  @override
  State<ScriptPickerFlyout> createState() => _ScriptPickerFlyoutState();
}

class _ScriptPickerFlyoutState extends State<ScriptPickerFlyout> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _openFlyout() {
    _flyoutController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      builder: (context) => FlyoutContent(
        child: SizedBox(
          width: 260,
          child: ScriptSelector(
            selectedScript: widget.currentScript,
            onChanged: (scriptName) {
              widget.onScriptSelected(scriptName);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        onTap: _openFlyout,
        child: widget.child,
      ),
    );
  }
}
