import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_notifications/task_completion_sound_player.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/app/providers/database_provider.dart';
import 'package:framelean/infrastructure/repositories/drift_app_notification_repository.dart';
import 'package:framelean/infrastructure/services/app_notifications/local_task_completion_sound_player.dart';
import 'package:framelean/app/providers/repository_provider.dart';

final appNotificationRepositoryProvider = Provider<AppNotificationRepository>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return DriftAppNotificationRepository(database);
});

final appNotificationManagerProvider = Provider<AppNotificationManager>((ref) {
  final manager = AppNotificationManager(
    repository: ref.watch(appNotificationRepositoryProvider),
    readSettings: ref.watch(appSettingsRepositoryProvider).loadSettings,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final taskCompletionSoundPlayerProvider = Provider<TaskCompletionSoundPlayer>((
  ref,
) {
  final player = LocalTaskCompletionSoundPlayer();
  ref.onDispose(() {
    unawaited(player.dispose());
  });
  return player;
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
