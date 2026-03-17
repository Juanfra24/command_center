import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/feature/notification/controller/notification_controller.dart';
import 'package:command_center/feature/notification/views/components/notification_flyout.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class NotificationBell extends StatelessWidget {
  final FlyoutController flyoutController;
  final NotificationService notificationService;
  final NotificationController notificationController;

  const NotificationBell({
    super.key,
    required this.flyoutController,
    required this.notificationService,
    required this.notificationController,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = notificationService.unreadCount.value;
      return FlyoutTarget(
        controller: flyoutController,
        child: IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(FluentIcons.ringer, size: 16),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            notificationController.loadNotifications();
            flyoutController.showFlyout(
              barrierDismissible: true,
              dismissOnPointerMoveAway: false,
              builder: (context) => const NotificationFlyout(),
            );
          },
        ),
      );
    });
  }
}
