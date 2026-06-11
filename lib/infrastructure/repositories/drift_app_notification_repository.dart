import 'package:drift/drift.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/infrastructure/database/app_database.dart';

class DriftAppNotificationRepository implements AppNotificationRepository {
  DriftAppNotificationRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({int? limit}) {
    final query = database.select(database.appNotificationRows)
      ..where((table) => table.dismissedAt.isNull())
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int? limit,
  }) async {
    final query = database.select(database.appNotificationRows)
      ..where((table) => table.dismissedAt.isNull())
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
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
  Future<void> markAllAsRead(DateTime readAt) {
    return (database.update(
          database.appNotificationRows,
        )..where((table) => table.dismissedAt.isNull() & table.readAt.isNull()))
        .write(
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

  @override
  Future<void> dismissAll(DateTime dismissedAt) {
    return (database.update(
      database.appNotificationRows,
    )..where((table) => table.dismissedAt.isNull())).write(
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
      kind: appNotificationKindFromPersistence(kind),
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
      kind: Value(kind.name),
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

AppNotificationKind appNotificationKindFromPersistence(String value) {
  for (final kind in AppNotificationKind.values) {
    if (kind.name == value) {
      return kind;
    }
  }
  return AppNotificationKind.general;
}

AppNotificationLevel appNotificationLevelFromPersistence(String value) {
  for (final level in AppNotificationLevel.values) {
    if (level.name == value) {
      return level;
    }
  }
  return AppNotificationLevel.info;
}
