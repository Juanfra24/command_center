# Proxy Auto-Rotation — Design Spec

## Status: APPROVED

## Context

The Command Center manages proxy slots via Webshare and scores IPs via IPQualityScore. Currently, when an IP scores poorly, the user must manually navigate to the proxy screen, select the slot, and trigger a replacement. With many proxy slots, this becomes tedious and error-prone. Auto-rotation automates this: after any scoring operation, IPs below a configurable threshold are replaced automatically.

This feature also introduces a persistent notification system to surface auto-rotation events (quota exhaustion, failed replacements) and serve as a foundation for future features (ban alerts, script crashes, etc.).

## Feature Summary

**Proxy Auto-Rotation:** After any IP scoring operation completes, automatically replace IPs that score below a user-configured threshold. On app startup, score all IPs in the background to catch degradation since the last session.

**Notification System:** Database-backed notifications that persist until the user dismisses them. Displayed via a bell icon with unread badge in the window title bar, opening a flyout panel.

---

## Proxy Auto-Rotation

### Trigger: Score-Based

Auto-rotation fires in two scenarios:

1. **After any scoring operation** — When `ProxyScoringController.scoreIpWithIpqs()` or `scoreAllCurrentIps()` completes, the scoring controller passes the results to the auto-rotation service. For batch scoring, the service collects all below-threshold IPs and processes them as a batch after all scoring is done (not per-IP).

2. **On app startup** — After async service initialization completes in `AppBindings.initializeAsyncServices()`, trigger `scoreAllCurrentIps()` in the background if both Webshare and IPQS are configured. This feeds into trigger #1 naturally.

### Configuration

Two new keys in `AppConfigTable` via `AppConfigService`:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `auto_rotation_enabled` | bool | `true` | Master toggle |
| `auto_rotation_threshold` | int | `40` | Replace IPs scoring below this (0-100 scale where 100 is safest) |

### Replacement Logic

`ProxyAutoRotationService` orchestrates the replacement flow:

```
1. Receive list of scored IPs from scoring controller
2. Filter to IPs below threshold (skip if auto-rotation disabled)
3. Sort by score ascending (worst first)
4. For each IP:
   a. Check Webshare quota via ProxyReplacementService.fetchPlanInfo()
   b. If quota exhausted → create "quota_exhausted" notification, stop processing
   c. Call ProxyReplacementService.replaceProxyIp(currentIp, keepSameCountry: true)
   d. If replacement fails → create "rotation_failed" notification, continue to next
   e. Sync with Webshare via ProxySyncService.syncWithWebshare() to get new IP data
   f. Score the new IP via IpqsService.scoreIp() + update via ProxyRepository
   g. If new IP also below threshold → create "rotation_failed" notification with warning, do NOT retry
5. After all replacements: reload proxy data once, create summary notification
```

### Infinite Loop Prevention

After replacing an IP, the new IP is scored. If the new IP also scores below threshold, the service logs a warning and creates a notification but does **not** attempt another replacement for that slot. Each slot gets at most one replacement attempt per rotation cycle. The `_recentlyRotatedSlotIds` set (cleared at the start of each rotation cycle) tracks which slots have already been processed.

### Service Design

**New file:** `lib/config/services/proxy/proxy_auto_rotation_service.dart`

```dart
class ProxyAutoRotationService {
  final ProxyReplacementService _replacementService;
  final WebshareService _webshareService;
  final IpqsService _ipqsService;
  final ProxyRepository _proxyRepository;
  final ProxySyncService _syncService;
  final NotificationService _notificationService;
  final AppConfigService _configService;
```

Constructor injection for all dependencies. All dependencies are services or repositories — no controller dependencies. The auto-rotation service accesses proxy data via `ProxyRepository` and scores IPs via `IpqsService` + `ProxyRepository` directly (not through controllers). Registered in `AppBindings.initializeAsyncServices()` after all its dependencies are available.

The service has one public method:

```dart
/// Process scored IPs and replace any below threshold.
/// Called by ProxyScoringController after scoring completes.
Future<void> processScoreResults(List<ScoredIpResult> results) async;
```

Where `ScoredIpResult` is a simple data class in its own file (`lib/config/services/proxy/scored_ip_result.dart`) to avoid coupling the scoring controller to the auto-rotation service:
```dart
class ScoredIpResult {
  final ProxyIpAddressEntity ip;
  final ProxySlotEntity slot;
  final double score;
  const ScoredIpResult({required this.ip, required this.slot, required this.score});
}
```

### Integration with ProxyScoringController

After `scoreAllCurrentIps()` completes its scoring loop and reloads data, it builds a list of `ScoredIpResult` for all IPs it just scored and calls `_autoRotationService.processScoreResults(results)`.

After single `scoreIpWithIpqs()` completes, it calls the same method with a single-element list.

The auto-rotation service is an optional dependency — if not available (e.g., during tests), scoring works exactly as before.

### Startup Scoring Trigger

In `AppBindings.initializeAsyncServices()`, after all services are initialized, add:

```dart
// 8. Trigger startup scoring in background (non-blocking)
_triggerStartupScoring();
```

This is a fire-and-forget call that:
1. Checks if both Webshare and IPQS are configured
2. Checks staleness: only re-scores IPs whose `lastScoreCheck` is older than 6 hours (avoids burning IPQS quota on every app restart during development)
3. If any stale IPs exist, scores them (which triggers auto-rotation via the normal pathway)
4. Errors are caught and logged, never propagated

---

## Notification System

### Database Table

**New file:** `lib/data/database/tables/notifications_table.dart`

```dart
class NotificationsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();           // e.g., 'quota_exhausted', 'rotation_failed'
  TextColumn get severity => text()();       // 'info', 'warning', 'error'
  TextColumn get title => text()();
  TextColumn get message => text()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get readAt => dateTime().nullable()();
}
```

Schema version bump to 4 (currently 3 after cascade delete). Migration: `m.createTable(notificationsTable)`.

### Entity

**New file:** `lib/domain/entities/notification.dart`

```dart
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
  // ... copyWith, props
}
```

### Repository

**New file:** `lib/domain/repositories/notification_repository.dart` (abstract interface)
**New file:** `lib/data/repositories/notification_repository_impl.dart` (Drift implementation)

Methods:
- `Future<List<NotificationEntity>> getUnreadNotifications()`
- `Future<List<NotificationEntity>> getAllNotifications({int limit = 50})`
- `Future<int> insertNotification(NotificationEntity notification)`
- `Future<void> markAsRead(int id)`
- `Future<void> markAllAsRead()`
- `Future<int> getUnreadCount()`

### Service

**New file:** `lib/config/services/notification_service.dart`

```dart
class NotificationService {
  final NotificationRepository _repository;

  // Observable for UI reactivity
  final unreadCount = 0.obs;

  Future<void> createNotification({
    required NotificationType type,
    required NotificationSeverity severity,
    required String title,
    required String message,
  }) async;

  Future<List<NotificationEntity>> getUnreadNotifications() async;
  Future<void> markAsRead(int id) async;
  Future<void> markAllAsRead() async;
  Future<void> refreshUnreadCount() async;
}
```

The `unreadCount` observable drives the badge in the title bar. It's refreshed after every write operation and on service initialization.

### Controller

**New file:** `lib/feature/notification/controller/notification_controller.dart`

```dart
class NotificationController extends GetxController {
  final NotificationService _notificationService;

  var notifications = <NotificationEntity>[].obs;
  var isLoading = false.obs;

  int get unreadCount => _notificationService.unreadCount.value;

  Future<void> loadNotifications() async;
  Future<void> markAsRead(int id) async;
  Future<void> markAllAsRead() async;
}
```

### UI Components

**Bell icon in title bar** (`lib/core/widgets/window_title_bar.dart`):
- Add a notification bell icon as an action in `WindowTitleBar`
- Show unread count badge when > 0
- Clicking opens a `Flyout` positioned below the bell

**Notification flyout** (`lib/feature/notification/views/components/notification_flyout.dart`):
- Lists only unread notifications, most recent first
- Each notification shows: severity icon (color-coded), title, message, timestamp
- Click individual notification to mark as read (dismisses it from the list)
- "Mark all as read" button at the top (clears the flyout)
- Empty state: "No notifications"
- Max height constrained with scrolling for long lists

**Notification card** (`lib/feature/notification/views/components/notification_card.dart`):
- Severity-colored left border (green=info, orange=warning, red=error)
- Title in bold, message below, relative timestamp ("2 min ago")
- Dismiss button (marks as read, removes from list)

### Settings UI

**In `SettingsSection`**, add a new card between the Music card and the Integrations card (current order: Appearance → Music → **new card here** → Integrations → About):

```
Proxy Auto-Rotation
├── Enable/disable toggle (ToggleSwitch)
├── Score threshold slider (0-100) with label "Replace IPs scoring below {N}"
└── Note: "Runs automatically after IP scoring"
```

---

## Files Affected

### New Files

| File | Layer | Purpose |
|------|-------|---------|
| `lib/config/services/proxy/proxy_auto_rotation_service.dart` | Service | Auto-rotation orchestration |
| `lib/config/services/proxy/scored_ip_result.dart` | Service | Data class shared between scoring controller and auto-rotation service |
| `lib/data/database/tables/notifications_table.dart` | Data | Drift table definition |
| `lib/domain/entities/notification.dart` | Domain | Entity + enums |
| `lib/domain/repositories/notification_repository.dart` | Domain | Abstract interface |
| `lib/data/repositories/notification_repository_impl.dart` | Data | Drift implementation |
| `lib/config/services/notification_service.dart` | Service | Notification business logic |
| `lib/feature/notification/controller/notification_controller.dart` | Controller | UI state |
| `lib/feature/notification/views/components/notification_flyout.dart` | Component | Flyout panel |
| `lib/feature/notification/views/components/notification_card.dart` | Component | Individual notification display |
| `lib/feature/app/views/sections/auto_rotation_settings.dart` | Section | Settings UI section |

### Modified Files

| File | Change |
|------|--------|
| `lib/data/database/app_database.dart` | Add `NotificationsTable` to `@DriftDatabase`, bump schema to 4, add migration |
| `lib/data/database/tables/tables.dart` | Export new table |
| `lib/data/database_service.dart` | Expose `NotificationRepository` |
| `lib/data/repositories/repositories.dart` | Export new repository |
| `lib/domain/repositories/repositories.dart` | Export new abstract repo |
| `lib/domain/entities/entities.dart` | Export new entity |
| `lib/core/resource/dependency_injection.dart` | Register `NotificationService`, `NotificationController`, `ProxyAutoRotationService` |
| `lib/config/services/app_config_service.dart` | Add `auto_rotation_enabled` and `auto_rotation_threshold` config keys + getters/setters |
| `lib/feature/proxy/controller/proxy_scoring_controller.dart` | After scoring, call auto-rotation service |
| `lib/core/widgets/window_title_bar.dart` | Add notification bell icon with badge |
| `lib/feature/app/views/sections/settings_section.dart` | Add auto-rotation settings card |
| `lib/feature/proxy/controller/proxy_replacement_controller.dart` | Refactor to consume `ProxyReplacementService` from DI via `Get.find()` instead of creating it internally |
| `lib/feature/app.dart` | Pass notification bell to title bar actions |

---

## Notification Types for Auto-Rotation

| Type | Severity | When | Title | Message Example |
|------|----------|------|-------|-----------------|
| `rotationCompleted` | info | All replacements succeeded | "Auto-Rotation Complete" | "Replaced 3 proxies. All new IPs scored above threshold." |
| `rotationFailed` | warning | New IP also scored below threshold | "New IP Below Threshold" | "Slot 5: replacement IP scored 32. Manual review recommended." |
| `quotaExhausted` | error | Quota ran out before all replacements | "Replacement Quota Exhausted" | "3 proxies still below threshold. Webshare quota: 0/10 remaining." |

---

## Error Handling

All auto-rotation operations use `Result<T>` for error propagation. The service never throws — it catches all errors, creates appropriate notifications, and logs via `logger`. If the notification service itself fails (DB error), the error is logged but does not crash the rotation.

---

## Testing Strategy

- **Unit tests:** `ProxyAutoRotationService` with mocked dependencies — test threshold filtering, worst-first ordering, quota exhaustion, infinite loop prevention, notification creation
- **Unit tests:** `NotificationService` — CRUD, unread count, mark as read
- **Repository tests:** `NotificationRepositoryImpl` with in-memory Drift database
- **Widget tests:** Notification flyout rendering, bell badge count, settings toggle/slider
