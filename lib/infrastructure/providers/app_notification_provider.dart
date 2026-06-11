import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/infrastructure/providers/database_provider.dart';
import 'package:framelean/infrastructure/repositories/drift_app_notification_repository.dart';

final appNotificationRepositoryProvider = Provider<AppNotificationRepository>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return DriftAppNotificationRepository(database);
});

final appNotificationManagerProvider = Provider<AppNotificationManager>((ref) {
  final manager = AppNotificationManager(
    repository: ref.watch(appNotificationRepositoryProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final appNotificationsProvider = StreamProvider<List<AppNotificationEntry>>((
  ref,
) {
  return ref
      .watch(appNotificationRepositoryProvider)
      .watchRecentNotifications();
});

final appNotificationUnreadCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(appNotificationRepositoryProvider)
      .watchRecentNotifications()
      .map(
        (notifications) =>
            notifications.where((notification) => notification.isUnread).length,
      );
});

final appNotificationPresentationsProvider =
    StreamProvider<AppNotificationPresentation>((ref) {
      return ref.watch(appNotificationManagerProvider).presentations;
    });
