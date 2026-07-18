import 'package:framelean/domain/library.dart';

abstract class AppNotificationRepository {
  Stream<List<AppNotificationEntry>> watchRecentNotifications({int? limit});

  Future<List<AppNotificationEntry>> loadRecentNotifications({int? limit});

  Future<void> saveNotification(AppNotificationEntry notification);

  Future<AppNotificationEntry> upsertNotificationByDedupeKey(
    AppNotificationEntry notification,
  );

  Future<void> markAsRead(String id, DateTime readAt);

  Future<void> markAllAsRead(DateTime readAt);

  Future<void> dismiss(String id, DateTime dismissedAt);

  Future<void> dismissAll(DateTime dismissedAt);
}
