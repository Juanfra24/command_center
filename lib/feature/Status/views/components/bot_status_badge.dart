import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:fluent_ui/fluent_ui.dart';

class BotStatusBadge extends StatelessWidget {
  final ClientStatus? status;
  final int retryCount;

  const BotStatusBadge({
    super.key,
    this.status,
    this.retryCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
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
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _resolve() {
    switch (status) {
      case ClientStatus.running:
        return ('Running', Colors.green);
      case ClientStatus.restarting:
        return (
          'Restarting $retryCount/${WatchdogService.maxRetries}',
          Colors.orange
        );
      case ClientStatus.failed:
        return (
          'Failed $retryCount/${WatchdogService.maxRetries}',
          Colors.orange
        );
      case ClientStatus.stopped:
        return ('Stopped', Colors.grey);
      case ClientStatus.banned:
        return ('Banned', Colors.red);
      case ClientStatus.awaitingAccount:
        return ('Awaiting Account', Colors.blue);
      case null:
        return ('Stopped', Colors.grey);
    }
  }
}
