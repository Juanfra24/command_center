import 'package:command_center/domain/entities/notification.dart';
import 'package:fluent_ui/fluent_ui.dart';

class NotificationCard extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = _severityColor(notification.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_severityIcon(notification.severity),
                color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: theme.typography.bodyStrong),
                  const SizedBox(height: 2),
                  Text(notification.message,
                      style: theme.typography.caption),
                  const SizedBox(height: 4),
                  Text(_formatTime(notification.createdAt),
                      style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 10),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }

  static Color _severityColor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return Colors.green;
      case NotificationSeverity.warning:
        return Colors.orange;
      case NotificationSeverity.error:
        return Colors.red;
    }
  }

  static IconData _severityIcon(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return FluentIcons.info;
      case NotificationSeverity.warning:
        return FluentIcons.warning;
      case NotificationSeverity.error:
        return FluentIcons.error_badge;
    }
  }

  static String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
