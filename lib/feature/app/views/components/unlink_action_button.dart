import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// A red-tinted "Unlink" button that shows a [ProgressRing] while processing.
///
/// Calls [onUnlink] when pressed. Automatically disables itself while
/// [isProcessing] is true.
class UnlinkActionButton extends StatelessWidget {
  const UnlinkActionButton({
    super.key,
    required this.isProcessing,
    required this.onUnlink,
  });

  final RxBool isProcessing;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Button(
        style: ButtonStyle(
          backgroundColor:
              WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
        ),
        onPressed: isProcessing.value ? null : onUnlink,
        child: isProcessing.value
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.plug_disconnected, size: 14),
                  SizedBox(width: 8),
                  Text('Unlink'),
                ],
              ),
      ),
    );
  }
}
