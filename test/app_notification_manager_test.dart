import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/value_objects/task_notification_payload.dart';

void main() {
  test('settings save targets expose event-specific notification titles', () {
    expect(AppSettingsSaveTarget.application.successTitle, '应用设置已保存');
    expect(AppSettingsSaveTarget.videoTask.successTitle, '视频任务配置已保存');
    expect(AppSettingsSaveTarget.videoTask.successMessage, '在下次导入任务时应用');
    expect(AppSettingsSaveTarget.imageTask.successTitle, '图片任务配置已保存');
    expect(AppSettingsSaveTarget.audioTask.successTitle, '音频任务配置已保存');
    expect(AppSettingsSaveTarget.output.successTitle, '输出配置已保存');
    expect(
      AppSettingsSaveTarget.output.successMessage,
      '非运行状态的任务已更新；正在处理的任务将在下次处理时使用新配置',
    );
    expect(AppSettingsSaveTarget.encoder.failureTitle, '编码器配置保存失败');
  });

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

  test('task completion notification persists typed output payload', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);
    final completedTask = MediaTask.draft(
      inputPath: '/input/demo.mp4',
      fileName: 'demo.mp4',
      mediaKind: MediaKind.video,
      sortOrder: 0,
    ).markRunning(outputPath: '/output/demo.mp4').markCompleted();

    final notification = await manager.notifyTaskCompleted(completedTask);
    final payload = TaskNotificationPayload.tryParse(notification.payloadJson);

    expect(notification.kind, AppNotificationKind.task);
    expect(notification.level, AppNotificationLevel.success);
    expect(notification.title, 'demo.mp4 处理完成');
    expect(notification.message, '已保存至 /output/demo.mp4');
    expect(payload?.taskId, completedTask.id);
    expect(payload?.outputPath, '/output/demo.mp4');
  });

  test('task failure notification uses file name and failure reason', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);
    final failedTask = MediaTask.draft(
      inputPath: '/input/demo.mp4',
      fileName: 'demo.mp4',
      mediaKind: MediaKind.video,
      sortOrder: 0,
    ).markFailed('编码器不可用');

    final notification = await manager.notifyTaskFailed(failedTask);

    expect(notification.kind, AppNotificationKind.task);
    expect(notification.level, AppNotificationLevel.error);
    expect(notification.title, 'demo.mp4 处理失败');
    expect(notification.message, '编码器不可用');
  });
}

class FakeAppNotificationRepository implements AppNotificationRepository {
  final savedNotifications = <AppNotificationEntry>[];

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {}

  @override
  Future<void> dismissAll(DateTime dismissedAt) async {
    savedNotifications.clear();
  }

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
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int? limit,
  }) async* {
    yield savedNotifications.take(limit ?? savedNotifications.length).toList();
  }
}
