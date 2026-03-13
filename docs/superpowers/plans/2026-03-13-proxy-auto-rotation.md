# Proxy Auto-Rotation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically replace proxy IPs that score below a configurable threshold after any scoring operation, with a persistent notification system to surface events.

**Architecture:** Score-triggered auto-rotation service (no timers) that hooks into the existing scoring controller. Database-backed notification system with bell icon + flyout in the title bar. Settings UI for threshold configuration. Startup scoring with 6-hour staleness check.

**Tech Stack:** Flutter/Dart, GetX, Drift ORM, Fluent UI, mocktail for tests

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/data/database/tables/notifications_table.dart` | Drift table definition for notifications |
| `lib/domain/entities/notification.dart` | NotificationEntity + enums (NotificationType, NotificationSeverity) |
| `lib/domain/repositories/notification_repository.dart` | Abstract notification repository interface |
| `lib/data/repositories/notification_repository_impl.dart` | Drift implementation of notification repository |
| `lib/config/services/notification_service.dart` | Notification business logic (CRUD + unread count) |
| `lib/config/services/proxy/scored_ip_result.dart` | ScoredIpResult data class shared between scoring and auto-rotation |
| `lib/config/services/proxy/proxy_auto_rotation_service.dart` | Auto-rotation orchestration logic |
| `lib/feature/notification/controller/notification_controller.dart` | UI state for notification list |
| `lib/feature/notification/views/components/notification_card.dart` | Individual notification display widget |
| `lib/feature/notification/views/components/notification_flyout.dart` | Flyout panel listing unread notifications |
| `lib/feature/app/views/sections/auto_rotation_settings.dart` | Settings UI for auto-rotation toggle + threshold |
| `test/config/services/notification_service_test.dart` | NotificationService unit tests |
| `test/data/repositories/notification_repository_impl_test.dart` | Repository tests with in-memory Drift |
| `test/config/services/proxy_auto_rotation_service_test.dart` | Auto-rotation service unit tests |

### Modified Files

| File | Change |
|------|--------|
| `lib/data/database/app_database.dart` | Add NotificationsTable, bump schema 3→4, migration |
| `lib/data/database/tables/tables.dart` | Export notifications_table |
| `lib/data/database_service.dart` | Expose NotificationRepository |
| `lib/data/repositories/repositories.dart` | Export notification_repository_impl |
| `lib/domain/repositories/repositories.dart` | Export notification_repository |
| `lib/domain/entities/entities.dart` | Export notification entity |
| `lib/config/services/app_config_service.dart` | Add auto_rotation config keys + getters/setters |
| `lib/core/resource/dependency_injection.dart` | Register new services/controllers, move ProxyReplacementService to DI |
| `lib/feature/proxy/controller/proxy_replacement_controller.dart` | Consume ProxyReplacementService from DI |
| `lib/feature/proxy/controller/proxy_scoring_controller.dart` | Build ScoredIpResult list, call auto-rotation after scoring |
| `lib/core/widgets/window_title_bar.dart` | (no changes — bell icon passed via actions param from app.dart) |
| `lib/feature/app.dart` | Pass notification bell widget to title bar actions |
| `lib/feature/app/views/sections/settings_section.dart` | Add auto-rotation settings card |

---

## Chunk 1: Notification System (Database → Repository → Service)

### Task 1: Add NotificationsTable and bump schema to v4

**Files:**
- Create: `lib/data/database/tables/notifications_table.dart`
- Modify: `lib/data/database/tables/tables.dart`
- Modify: `lib/data/database/app_database.dart`

- [ ] **Step 1: Create the Drift table**

```dart
// lib/data/database/tables/notifications_table.dart
import 'package:drift/drift.dart';

/// Table for storing persistent notifications
class NotificationsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get severity => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  BoolColumn get isRead =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get readAt => dateTime().nullable()();
}
```

- [ ] **Step 2: Export from tables barrel**

In `lib/data/database/tables/tables.dart`, add:
```dart
export 'notifications_table.dart';
```

- [ ] **Step 3: Register table in AppDatabase and add migration**

In `lib/data/database/app_database.dart`:
- Add `NotificationsTable` to the `@DriftDatabase(tables: [...])` list
- Change `schemaVersion` from `3` to `4`
- Add migration step in `onUpgrade`:

```dart
if (from < 4) {
  await m.createTable(notificationsTable);
}
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 6: Commit**

```bash
git add lib/data/database/
git commit -m "feat(db): add notifications table, bump schema to v4"
```

---

### Task 2: Create NotificationEntity and repository interface

**Files:**
- Create: `lib/domain/entities/notification.dart`
- Modify: `lib/domain/entities/entities.dart`
- Create: `lib/domain/repositories/notification_repository.dart`
- Modify: `lib/domain/repositories/repositories.dart`

- [ ] **Step 1: Create the entity**

```dart
// lib/domain/entities/notification.dart
import 'package:equatable/equatable.dart';

enum NotificationType {
  rotationCompleted,
  rotationFailed,
  quotaExhausted,
}

enum NotificationSeverity { info, warning, error }

class NotificationEntity extends Equatable {
  final int? id;
  final NotificationType type;
  final NotificationSeverity severity;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const NotificationEntity({
    this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  NotificationEntity copyWith({
    int? id,
    NotificationType? type,
    NotificationSeverity? severity,
    String? title,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, severity, title, message, isRead, createdAt, readAt];
}
```

- [ ] **Step 2: Create the abstract repository**

```dart
// lib/domain/repositories/notification_repository.dart
import 'package:command_center/domain/entities/notification.dart';

abstract class NotificationRepository {
  Future<List<NotificationEntity>> getUnreadNotifications();
  Future<List<NotificationEntity>> getAllNotifications({int limit = 50});
  Future<int> insertNotification(NotificationEntity notification);
  Future<void> markAsRead(int id);
  Future<void> markAllAsRead();
  Future<int> getUnreadCount();
}
```

- [ ] **Step 3: Update barrel exports**

In `lib/domain/entities/entities.dart`, add:
```dart
export 'notification.dart';
```

In `lib/domain/repositories/repositories.dart`, add:
```dart
export 'notification_repository.dart';
```

- [ ] **Step 4: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 5: Commit**

```bash
git add lib/domain/
git commit -m "feat: add NotificationEntity and repository interface"
```

---

### Task 3: Implement NotificationRepositoryImpl with tests

**Files:**
- Create: `lib/data/repositories/notification_repository_impl.dart`
- Modify: `lib/data/repositories/repositories.dart`
- Modify: `lib/data/database_service.dart`
- Create: `test/data/repositories/notification_repository_impl_test.dart`

- [ ] **Step 1: Write the repository implementation**

```dart
// lib/data/repositories/notification_repository_impl.dart
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
    await (_db.update(_db.notificationsTable)
          ..where((t) => t.id.equals(id)))
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
      type: NotificationType.values
          .firstWhere((e) => e.name == row.type,
              orElse: () => NotificationType.rotationCompleted),
      severity: NotificationSeverity.values
          .firstWhere((e) => e.name == row.severity,
              orElse: () => NotificationSeverity.info),
      title: row.title,
      message: row.message,
      isRead: row.isRead,
      createdAt: row.createdAt,
      readAt: row.readAt,
    );
  }
}
```

- [ ] **Step 2: Update barrel and DatabaseService**

In `lib/data/repositories/repositories.dart`, add:
```dart
export 'notification_repository_impl.dart';
```

In `lib/data/database_service.dart`, add:
- Import: `import 'repositories/notification_repository_impl.dart';` and `import '../domain/repositories/notification_repository.dart';`
- New field: `late final NotificationRepository notificationRepository;`
- In `init()`: `notificationRepository = NotificationRepositoryImpl(_database);`

- [ ] **Step 3: Write repository tests**

```dart
// test/data/repositories/notification_repository_impl_test.dart
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

  NotificationEntity _makeNotification({
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
      final id = await repo.insertNotification(_makeNotification());
      expect(id, greaterThan(0));
    });

    test('getUnreadNotifications returns only unread', () async {
      await repo.insertNotification(_makeNotification(title: 'A'));
      await repo.insertNotification(_makeNotification(title: 'B'));
      final id = await repo.insertNotification(_makeNotification(title: 'C'));
      await repo.markAsRead(id);

      final unread = await repo.getUnreadNotifications();
      expect(unread.length, 2);
      expect(unread.every((n) => !n.isRead), true);
    });

    test('getUnreadNotifications returns newest first', () async {
      final earlier = DateTime(2026, 1, 1, 10, 0);
      final later = DateTime(2026, 1, 1, 11, 0);
      await repo.insertNotification(
          _makeNotification(title: 'First', createdAt: earlier));
      await repo.insertNotification(
          _makeNotification(title: 'Second', createdAt: later));

      final unread = await repo.getUnreadNotifications();
      expect(unread.first.title, 'Second');
    });

    test('markAsRead sets isRead and readAt', () async {
      final id = await repo.insertNotification(_makeNotification());
      await repo.markAsRead(id);

      final all = await repo.getAllNotifications();
      expect(all.first.isRead, true);
      expect(all.first.readAt, isNotNull);
    });

    test('markAllAsRead marks all unread as read', () async {
      await repo.insertNotification(_makeNotification(title: 'A'));
      await repo.insertNotification(_makeNotification(title: 'B'));

      await repo.markAllAsRead();

      final unread = await repo.getUnreadNotifications();
      expect(unread, isEmpty);
    });

    test('getUnreadCount returns correct count', () async {
      await repo.insertNotification(_makeNotification());
      await repo.insertNotification(_makeNotification());
      final id = await repo.insertNotification(_makeNotification());
      await repo.markAsRead(id);

      final count = await repo.getUnreadCount();
      expect(count, 2);
    });

    test('getAllNotifications respects limit', () async {
      for (int i = 0; i < 5; i++) {
        await repo.insertNotification(_makeNotification(title: 'N$i'));
      }

      final all = await repo.getAllNotifications(limit: 3);
      expect(all.length, 3);
    });

    test('handles all notification types', () async {
      for (final type in NotificationType.values) {
        await repo.insertNotification(_makeNotification(type: type));
      }
      final all = await repo.getAllNotifications();
      expect(all.length, NotificationType.values.length);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/repositories/notification_repository_impl_test.dart`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add lib/data/ lib/domain/ test/data/repositories/notification_repository_impl_test.dart
git commit -m "feat: add notification repository with Drift implementation and tests"
```

---

### Task 4: Create NotificationService with tests

**Files:**
- Create: `lib/config/services/notification_service.dart`
- Create: `test/config/services/notification_service_test.dart`

- [ ] **Step 1: Write the service**

```dart
// lib/config/services/notification_service.dart
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/repositories/notification_repository.dart';
import 'package:get/get.dart';

class NotificationService {
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
```

- [ ] **Step 2: Write service tests**

```dart
// test/config/services/notification_service_test.dart
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

  setUp(() {
    mockRepo = MockNotificationRepository();
    service = NotificationService(mockRepo);
  });

  setUpAll(() {
    registerFallbackValue(NotificationEntity(
      type: NotificationType.rotationCompleted,
      severity: NotificationSeverity.info,
      title: '',
      message: '',
      createdAt: DateTime.now(),
    ));
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
  });
}
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/config/services/notification_service_test.dart`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add lib/config/services/notification_service.dart test/config/services/notification_service_test.dart
git commit -m "feat: add NotificationService with tests"
```

---

## Chunk 2: Auto-Rotation Service

### Task 5: Add auto-rotation config keys to AppConfigService

**Files:**
- Modify: `lib/config/services/app_config_service.dart`

- [ ] **Step 1: Add config keys, observables, and methods**

Add to the class:

Config keys (alongside existing `_keyWebshareApiKey`, etc.):
```dart
static const String _keyAutoRotationEnabled = 'auto_rotation_enabled';
static const String _keyAutoRotationThreshold = 'auto_rotation_threshold';
```

Observables (alongside existing `webshareApiKey`, etc.):
```dart
final autoRotationEnabled = true.obs;
final autoRotationThreshold = 40.obs;
```

In `loadConfig()`, after existing loads:
```dart
final rotationEnabled =
    await _configRepository!.getValue(_keyAutoRotationEnabled);
autoRotationEnabled.value = rotationEnabled != 'false'; // default true

final threshold =
    await _configRepository!.getValue(_keyAutoRotationThreshold);
autoRotationThreshold.value = int.tryParse(threshold ?? '') ?? 40;
```

New methods:
```dart
Future<Result<void>> saveAutoRotationEnabled(bool enabled) async {
  try {
    if (_configRepository == null) {
      return Result.failure('Config repository not initialized');
    }
    await _configRepository!
        .setValue(_keyAutoRotationEnabled, enabled.toString());
    autoRotationEnabled.value = enabled;
    return Result.success(null);
  } catch (e) {
    logger.e('Error saving auto-rotation enabled: $e');
    return Result.failure('Failed to save auto-rotation setting: $e', e);
  }
}

Future<Result<void>> saveAutoRotationThreshold(int threshold) async {
  try {
    if (_configRepository == null) {
      return Result.failure('Config repository not initialized');
    }
    await _configRepository!
        .setValue(_keyAutoRotationThreshold, threshold.toString());
    autoRotationThreshold.value = threshold;
    return Result.success(null);
  } catch (e) {
    logger.e('Error saving auto-rotation threshold: $e');
    return Result.failure('Failed to save auto-rotation threshold: $e', e);
  }
}
```

- [ ] **Step 2: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 3: Commit**

```bash
git add lib/config/services/app_config_service.dart
git commit -m "feat: add auto-rotation config keys to AppConfigService"
```

---

### Task 6: Create ScoredIpResult and ProxyAutoRotationService with tests

**Files:**
- Create: `lib/config/services/proxy/scored_ip_result.dart`
- Create: `lib/config/services/proxy/proxy_auto_rotation_service.dart`
- Create: `test/config/services/proxy_auto_rotation_service_test.dart`

- [ ] **Step 1: Create ScoredIpResult**

```dart
// lib/config/services/proxy/scored_ip_result.dart
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';

class ScoredIpResult {
  final ProxyIpAddressEntity ip;
  final ProxySlotEntity slot;
  final double score;

  const ScoredIpResult({
    required this.ip,
    required this.slot,
    required this.score,
  });
}
```

- [ ] **Step 2: Create ProxyAutoRotationService**

```dart
// lib/config/services/proxy/proxy_auto_rotation_service.dart
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/proxy/scored_ip_result.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';

class ProxyAutoRotationService {
  final ProxyReplacementService _replacementService;
  final WebshareService _webshareService;
  final IpqsService _ipqsService;
  final ProxyRepository _proxyRepository;
  final ProxySyncService _syncService;
  final NotificationService _notificationService;
  final AppConfigService _configService;

  ProxyAutoRotationService({
    required ProxyReplacementService replacementService,
    required WebshareService webshareService,
    required IpqsService ipqsService,
    required ProxyRepository proxyRepository,
    required ProxySyncService syncService,
    required NotificationService notificationService,
    required AppConfigService configService,
  })  : _replacementService = replacementService,
        _webshareService = webshareService,
        _ipqsService = ipqsService,
        _proxyRepository = proxyRepository,
        _syncService = syncService,
        _notificationService = notificationService,
        _configService = configService;

  final _recentlyRotatedSlotIds = <int>{};
  bool _isRunning = false;

  Future<void> processScoreResults(List<ScoredIpResult> results) async {
    if (_isRunning) {
      logger.w('Auto-rotation: already running, skipping');
      return;
    }
    if (!_configService.autoRotationEnabled.value) return;
    if (!_webshareService.isConfigured.value) return;

    _isRunning = true;
    try {
      await _processResults(results);
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _processResults(List<ScoredIpResult> results) async {
    final threshold = _configService.autoRotationThreshold.value;

    // Filter to below-threshold IPs, sorted worst first
    _recentlyRotatedSlotIds.clear();
    final belowThreshold = results
        .where((r) => r.score < threshold && r.slot.id != null)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score)); // worst first

    if (belowThreshold.isEmpty) return;

    logger.i(
        'Auto-rotation: ${belowThreshold.length} IPs below threshold ($threshold)');

    int replacedCount = 0;
    int failedCount = 0;

    for (final scored in belowThreshold) {
      // Check quota
      final planInfo = await _replacementService.fetchPlanInfo();
      if (planInfo == null || planInfo.proxyReplacementsAvailable <= 0) {
        final remaining = belowThreshold.length - replacedCount - failedCount;
        await _notificationService.createNotification(
          type: NotificationType.quotaExhausted,
          severity: NotificationSeverity.error,
          title: 'Replacement Quota Exhausted',
          message:
              '$remaining proxies still below threshold. Webshare quota: '
              '${planInfo?.proxyReplacementsAvailable ?? 0}/'
              '${planInfo?.proxyReplacementsTotal ?? 0} remaining.',
        );
        logger.w('Auto-rotation: quota exhausted, stopping');
        break;
      }

      // Replace
      _recentlyRotatedSlotIds.add(scored.slot.id!);
      final result = await _replacementService.replaceProxyIp(
        scored.ip,
        keepSameCountry: true,
      );

      switch (result) {
        case Success():
          // Sync to get new IP
          try {
            await _syncService.syncWithWebshare();
          } catch (e) {
            logger.w('Auto-rotation: sync after replacement failed: $e');
          }

          // Score the new IP
          final newIp =
              await _proxyRepository.getActiveIpForSlot(scored.slot.id!);
          if (newIp != null) {
            final scoreResult = await _ipqsService.scoreIp(newIp.ipAddress);
            if (scoreResult.success) {
              final newScore = scoreResult.normalizedScore;
              await _proxyRepository.updateIpAddress(
                newIp.copyWith(
                  ipScore: newScore,
                  scoreLevel:
                      ProxyIpAddressEntity.getScoreLevel(newScore),
                  fraudScore: scoreResult.fraudScore,
                  isVpn: scoreResult.isVpn,
                  isProxy: scoreResult.isProxy,
                  isDatacenter: scoreResult.isDatacenter,
                  isTor: scoreResult.isTor,
                  abuseConfidence: scoreResult.recentAbuse ? 100 : 0,
                  lastScoreCheck: DateTime.now(),
                ),
              );

              if (newScore < threshold) {
                await _notificationService.createNotification(
                  type: NotificationType.rotationFailed,
                  severity: NotificationSeverity.warning,
                  title: 'New IP Below Threshold',
                  message:
                      '${scored.slot.slotName}: replacement IP scored '
                      '${newScore.toStringAsFixed(0)}. Manual review recommended.',
                );
                failedCount++;
              } else {
                replacedCount++;
              }
            } else {
              replacedCount++; // Replacement succeeded even if re-score failed
            }
          } else {
            replacedCount++;
          }

        case Failure(:final message):
          logger.w(
              'Auto-rotation: failed to replace ${scored.slot.slotName}: $message');
          failedCount++;
      }

      // Small delay between replacements
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Summary notification
    if (replacedCount > 0 && failedCount == 0) {
      await _notificationService.createNotification(
        type: NotificationType.rotationCompleted,
        severity: NotificationSeverity.info,
        title: 'Auto-Rotation Complete',
        message:
            'Replaced $replacedCount proxies. All new IPs scored above threshold.',
      );
    } else if (replacedCount > 0 && failedCount > 0) {
      await _notificationService.createNotification(
        type: NotificationType.rotationCompleted,
        severity: NotificationSeverity.info,
        title: 'Auto-Rotation Partial',
        message:
            'Replaced $replacedCount proxies. $failedCount still need attention.',
      );
    } else if (failedCount > 0) {
      await _notificationService.createNotification(
        type: NotificationType.rotationFailed,
        severity: NotificationSeverity.warning,
        title: 'Auto-Rotation Failed',
        message:
            'All $failedCount replacement attempts failed. Manual review recommended.',
      );
    }
  }
}
```

- [ ] **Step 3: Write auto-rotation service tests**

```dart
// test/config/services/proxy_auto_rotation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/proxy/scored_ip_result.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:get/get.dart';

class MockReplacementService extends Mock implements ProxyReplacementService {}
class MockWebshareService extends Mock implements WebshareService {}
class MockIpqsService extends Mock implements IpqsService {}
class MockProxyRepository extends Mock implements ProxyRepository {}
class MockSyncService extends Mock implements ProxySyncService {}
class MockNotificationService extends Mock implements NotificationService {}
class MockAppConfigService extends Mock implements AppConfigService {}

void main() {
  late ProxyAutoRotationService service;
  late MockReplacementService mockReplacement;
  late MockWebshareService mockWebshare;
  late MockIpqsService mockIpqs;
  late MockProxyRepository mockProxyRepo;
  late MockSyncService mockSync;
  late MockNotificationService mockNotification;
  late MockAppConfigService mockConfig;

  final testSlot = ProxySlotEntity(
    id: 1,
    webshareId: 'ws1',
    slotName: 'Slot 1',
    slotNumber: 1,
    username: 'user',
    password: 'pass',
    port: 80,
    createdAt: DateTime.now(),
    lastUpdated: DateTime.now(),
    totalIpChanges: 0,
    isActive: true,
  );

  final testIp = ProxyIpAddressEntity(
    id: 10,
    ipAddress: '1.2.3.4',
    hostname: '1.2.3.4',
    slotId: 1,
    isActive: true,
    countryCode: 'US',
    cityName: 'Test',
    ipTimezone: 'UTC',
    highCountryConfidence: true,
    asnName: 'Test',
    asnNumber: 1234,
    ipScore: 25,
    scoreLevel: IpScoreLevel.bad,
    isVpn: false,
    isProxy: true,
    isDatacenter: true,
    isTor: false,
    fraudScore: 75,
    abuseConfidence: 0,
    assignedAt: DateTime.now(),
    lastVerification: DateTime.now(),
    totalDaysUsed: 0,
    timesAssigned: 1,
  );

  setUp(() {
    mockReplacement = MockReplacementService();
    mockWebshare = MockWebshareService();
    mockIpqs = MockIpqsService();
    mockProxyRepo = MockProxyRepository();
    mockSync = MockSyncService();
    mockNotification = MockNotificationService();
    mockConfig = MockAppConfigService();

    when(() => mockConfig.autoRotationEnabled).thenReturn(true.obs);
    when(() => mockConfig.autoRotationThreshold).thenReturn(40.obs);
    when(() => mockWebshare.isConfigured).thenReturn(true.obs);

    service = ProxyAutoRotationService(
      replacementService: mockReplacement,
      webshareService: mockWebshare,
      ipqsService: mockIpqs,
      proxyRepository: mockProxyRepo,
      syncService: mockSync,
      notificationService: mockNotification,
      configService: mockConfig,
    );
  });

  setUpAll(() {
    registerFallbackValue(testIp);
    registerFallbackValue(NotificationType.rotationCompleted);
    registerFallbackValue(NotificationSeverity.info);
  });

  group('ProxyAutoRotationService', () {
    test('skips when auto-rotation disabled', () async {
      when(() => mockConfig.autoRotationEnabled).thenReturn(false.obs);

      await service.processScoreResults([
        ScoredIpResult(ip: testIp, slot: testSlot, score: 20),
      ]);

      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('skips when webshare not configured', () async {
      when(() => mockWebshare.isConfigured).thenReturn(false.obs);

      await service.processScoreResults([
        ScoredIpResult(ip: testIp, slot: testSlot, score: 20),
      ]);

      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('skips IPs above threshold', () async {
      await service.processScoreResults([
        ScoredIpResult(ip: testIp, slot: testSlot, score: 80),
      ]);

      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('replaces IPs below threshold worst-first', () async {
      final slot2 = testSlot.copyWith(id: 2, slotName: 'Slot 2');
      final ip2 = testIp.copyWith(id: 20, slotId: 2, ipScore: 35);

      when(() => mockReplacement.fetchPlanInfo()).thenAnswer(
          (_) async => WebsharePlanInfo(
              proxyReplacementsAvailable: 5,
              proxyReplacementsTotal: 10,
              proxyReplacementsUsed: 5));
      when(() => mockReplacement.replaceProxyIp(any(), keepSameCountry: true))
          .thenAnswer((_) async => Result.success(null));
      when(() => mockSync.syncWithWebshare()).thenAnswer((_) async {});
      when(() => mockProxyRepo.getActiveIpForSlot(any()))
          .thenAnswer((_) async => testIp.copyWith(ipScore: 80));
      when(() => mockIpqs.scoreIp(any())).thenAnswer((_) async =>
          IpqsResult(success: true, fraudScore: 20,
              isVpn: false, isProxy: true, isDatacenter: true, isTor: false,
              recentAbuse: false));  // normalizedScore = 100 - 20 = 80
      when(() => mockProxyRepo.updateIpAddress(any())).thenAnswer((_) async {});
      when(() => mockNotification.createNotification(
            type: any(named: 'type'),
            severity: any(named: 'severity'),
            title: any(named: 'title'),
            message: any(named: 'message'),
          )).thenAnswer((_) async {});

      await service.processScoreResults([
        ScoredIpResult(ip: ip2, slot: slot2, score: 35),
        ScoredIpResult(ip: testIp, slot: testSlot, score: 25),
      ]);

      // Should call replaceProxyIp twice, worst first (score 25 before 35)
      final calls = verify(
          () => mockReplacement.replaceProxyIp(captureAny(), keepSameCountry: true))
        ..called(2);
      expect((calls.captured[0] as ProxyIpAddressEntity).ipScore, 25);
    });

    test('stops and notifies on quota exhaustion', () async {
      when(() => mockReplacement.fetchPlanInfo()).thenAnswer(
          (_) async => WebsharePlanInfo(
              proxyReplacementsAvailable: 0,
              proxyReplacementsTotal: 10,
              proxyReplacementsUsed: 10));
      when(() => mockNotification.createNotification(
            type: any(named: 'type'),
            severity: any(named: 'severity'),
            title: any(named: 'title'),
            message: any(named: 'message'),
          )).thenAnswer((_) async {});

      await service.processScoreResults([
        ScoredIpResult(ip: testIp, slot: testSlot, score: 20),
      ]);

      verify(() => mockNotification.createNotification(
            type: NotificationType.quotaExhausted,
            severity: NotificationSeverity.error,
            title: any(named: 'title'),
            message: any(named: 'message'),
          )).called(1);
      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('does not retry when new IP also below threshold', () async {
      when(() => mockReplacement.fetchPlanInfo()).thenAnswer(
          (_) async => WebsharePlanInfo(
              proxyReplacementsAvailable: 5,
              proxyReplacementsTotal: 10,
              proxyReplacementsUsed: 5));
      when(() => mockReplacement.replaceProxyIp(any(), keepSameCountry: true))
          .thenAnswer((_) async => Result.success(null));
      when(() => mockSync.syncWithWebshare()).thenAnswer((_) async {});
      when(() => mockProxyRepo.getActiveIpForSlot(any()))
          .thenAnswer((_) async => testIp.copyWith(ipScore: 30));
      when(() => mockIpqs.scoreIp(any())).thenAnswer((_) async =>
          IpqsResult(success: true, fraudScore: 70,
              isVpn: false, isProxy: true, isDatacenter: true, isTor: false,
              recentAbuse: false));  // normalizedScore = 100 - 70 = 30
      when(() => mockProxyRepo.updateIpAddress(any())).thenAnswer((_) async {});
      when(() => mockNotification.createNotification(
            type: any(named: 'type'),
            severity: any(named: 'severity'),
            title: any(named: 'title'),
            message: any(named: 'message'),
          )).thenAnswer((_) async {});

      await service.processScoreResults([
        ScoredIpResult(ip: testIp, slot: testSlot, score: 25),
      ]);

      // Only one replacement call (no retry)
      verify(() => mockReplacement.replaceProxyIp(any(), keepSameCountry: true))
          .called(1);
      // Warning notification created
      verify(() => mockNotification.createNotification(
            type: NotificationType.rotationFailed,
            severity: NotificationSeverity.warning,
            title: any(named: 'title'),
            message: any(named: 'message'),
          )).called(1);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/config/services/proxy_auto_rotation_service_test.dart`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add lib/config/services/proxy/ test/config/services/proxy_auto_rotation_service_test.dart
git commit -m "feat: add ProxyAutoRotationService with score-triggered replacement"
```

---

### Task 7: Register services in DI and refactor ProxyReplacementController

**Files:**
- Modify: `lib/core/resource/dependency_injection.dart`
- Modify: `lib/feature/proxy/controller/proxy_replacement_controller.dart`

- [ ] **Step 1: Register ProxyReplacementService in DI**

In `AppBindings.initializeAsyncServices()`, after step 7 (OnboardingService), add:

```dart
// 8. NotificationService (depends on DatabaseService)
final notificationService =
    NotificationService(databaseService.notificationRepository);
await notificationService.init();
Get.put<NotificationService>(notificationService, permanent: true);
```

In `AppBindings.dependencies()`, add after existing lazy registrations:

```dart
Get.lazyPut<ProxyReplacementService>(
  () => ProxyReplacementService(Get.find<WebshareService>()),
  fenix: true,
);
Get.lazyPut<NotificationController>(
  () => NotificationController(Get.find<NotificationService>()),
  fenix: true,
);
```

`ProxySyncService` is currently created inside `ProxyController`. Register it as a shared DI service so both `ProxyController` and `ProxyAutoRotationService` use the same instance:

```dart
Get.lazyPut<ProxySyncService>(
  () => ProxySyncService(
    Get.find<DatabaseService>().proxyRepository,
    Get.find<WebshareService>(),
    Get.find<DatabaseService>().database,
  ),
  fenix: true,
);
Get.lazyPut<ProxyAutoRotationService>(
  () => ProxyAutoRotationService(
    replacementService: Get.find<ProxyReplacementService>(),
    webshareService: Get.find<WebshareService>(),
    ipqsService: Get.find<IpqsService>(),
    proxyRepository: Get.find<DatabaseService>().proxyRepository,
    syncService: Get.find<ProxySyncService>(),
    notificationService: Get.find<NotificationService>(),
    configService: Get.find<AppConfigService>(),
  ),
  fenix: true,
);
```

Also update `ProxyController` to use `Get.find<ProxySyncService>()` instead of creating its own instance internally.

- [ ] **Step 2: Refactor ProxyReplacementController to use DI**

Replace the `_initReplacementService` method:

```dart
void _initReplacementService() {
  try {
    _replacementService = Get.find<ProxyReplacementService>();

    final webshareService = Get.find<WebshareService>();
    if (webshareService.isConfigured.value) {
      fetchPlanInfo();
    }

    ever(webshareService.isConfigured, (configured) {
      if (configured) fetchPlanInfo();
    });
  } catch (e) {
    logger.w('Replacement service not available yet: $e');
  }
}
```

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 4: Run existing tests**

Run: `flutter test`
Expected: All pass (existing tests unchanged)

- [ ] **Step 5: Commit**

```bash
git add lib/core/resource/dependency_injection.dart lib/feature/proxy/controller/proxy_replacement_controller.dart
git commit -m "refactor: register services in DI, refactor ProxyReplacementController"
```

---

### Task 8: Integrate auto-rotation into ProxyScoringController

**Files:**
- Modify: `lib/feature/proxy/controller/proxy_scoring_controller.dart`

- [ ] **Step 1: Add auto-rotation integration**

Add an optional dependency on `ProxyAutoRotationService`:

```dart
ProxyAutoRotationService? _autoRotationService;
```

In `onInit()`, after `_initIpqs()`:
```dart
try {
  _autoRotationService = Get.find<ProxyAutoRotationService>();
} catch (_) {
  // Optional — auto-rotation not available
}
```

Modify `scoreIpWithIpqs` to return the `ScoredIpResult` data by capturing the score. After the `if (result.success)` block that updates the DB (around line 93-109), add after the `return true`:

Change the method to also call auto-rotation after single scoring. The cleanest approach: build the `ScoredIpResult` and pass it after each single score:

After the existing `return true;` inside the `if (result.success)` block, add before the return:
```dart
// Trigger auto-rotation for this single IP
if (_autoRotationService != null) {
  final slot = _proxyController.proxySlots
      .firstWhereOrNull((s) => s.id == ip.slotId);
  if (slot != null) {
    await _autoRotationService!.processScoreResults([
      ScoredIpResult(ip: ip, slot: slot, score: newScore),
    ]);
    // Reload after auto-rotation may have changed IPs
    await _proxyController.loadIpAddresses();
  }
}
```

At the end of `scoreAllCurrentIps()`, after the single reload, add before the `return successCount`:
```dart
// Trigger auto-rotation for all scored IPs
if (_autoRotationService != null) {
  final results = <ScoredIpResult>[];
  for (final slot in _proxyController.proxySlots) {
    final currentIp = _proxyController.getCurrentIpForSlot(slot);
    if (currentIp != null && currentIp.hasBeenScored) {
      results.add(ScoredIpResult(
        ip: currentIp,
        slot: slot,
        score: currentIp.ipScore,
      ));
    }
  }
  await _autoRotationService!.processScoreResults(results);
  // Reload after auto-rotation may have changed IPs
  await _proxyController.loadIpAddresses();
}
```

Add imports:
```dart
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/proxy/scored_ip_result.dart';
```

- [ ] **Step 2: Add startup scoring trigger**

Add a `skipStale` parameter to `scoreAllCurrentIps()` to allow startup scoring to skip recently-checked IPs without affecting user-triggered "Score All":

```dart
Future<int> scoreAllCurrentIps({bool skipStale = false}) async {
```

In the `for` loop in `scoreAllCurrentIps()`, after `if (currentIp != null) {`, add:
```dart
  // Skip IPs scored within the last 6 hours (for startup scoring only)
  if (skipStale &&
      currentIp.lastScoreCheck != null &&
      DateTime.now().difference(currentIp.lastScoreCheck!).inHours < 6) {
    continue;
  }
```

Add the startup trigger in `lib/feature/proxy/controller/proxy_scoring_controller.dart` — inside `onReady()` (not `initializeAsyncServices()`, since controllers are lazy and not yet registered during service init):

```dart
@override
void onReady() {
  super.onReady();
  _triggerStartupScoring();
}

void _triggerStartupScoring() {
  try {
    final webshare = Get.find<WebshareService>();
    final ipqs = Get.find<IpqsService>();
    if (!webshare.isConfigured.value || !ipqs.isConfigured.value) return;

    // Fire and forget — score stale IPs in background
    Future(() async {
      try {
        await scoreAllCurrentIps(skipStale: true);
      } catch (e) {
        logger.e('Startup scoring failed: $e');
      }
    });
  } catch (_) {
    // Services not available, skip
  }
}
```

This triggers when the scoring controller is first activated (when the user navigates to the proxy screen), ensuring all DI dependencies are available.

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add lib/feature/proxy/controller/proxy_scoring_controller.dart lib/core/resource/dependency_injection.dart
git commit -m "feat: integrate auto-rotation into scoring controller with startup trigger"
```

---

## Chunk 3: Notification UI + Settings

### Task 9: Create NotificationController

**Files:**
- Create: `lib/feature/notification/controller/notification_controller.dart`

- [ ] **Step 1: Write the controller**

```dart
// lib/feature/notification/controller/notification_controller.dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/feature/notification/
git commit -m "feat: add NotificationController"
```

---

### Task 10: Create notification UI components

**Files:**
- Create: `lib/feature/notification/views/components/notification_card.dart`
- Create: `lib/feature/notification/views/components/notification_flyout.dart`

- [ ] **Step 1: Create NotificationCard**

```dart
// lib/feature/notification/views/components/notification_card.dart
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
```

- [ ] **Step 2: Create NotificationFlyout**

```dart
// lib/feature/notification/views/components/notification_flyout.dart
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
                  Text('Notifications',
                      style: theme.typography.bodyStrong),
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
                  child: Text('No notifications',
                      style: theme.typography.caption),
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/feature/notification/
git commit -m "feat: add notification card and flyout UI components"
```

---

### Task 11: Add notification bell to title bar

**Files:**
- Modify: `lib/feature/app.dart`

- [ ] **Step 1: Add bell icon to title bar actions**

In `lib/feature/app.dart`, the title bar is built in the `build` method. Find where `WindowTitleBar` is constructed and add a notification bell widget to the `actions` list.

Read the file to find the exact location, then add a bell icon widget with badge. The bell uses a `FlyoutController` to show the notification flyout on tap. Wrap in `Obx` to reactively show badge count.

The implementation should:
1. Import `NotificationController`, `NotificationFlyout`
2. Add a `FlyoutController` to `_AppState`
3. Dispose the `FlyoutController` in `_AppState.dispose()`
4. In the title bar actions, add a bell icon button with `Flyout` wrapper
5. Show unread count badge when > 0 (bind to `Get.find<NotificationService>().unreadCount` inside `Obx` for reactivity)

- [ ] **Step 2: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 3: Commit**

```bash
git add lib/feature/app.dart
git commit -m "feat: add notification bell with badge to window title bar"
```

---

### Task 12: Add auto-rotation settings section

**Files:**
- Create: `lib/feature/app/views/sections/auto_rotation_settings.dart`
- Modify: `lib/feature/app/views/sections/settings_section.dart`

- [ ] **Step 1: Create auto-rotation settings widget**

```dart
// lib/feature/app/views/sections/auto_rotation_settings.dart
import 'package:command_center/config/services/app_config_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class AutoRotationSettings extends StatelessWidget {
  const AutoRotationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    try {
      final configService = Get.find<AppConfigService>();
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FluentIcons.sync, color: theme.accentColor),
                const SizedBox(width: 8),
                Text('Proxy Auto-Rotation',
                    style: theme.typography.bodyLarge),
              ],
            ),
            const SizedBox(height: 16),
            Obx(() {
              final enabled = configService.autoRotationEnabled.value;
              final threshold =
                  configService.autoRotationThreshold.value.toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ToggleSwitch(
                    checked: enabled,
                    onChanged: (value) =>
                        configService.saveAutoRotationEnabled(value),
                    content: const Text(
                        'Automatically replace low-scoring proxies'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Replace IPs scoring below ${threshold.round()}',
                    style: theme.typography.body,
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: threshold,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: enabled
                        ? (value) => configService
                            .saveAutoRotationThreshold(value.round())
                        : null,
                    label: '${threshold.round()}',
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Text('Runs automatically after IP scoring',
                style: theme.typography.caption),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
```

- [ ] **Step 2: Add to SettingsSection**

In `lib/feature/app/views/sections/settings_section.dart`, import the new widget and add it between the music card and integrations card:

```dart
_buildMusicCard(context),
const SizedBox(height: 16),
const AutoRotationSettings(),  // NEW
const SizedBox(height: 16),
_buildIntegrationsCard(context),
```

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 4: Commit**

```bash
git add lib/feature/app/views/sections/ lib/feature/app/views/sections/settings_section.dart
git commit -m "feat: add auto-rotation settings UI section"
```

---

### Task 13: Final verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All pass

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 3: Regenerate Drift code (in case of any drift)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Succeeds

- [ ] **Step 4: Format (after Drift regen to include generated files)**

Run: `dart format --set-exit-if-changed .`
Expected: Exit code 0 (fix any formatting issues if not)

- [ ] **Step 5: Commit any formatting fixes**

```bash
git add -A
git commit -m "style: format and verify proxy auto-rotation feature"
```
