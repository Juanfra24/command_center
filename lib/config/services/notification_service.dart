import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/notification_repository.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  final NotificationRepository _repository;

  final unreadCount = 0.obs;

  NotificationService(this._repository);

  Future<void> init() async {
    await refreshUnreadCount();
  }

  Future<void> createNotification({
    required NotificationType type,
    required NotificationSeverity severity,
    required String title,
    required String message,
  }) async {
    try {
      await _repository.insertNotification(NotificationEntity(
        type: type,
        severity: severity,
        title: title,
        message: message,
        createdAt: DateTime.now(),
      ));
      await refreshUnreadCount();
    } catch (e) {
      logger.e('Failed to create notification: $e');
    }
  }

  Future<List<NotificationEntity>> getUnreadNotifications() async {
    try {
      return await _repository.getUnreadNotifications();
    } catch (e) {
      logger.e('Failed to get unread notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _repository.markAsRead(id);
      await refreshUnreadCount();
    } catch (e) {
      logger.e('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      await refreshUnreadCount();
    } catch (e) {
      logger.e('Failed to mark all as read: $e');
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      unreadCount.value = await _repository.getUnreadCount();
    } catch (e) {
      logger.e('Failed to refresh unread count: $e');
    }
  }
}
