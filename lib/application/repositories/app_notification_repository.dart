import 'package:framelean/domain/entities/app_notification_entry.dart';

abstract class AppNotificationRepository {
  Stream<List<AppNotificationEntry>> watchRecentNotifications({int limit = 50});

  Future<List<AppNotificationEntry>> loadRecentNotifications({int limit = 50});

  Future<void> saveNotification(AppNotificationEntry notification);

  Future<void> markAsRead(String id, DateTime readAt);

  Future<void> dismiss(String id, DateTime dismissedAt);
}
