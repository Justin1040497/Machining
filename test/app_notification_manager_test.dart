import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';

void main() {
  test('notify persists and presents a notification', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);

    final presentationFuture = manager.presentations.first;
    final notification = await manager.notify(
      level: AppNotificationLevel.success,
      title: '设置修改并保存成功',
      source: 'settings',
    );
    final presentation = await presentationFuture;

    expect(repository.savedNotifications, [notification]);
    expect(presentation.notification, notification);
    expect(presentation.notification.level, AppNotificationLevel.success);
  });

  test('track records success and returns operation result', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);

    final result = await manager.track<int>(
      source: 'settings',
      successTitle: '设置修改并保存成功',
      failureTitle: '设置保存失败',
      operation: () async => 7,
    );

    expect(result, 7);
    expect(
      repository.savedNotifications.single.level,
      AppNotificationLevel.success,
    );
    expect(repository.savedNotifications.single.title, '设置修改并保存成功');
  });

  test('track records failure and rethrows operation error', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);

    await expectLater(
      manager.track<void>(
        source: 'settings',
        successTitle: '设置修改并保存成功',
        failureTitle: '设置保存失败',
        operation: () async => throw StateError('FFmpeg 路径无效'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      repository.savedNotifications.single.level,
      AppNotificationLevel.error,
    );
    expect(repository.savedNotifications.single.title, '设置保存失败');
    expect(
      repository.savedNotifications.single.message,
      contains('FFmpeg 路径无效'),
    );
  });
}

class FakeAppNotificationRepository implements AppNotificationRepository {
  final savedNotifications = <AppNotificationEntry>[];

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {}

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int limit = 50,
  }) async {
    return savedNotifications.take(limit).toList();
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) async {}

  @override
  Future<void> saveNotification(AppNotificationEntry notification) async {
    savedNotifications.add(notification);
  }

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int limit = 50,
  }) async* {
    yield savedNotifications.take(limit).toList();
  }
}
