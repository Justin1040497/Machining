import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_app_notification_repository.dart';

void main() {
  test('repository saves and loads recent app notifications', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAppNotificationRepository(database);
    final first = AppNotificationEntry(
      id: 'first',
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.success,
      title: '设置修改并保存成功',
      message: '',
      source: 'settings',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final second = AppNotificationEntry(
      id: 'second',
      level: AppNotificationLevel.error,
      title: '设置保存失败',
      message: 'FFmpeg 路径无效',
      source: 'settings',
      createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    await repository.saveNotification(first);
    await repository.saveNotification(second);

    final notifications = await repository.loadRecentNotifications();

    expect(notifications.map((notification) => notification.id), [
      'second',
      'first',
    ]);
    expect(notifications.first.level, AppNotificationLevel.error);
    expect(notifications.first.message, 'FFmpeg 路径无效');
    expect(notifications.last.kind, AppNotificationKind.task);

    await repository.markAllAsRead(DateTime.fromMillisecondsSinceEpoch(3000));
    final readNotifications = await repository.loadRecentNotifications();
    expect(
      readNotifications.every((notification) => !notification.isUnread),
      isTrue,
    );

    await repository.dismissAll(DateTime.fromMillisecondsSinceEpoch(4000));
    expect(await repository.loadRecentNotifications(), isEmpty);
  });

  test('upsert by dedupe key keeps one update notification', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAppNotificationRepository(database);
    const dedupeKey = 'update:windows-x64:1.2.1:5';

    await repository.upsertNotificationByDedupeKey(
      AppNotificationEntry(
        id: 'first-update',
        kind: AppNotificationKind.update,
        level: AppNotificationLevel.warning,
        title: '有 1.2.1 更新',
        message: '第一版摘要',
        source: 'update',
        dedupeKey: dedupeKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    );
    final saved = await repository.upsertNotificationByDedupeKey(
      AppNotificationEntry(
        id: 'second-update',
        kind: AppNotificationKind.update,
        level: AppNotificationLevel.success,
        title: '更新完成',
        message: '完成摘要',
        source: 'update',
        dedupeKey: dedupeKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ),
    );

    final notifications = await repository.loadRecentNotifications();

    expect(notifications, hasLength(1));
    expect(saved.id, 'first-update');
    expect(notifications.single.id, 'first-update');
    expect(notifications.single.title, '更新完成');
    expect(notifications.single.level, AppNotificationLevel.success);
    expect(notifications.single.dedupeKey, dedupeKey);
  });
}
