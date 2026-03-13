import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/repositories/notification_repository_impl.dart';
import 'package:command_center/domain/entities/notification.dart';

void main() {
  late AppDatabase db;
  late NotificationRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotificationRepositoryImpl(db);
  });

  tearDown(() => db.close());

  NotificationEntity makeNotification({
    NotificationType type = NotificationType.rotationCompleted,
    NotificationSeverity severity = NotificationSeverity.info,
    String title = 'Test',
    String message = 'Test message',
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      type: type,
      severity: severity,
      title: title,
      message: message,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  group('NotificationRepositoryImpl', () {
    test('insertNotification returns id', () async {
      final id = await repo.insertNotification(makeNotification());
      expect(id, greaterThan(0));
    });

    test('getUnreadNotifications returns only unread', () async {
      await repo.insertNotification(makeNotification(title: 'A'));
      await repo.insertNotification(makeNotification(title: 'B'));
      final id = await repo.insertNotification(makeNotification(title: 'C'));
      await repo.markAsRead(id);

      final unread = await repo.getUnreadNotifications();
      expect(unread.length, 2);
      expect(unread.every((n) => !n.isRead), true);
    });

    test('getUnreadNotifications returns newest first', () async {
      final earlier = DateTime(2026, 1, 1, 10, 0);
      final later = DateTime(2026, 1, 1, 11, 0);
      await repo.insertNotification(
          makeNotification(title: 'First', createdAt: earlier));
      await repo.insertNotification(
          makeNotification(title: 'Second', createdAt: later));

      final unread = await repo.getUnreadNotifications();
      expect(unread.first.title, 'Second');
    });

    test('markAsRead sets isRead and readAt', () async {
      final id = await repo.insertNotification(makeNotification());
      await repo.markAsRead(id);

      final all = await repo.getAllNotifications();
      expect(all.first.isRead, true);
      expect(all.first.readAt, isNotNull);
    });

    test('markAllAsRead marks all unread as read', () async {
      await repo.insertNotification(makeNotification(title: 'A'));
      await repo.insertNotification(makeNotification(title: 'B'));

      await repo.markAllAsRead();

      final unread = await repo.getUnreadNotifications();
      expect(unread, isEmpty);
    });

    test('getUnreadCount returns correct count', () async {
      await repo.insertNotification(makeNotification());
      await repo.insertNotification(makeNotification());
      final id = await repo.insertNotification(makeNotification());
      await repo.markAsRead(id);

      final count = await repo.getUnreadCount();
      expect(count, 2);
    });

    test('getAllNotifications respects limit', () async {
      for (int i = 0; i < 5; i++) {
        await repo.insertNotification(makeNotification(title: 'N$i'));
      }

      final all = await repo.getAllNotifications(limit: 3);
      expect(all.length, 3);
    });

    test('handles all notification types', () async {
      for (final type in NotificationType.values) {
        await repo.insertNotification(makeNotification(type: type));
      }
      final all = await repo.getAllNotifications();
      expect(all.length, NotificationType.values.length);
    });
  });
}
