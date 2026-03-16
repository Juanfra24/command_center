import 'package:equatable/equatable.dart';

enum NotificationType {
  rotationCompleted,
  rotationFailed,
  quotaExhausted,
  banDetected,
  maxRetriesReached,
  clientRelaunched,
  clientFailed,
  toast, // Toast-originated persistent notifications
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
