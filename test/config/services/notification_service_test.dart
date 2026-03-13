import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/notification_repository.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late MockNotificationRepository mockRepo;
  late NotificationService service;

  setUpAll(() {
    registerFallbackValue(NotificationEntity(
      type: NotificationType.rotationCompleted,
      severity: NotificationSeverity.info,
      title: '',
      message: '',
      createdAt: DateTime.now(),
    ));
  });

  setUp(() {
    mockRepo = MockNotificationRepository();
    service = NotificationService(mockRepo);
  });

  group('NotificationService', () {
    test('init refreshes unread count', () async {
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 3);
      await service.init();
      expect(service.unreadCount.value, 3);
    });

    test('createNotification inserts and refreshes count', () async {
      when(() => mockRepo.insertNotification(any())).thenAnswer((_) async => 1);
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);

      await service.createNotification(
        type: NotificationType.rotationCompleted,
        severity: NotificationSeverity.info,
        title: 'Done',
        message: 'All good',
      );

      verify(() => mockRepo.insertNotification(any())).called(1);
      expect(service.unreadCount.value, 1);
    });

    test('markAsRead delegates and refreshes count', () async {
      when(() => mockRepo.markAsRead(1)).thenAnswer((_) async {});
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 0);

      await service.markAsRead(1);

      verify(() => mockRepo.markAsRead(1)).called(1);
      expect(service.unreadCount.value, 0);
    });

    test('markAllAsRead delegates and refreshes count', () async {
      when(() => mockRepo.markAllAsRead()).thenAnswer((_) async {});
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 0);

      await service.markAllAsRead();

      verify(() => mockRepo.markAllAsRead()).called(1);
      expect(service.unreadCount.value, 0);
    });

    test('getUnreadNotifications returns list from repo', () async {
      final notifications = [
        NotificationEntity(
          id: 1,
          type: NotificationType.quotaExhausted,
          severity: NotificationSeverity.error,
          title: 'Quota',
          message: 'Exhausted',
          createdAt: DateTime.now(),
        ),
      ];
      when(() => mockRepo.getUnreadNotifications())
          .thenAnswer((_) async => notifications);

      final result = await service.getUnreadNotifications();
      expect(result.length, 1);
      expect(result.first.type, NotificationType.quotaExhausted);
    });

    test('createNotification handles repo error gracefully', () async {
      when(() => mockRepo.insertNotification(any()))
          .thenThrow(Exception('DB error'));

      // Should not throw
      await service.createNotification(
        type: NotificationType.rotationFailed,
        severity: NotificationSeverity.warning,
        title: 'Test',
        message: 'Error',
      );
    });

    test('markAsRead handles repo error gracefully', () async {
      when(() => mockRepo.markAsRead(any())).thenThrow(Exception('DB error'));

      // Should not throw
      await service.markAsRead(1);
    });

    test('markAllAsRead handles repo error gracefully', () async {
      when(() => mockRepo.markAllAsRead()).thenThrow(Exception('DB error'));

      // Should not throw
      await service.markAllAsRead();
    });
  });
}
