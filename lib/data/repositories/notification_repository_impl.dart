import 'package:drift/drift.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final AppDatabase _db;

  NotificationRepositoryImpl(this._db);

  @override
  Future<List<NotificationEntity>> getUnreadNotifications() async {
    final rows = await (_db.select(_db.notificationsTable)
          ..where((t) => t.isRead.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_rowToEntity).toList();
  }

  @override
  Future<List<NotificationEntity>> getAllNotifications({int limit = 50}) async {
    final rows = await (_db.select(_db.notificationsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_rowToEntity).toList();
  }

  @override
  Future<int> insertNotification(NotificationEntity notification) async {
    return _db.into(_db.notificationsTable).insert(
          NotificationsTableCompanion.insert(
            type: notification.type.name,
            severity: notification.severity.name,
            title: notification.title,
            message: notification.message,
            isRead: Value(notification.isRead),
            createdAt: Value(notification.createdAt),
            readAt: Value(notification.readAt),
          ),
        );
  }

  @override
  Future<void> markAsRead(int id) async {
    await (_db.update(_db.notificationsTable)..where((t) => t.id.equals(id)))
        .write(NotificationsTableCompanion(
      isRead: const Value(true),
      readAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> markAllAsRead() async {
    final now = DateTime.now();
    await (_db.update(_db.notificationsTable)
          ..where((t) => t.isRead.equals(false)))
        .write(NotificationsTableCompanion(
      isRead: const Value(true),
      readAt: Value(now),
    ));
  }

  @override
  Future<int> getUnreadCount() async {
    final count = _db.notificationsTable.id.count();
    final query = _db.selectOnly(_db.notificationsTable)
      ..addColumns([count])
      ..where(_db.notificationsTable.isRead.equals(false));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  NotificationEntity _rowToEntity(NotificationsTableData row) {
    return NotificationEntity(
      id: row.id,
      type: NotificationType.values.firstWhere(
        (e) => e.name == row.type,
        orElse: () => NotificationType.rotationCompleted,
      ),
      severity: NotificationSeverity.values.firstWhere(
        (e) => e.name == row.severity,
        orElse: () => NotificationSeverity.info,
      ),
      title: row.title,
      message: row.message,
      isRead: row.isRead,
      createdAt: row.createdAt,
      readAt: row.readAt,
    );
  }
}
