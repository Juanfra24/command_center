import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// A status bar that shows processing progress, errors, or informational
/// messages.
///
/// Displays a [ProgressRing] while [isProcessing] is true, an error icon when
/// [isError] is true, or an info icon otherwise. The bar is hidden when
/// [statusMessage] is null.
class ProcessingStatusBar extends StatelessWidget {
  const ProcessingStatusBar({
    super.key,
    required this.statusMessage,
    required this.isError,
    required this.isProcessing,
  });

  final Rxn<String> statusMessage;
  final RxBool isError;
  final RxBool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (statusMessage.value == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isError.value
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (isProcessing.value)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: ProgressRing(strokeWidth: 2),
                )
              else
                Icon(
                  isError.value
                      ? FluentIcons.error_badge
                      : FluentIcons.info,
                  size: 14,
                  color: isError.value ? Colors.red : Colors.blue,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMessage.value ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isError.value ? Colors.red : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
