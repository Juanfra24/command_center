import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:get/get.dart';

class NotificationController extends GetxController {
  final NotificationService _notificationService;

  var notifications = <NotificationEntity>[].obs;
  var isLoading = false.obs;

  NotificationController(this._notificationService);

  int get unreadCount => _notificationService.unreadCount.value;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      notifications.value =
          await _notificationService.getUnreadNotifications();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(int id) async {
    await _notificationService.markAsRead(id);
    notifications.removeWhere((n) => n.id == id);
  }

  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead();
    notifications.clear();
  }
}
