import 'package:fluent_ui/fluent_ui.dart';

class ProcessStatusBadge extends StatelessWidget {
  final bool isRunning;

  const ProcessStatusBadge({super.key, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isRunning
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isRunning ? 'Running' : 'Stopped',
              style: TextStyle(
                color: isRunning ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
