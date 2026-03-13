import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ScoringProgressDisplay extends StatelessWidget {
  final Rxn<String> statusMessage;
  final RxBool isError;
  final RxBool isProcessing;

  const ScoringProgressDisplay({
    super.key,
    required this.statusMessage,
    required this.isError,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
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
                  isError.value ? FluentIcons.error_badge : FluentIcons.info,
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
        ));
  }
}
