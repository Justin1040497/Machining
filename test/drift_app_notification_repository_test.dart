import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
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
  });
}
