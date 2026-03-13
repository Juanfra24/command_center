import 'package:command_center/domain/entities/notification.dart';

abstract class NotificationRepository {
  Future<List<NotificationEntity>> getUnreadNotifications();
  Future<List<NotificationEntity>> getAllNotifications({int limit = 50});
  Future<int> insertNotification(NotificationEntity notification);
  Future<void> markAsRead(int id);
  Future<void> markAllAsRead();
  Future<int> getUnreadCount();
}
