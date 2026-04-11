import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:get/get.dart';

class NotificationController extends GetxController {
  final NotificationService _notificationService;

  var notifications = <NotificationEntity>[].obs;
  var isLoading = false.obs;
  Worker? _unreadWorker;

  NotificationController(this._notificationService);

  int get unreadCount => _notificationService.unreadCount.value;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
    _unreadWorker =
        ever(_notificationService.unreadCount, (_) => loadNotifications());
  }

  @override
  void onClose() {
    _unreadWorker?.dispose();
    super.onClose();
  }

  Future<void> loadNotifications() async {
    if (isClosed) return;
    isLoading.value = true;
    try {
      final result = await _notificationService.getUnreadNotifications();
      if (isClosed) return;
      notifications.value = result;
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  Future<void> markAsRead(int id) async {
    await _notificationService.markAsRead(id);
    if (isClosed) return;
    notifications.removeWhere((n) => n.id == id);
  }

  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead();
    if (isClosed) return;
    notifications.clear();
  }
}
