import 'package:command_center/feature/notification/controller/notification_controller.dart';
import 'package:command_center/feature/notification/views/components/notification_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class NotificationFlyout extends StatelessWidget {
  const NotificationFlyout({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    final theme = FluentTheme.of(context);

    return Obx(() {
      final notifications = controller.notifications;

      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 360,
          maxHeight: 400,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Text('Notifications', style: theme.typography.bodyStrong),
                  const Spacer(),
                  if (notifications.isNotEmpty)
                    HyperlinkButton(
                      onPressed: controller.markAllAsRead,
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            const Divider(),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child:
                      Text('No notifications', style: theme.typography.caption),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return NotificationCard(
                      notification: notification,
                      onDismiss: () {
                        if (notification.id != null) {
                          controller.markAsRead(notification.id!);
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}
