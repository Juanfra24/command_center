import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/config/theme/status_colors.dart';
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
    final colors = StatusColors.of(context);
    final (label, color) = _resolve(colors);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
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
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _resolve(StatusColors colors) {
    switch (status) {
      case ClientStatus.running:
        return ('Running', colors.success);
      case ClientStatus.restarting:
        return (
          'Restarting $retryCount/${WatchdogService.maxRetries}',
          colors.warning,
        );
      case ClientStatus.failed:
        return (
          'Failed $retryCount/${WatchdogService.maxRetries}',
          colors.warning,
        );
      case ClientStatus.stopped:
        return ('Stopped', colors.muted);
      case ClientStatus.banned:
        return ('Banned', colors.error);
      case ClientStatus.awaitingAccount:
        return ('Awaiting Account', colors.info);
      case null:
        return ('Stopped', colors.muted);
    }
  }
}
