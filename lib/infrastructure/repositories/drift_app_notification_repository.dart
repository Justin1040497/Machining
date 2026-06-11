import 'package:drift/drift.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/infrastructure/database/app_database.dart';

class DriftAppNotificationRepository implements AppNotificationRepository {
  DriftAppNotificationRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int limit = 50,
  }) {
    final query = database.select(database.appNotificationRows)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int limit = 50,
  }) async {
    final query = database.select(database.appNotificationRows)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> saveNotification(AppNotificationEntry notification) {
    return database
        .into(database.appNotificationRows)
        .insertOnConflictUpdate(notification.toCompanion());
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) {
    return (database.update(
      database.appNotificationRows,
    )..where((table) => table.id.equals(id))).write(
      AppNotificationRowsCompanion(
        readAt: Value(readAt.millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) {
    return (database.update(
      database.appNotificationRows,
    )..where((table) => table.id.equals(id))).write(
      AppNotificationRowsCompanion(
        dismissedAt: Value(dismissedAt.millisecondsSinceEpoch),
      ),
    );
  }
}

extension AppNotificationRowMapper on AppNotificationRow {
  AppNotificationEntry toDomain() {
    return AppNotificationEntry(
      id: id,
      level: appNotificationLevelFromPersistence(level),
      title: title,
      message: message,
      source: source,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      readAt: readAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(readAt!),
      dismissedAt: dismissedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dismissedAt!),
      payloadJson: payloadJson,
    );
  }
}

extension AppNotificationEntryMapper on AppNotificationEntry {
  AppNotificationRowsCompanion toCompanion() {
    return AppNotificationRowsCompanion(
      id: Value(id),
      level: Value(level.name),
      title: Value(title),
      message: Value(message),
      source: Value(source),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      readAt: Value(readAt?.millisecondsSinceEpoch),
      dismissedAt: Value(dismissedAt?.millisecondsSinceEpoch),
      payloadJson: Value(payloadJson),
    );
  }
}

AppNotificationLevel appNotificationLevelFromPersistence(String value) {
  for (final level in AppNotificationLevel.values) {
    if (level.name == value) {
      return level;
    }
  }
  return AppNotificationLevel.info;
}
