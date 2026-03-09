import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// A [FilledButton] that shows a [ProgressRing] + "Processing..." while busy.
///
/// Calls [onConnect] when pressed. Automatically disables itself while
/// [isProcessing] is true.
class ConnectActionButton extends StatelessWidget {
  const ConnectActionButton({
    super.key,
    required this.isProcessing,
    required this.onConnect,
    this.label = 'Connect',
    this.icon = FluentIcons.plug_connected,
  });

  final RxBool isProcessing;
  final VoidCallback onConnect;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => FilledButton(
        onPressed: isProcessing.value ? null : onConnect,
        child: isProcessing.value
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Processing...'),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
