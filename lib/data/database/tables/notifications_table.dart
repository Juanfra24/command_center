import 'package:drift/drift.dart';

/// Table for storing persistent notifications
class NotificationsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get severity => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get readAt => dateTime().nullable()();
}
