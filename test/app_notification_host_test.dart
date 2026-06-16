import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/notifications/app_notification_host.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_notifications/task_completion_sound_player.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_settings_provider.dart';

void main() {
  testWidgets('presents notification without missing overlay errors', (
    tester,
  ) async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appNotificationManagerProvider.overrideWithValue(manager)],
        child: ScreenUtilInit(
          designSize: frameLeanScreenDesignSize,
          fontSizeResolver: frameLeanFontSizeResolver,
          builder: (context, child) {
            return MaterialApp(
              theme: frameLeanLightTheme(),
              builder: (context, child) {
                return AppNotificationHost(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const Scaffold(body: Text('home')),
            );
          },
        ),
      ),
    );

    await manager.notify(
      level: AppNotificationLevel.success,
      title: '应用主题已保存',
      source: 'settings',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('应用主题已保存'), findsOneWidget);
    final cardSize = tester.getSize(
      find.byKey(const ValueKey('app-notification-card')),
    );
    expect(cardSize.width, inInclusiveRange(260, 270));
    expect(cardSize.height, inInclusiveRange(52, 60));
    expect(tester.takeException(), isNull);

    await manager.notify(
      level: AppNotificationLevel.error,
      title: '应用主题保存失败',
      message: 'FFmpeg 路径无效，请重新选择可执行文件',
      source: 'settings',
    );
    await tester.pump();

    expect(find.text('应用主题已保存'), findsOneWidget);
    expect(find.text('应用主题保存失败'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('应用主题已保存'), findsOneWidget);
    expect(find.text('应用主题保存失败'), findsNothing);

    await tester.pump(const Duration(milliseconds: 130));

    expect(find.text('应用主题已保存'), findsNothing);
    expect(find.text('应用主题保存失败'), findsOneWidget);
    expect(find.text('FFmpeg 路径无效，请重新选择可执行文件'), findsOneWidget);
    final failureCardSize = tester.getSize(
      find.byKey(const ValueKey('app-notification-card')),
    );
    expect(failureCardSize.width, 300);
    expect(failureCardSize.height, inInclusiveRange(70, 84));
    expect(tester.takeException(), isNull);

    await manager.notify(
      level: AppNotificationLevel.info,
      title: '第二条通知',
      source: 'test',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await manager.notify(
      level: AppNotificationLevel.success,
      title: '最新通知',
      source: 'test',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('应用主题保存失败'), findsNothing);
    expect(find.text('第二条通知'), findsNothing);
    expect(find.text('最新通知'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('plays selected sound for task completion notifications', (
    tester,
  ) async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    final player = FakeTaskCompletionSoundPlayer();
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appNotificationManagerProvider.overrideWithValue(manager),
          taskCompletionSoundPlayerProvider.overrideWithValue(player),
          appSettingsProvider.overrideWith((ref) {
            return AppSettings.initial().copyWith(
              taskCompletionSound: TaskCompletionSound.servoConfirm,
            );
          }),
        ],
        child: ScreenUtilInit(
          designSize: frameLeanScreenDesignSize,
          fontSizeResolver: frameLeanFontSizeResolver,
          builder: (context, child) {
            return MaterialApp(
              theme: frameLeanLightTheme(),
              builder: (context, child) {
                return AppNotificationHost(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const Scaffold(body: Text('home')),
            );
          },
        ),
      ),
    );

    await manager.notify(
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.success,
      title: 'demo.mp4 处理完成',
      source: 'task',
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(player.playedSounds, [TaskCompletionSound.servoConfirm]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });
}

class FakeTaskCompletionSoundPlayer implements TaskCompletionSoundPlayer {
  final playedSounds = <TaskCompletionSound>[];

  @override
  Future<void> play(TaskCompletionSound sound) async {
    playedSounds.add(sound);
  }
}

class FakeAppNotificationRepository implements AppNotificationRepository {
  final savedNotifications = <AppNotificationEntry>[];

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {}

  @override
  Future<void> dismissAll(DateTime dismissedAt) async {}

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int? limit,
  }) async {
    return savedNotifications.take(limit ?? savedNotifications.length).toList();
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) async {}

  @override
  Future<void> markAllAsRead(DateTime readAt) async {}

  @override
  Future<void> saveNotification(AppNotificationEntry notification) async {
    savedNotifications.add(notification);
  }

  @override
  Future<AppNotificationEntry> upsertNotificationByDedupeKey(
    AppNotificationEntry notification,
  ) async {
    savedNotifications.removeWhere(
      (item) =>
          item.dedupeKey != null && item.dedupeKey == notification.dedupeKey,
    );
    savedNotifications.add(notification);
    return notification;
  }

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int? limit,
  }) async* {
    yield savedNotifications.take(limit ?? savedNotifications.length).toList();
  }
}
