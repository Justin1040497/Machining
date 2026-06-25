import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/execution/task_execution_notification_summary.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/notification_delivery_mode.dart';
import 'package:framelean/domain/enums/notification_event_type.dart';
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
      eventType: NotificationEventType.taskCompleted,
    );
    final presentation = await presentationFuture;

    expect(repository.savedNotifications, [notification]);
    expect(presentation.notification, notification);
    expect(presentation.notification.level, AppNotificationLevel.success);
  });

  test('interaction notification only presents temporary feedback', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(repository: repository);
    addTearDown(manager.dispose);

    final presentationFuture = manager.presentations.first;
    final notification = await manager.notifyInteraction(
      title: '正在分析，请稍等',
      message: 'demo.mp4',
      source: 'workbench',
    );
    final presentation = await presentationFuture;

    expect(repository.savedNotifications, isEmpty);
    expect(notification.kind, AppNotificationKind.interaction);
    expect(presentation.notification, notification);
  });

  test(
    'track presents transient success and returns operation result',
    () async {
      final repository = FakeAppNotificationRepository();
      final manager = AppNotificationManager(repository: repository);
      addTearDown(manager.dispose);
      final presentationFuture = manager.presentations.first;

      final result = await manager.track<int>(
        source: 'settings',
        successTitle: '设置修改并保存成功',
        failureTitle: '设置保存失败',
        operation: () async => 7,
      );
      final presentation = await presentationFuture;

      expect(result, 7);
      expect(repository.savedNotifications, isEmpty);
      expect(presentation.notification.level, AppNotificationLevel.success);
      expect(presentation.notification.title, '设置修改并保存成功');
    },
  );

  test('disabled delivery suppresses persistence and presentation', () async {
    final repository = FakeAppNotificationRepository();
    final manager = AppNotificationManager(
      repository: repository,
      readSettings: () async => AppSettings.initial().copyWith(
        notificationPolicies: {
          ...defaultNotificationPolicies,
          NotificationEventType.taskCompleted:
              NotificationDeliveryMode.disabled,
        },
      ),
    );
    addTearDown(manager.dispose);
    var presented = false;
    final subscription = manager.presentations.listen((_) => presented = true);
    addTearDown(subscription.cancel);

    await manager.notify(
      level: AppNotificationLevel.success,
      title: '任务完成',
      source: 'task',
      eventType: NotificationEventType.taskCompleted,
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.savedNotifications, isEmpty);
    expect(presented, isFalse);
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

    final notification = await manager.notifyTaskCompleted(
      completedTask,
      const TaskExecutionNotificationSummary(
        sourceFileSize: 10 * 1024 * 1024,
        outputFileSize: 6 * 1024 * 1024,
        durationMs: 6543,
        outputPath: '/output/demo.mp4',
      ),
    );
    final payload = TaskNotificationPayload.tryParse(notification.payloadJson);

    expect(notification.kind, AppNotificationKind.task);
    expect(notification.level, AppNotificationLevel.success);
    expect(notification.title, '任务成功');
    expect(notification.message, contains('文件：demo.mp4'));
    expect(notification.message, contains('体积：10 MB -> 6 MB'));
    expect(notification.message, contains('压缩比例：40.0%'));
    expect(notification.message, contains('保存至：/output/demo.mp4'));
    expect(notification.message, contains('耗时：7 秒'));
    expect(payload?.taskId, completedTask.id);
    expect(payload?.outputPath, '/output/demo.mp4');
    expect(payload?.sourceFileSize, 10 * 1024 * 1024);
    expect(payload?.outputFileSize, 6 * 1024 * 1024);
    expect(payload?.durationMs, 6543);
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

    final notification = await manager.notifyTaskFailed(
      failedTask,
      const TaskExecutionNotificationSummary(
        failureReason: '编码器不可用',
        failureSuggestion: '建议查看任务日志，确认编码器配置后重试。',
      ),
    );

    expect(notification.kind, AppNotificationKind.task);
    expect(notification.level, AppNotificationLevel.error);
    expect(notification.title, '任务失败');
    expect(notification.message, contains('文件：demo.mp4'));
    expect(notification.message, contains('原因：编码器不可用'));
    expect(notification.message, contains('建议：建议查看任务日志，确认编码器配置后重试。'));
  });

  test(
    'image ineffective compression failure suggests another format',
    () async {
      final repository = FakeAppNotificationRepository();
      final manager = AppNotificationManager(repository: repository);
      addTearDown(manager.dispose);
      final failedTask = MediaTask.draft(
        inputPath: '/input/demo.png',
        fileName: 'demo.png',
        mediaKind: MediaKind.image,
        sortOrder: 0,
      ).markFailed('输出文件大小不小于源文件');

      final notification = await manager.notifyTaskFailed(failedTask);

      expect(notification.message, contains('WebP/JPG'));
      expect(notification.message, contains('降低质量'));
    },
  );

  test(
    'hardware encoder session failure shows friendly reason without stderr',
    () async {
      // 验证：硬件编码会话失效时，通知不再暴露 exitCode/stderr 技术细节，
      // 而是展示用户友好的原因和建议。
      final repository = FakeAppNotificationRepository();
      final manager = AppNotificationManager(repository: repository);
      addTearDown(manager.dispose);
      final failedTask =
          MediaTask.draft(
            inputPath: '/input/DJI_0009.MP4',
            fileName: 'DJI_0009.MP4',
            mediaKind: MediaKind.video,
            sortOrder: 0,
          ).markFailed(
            'FFmpeg 退出码: 187\n'
            '[vost#0:0/h264_videotoolbox @ 0xcb6ca8000] Error encoding a frame: Generic error in an external library\n'
            '[vost#0:0/h264_videotoolbox @ 0xcb6ca8000] Task finished with error code: -542398533 (Generic error in an external library)\n'
            'Conversion failed!',
          );

      final notification = await manager.notifyTaskFailed(
        failedTask,
        const TaskExecutionNotificationSummary(
          failureReason: '系统挂起或睡眠导致硬件编码会话中断',
          failureSuggestion: '任务已自动尝试恢复。如仍失败，建议改用软件编码后重试。',
        ),
      );

      expect(notification.message, contains('文件：DJI_0009.MP4'));
      expect(notification.message, contains('系统挂起或睡眠导致硬件编码会话中断'));
      expect(notification.message, isNot(contains('exitCode')));
      expect(notification.message, isNot(contains('h264_videotoolbox')));
      expect(notification.message, isNot(contains('Generic error')));
      expect(notification.message, isNot(contains('Conversion failed')));
      expect(notification.message, contains('软件编码'));
    },
  );

  test(
    'missing summary falls back to friendly reason without exposing stderr',
    () async {
      // 验证：summary 缺失时，_failureReason 不直接吐 task.errorMessage 里的技术细节。
      final repository = FakeAppNotificationRepository();
      final manager = AppNotificationManager(repository: repository);
      addTearDown(manager.dispose);
      final failedTask =
          MediaTask.draft(
            inputPath: '/input/demo.mp4',
            fileName: 'demo.mp4',
            mediaKind: MediaKind.video,
            sortOrder: 0,
          ).markFailed(
            'FFmpeg 退出码: 1\nSome internal stderr garbage\nConversion failed!',
          );

      final notification = await manager.notifyTaskFailed(failedTask);

      expect(notification.message, contains('媒体处理未能完成'));
      expect(notification.message, isNot(contains('FFmpeg 退出码')));
      expect(notification.message, isNot(contains('stderr garbage')));
    },
  );
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
