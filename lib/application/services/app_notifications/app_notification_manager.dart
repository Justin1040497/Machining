import 'dart:async';

import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_info.dart';
import 'package:framelean/domain/value_objects/task_notification_payload.dart';
import 'package:framelean/domain/value_objects/update_notification_payload.dart';
import 'package:uuid/uuid.dart';

typedef AppNotificationActionCallback = void Function();

class AppNotificationAction {
  const AppNotificationAction({
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final String label;
  final AppNotificationActionCallback onPressed;
  final String? tooltip;
}

class AppNotificationPresentation {
  const AppNotificationPresentation({required this.notification, this.action});

  final AppNotificationEntry notification;
  final AppNotificationAction? action;
}

class AppNotificationManager {
  AppNotificationManager({required this.repository});

  final AppNotificationRepository repository;
  final Uuid _uuid = const Uuid();
  final StreamController<AppNotificationPresentation> _presentationController =
      StreamController<AppNotificationPresentation>.broadcast();

  Stream<AppNotificationPresentation> get presentations =>
      _presentationController.stream;

  Future<AppNotificationEntry> notify({
    AppNotificationKind kind = AppNotificationKind.general,
    required AppNotificationLevel level,
    required String title,
    String message = '',
    required String source,
    String? dedupeKey,
    String? payloadJson,
    AppNotificationAction? action,
  }) async {
    final notification = AppNotificationEntry(
      id: _uuid.v4(),
      kind: kind,
      level: level,
      title: title,
      message: message,
      source: source,
      createdAt: DateTime.now(),
      dedupeKey: dedupeKey,
      payloadJson: payloadJson,
    );
    await repository.saveNotification(notification);
    if (!_presentationController.isClosed) {
      _presentationController.add(
        AppNotificationPresentation(notification: notification, action: action),
      );
    }
    return notification;
  }

  Future<AppNotificationEntry> upsert({
    AppNotificationKind kind = AppNotificationKind.general,
    required AppNotificationLevel level,
    required String title,
    String message = '',
    required String source,
    required String dedupeKey,
    String? payloadJson,
    AppNotificationAction? action,
  }) async {
    final notification = AppNotificationEntry(
      id: _uuid.v4(),
      kind: kind,
      level: level,
      title: title,
      message: message,
      source: source,
      createdAt: DateTime.now(),
      dedupeKey: dedupeKey,
      payloadJson: payloadJson,
    );
    final saved = await repository.upsertNotificationByDedupeKey(notification);
    if (!_presentationController.isClosed && !saved.isDismissed) {
      _presentationController.add(
        AppNotificationPresentation(notification: saved, action: action),
      );
    }
    return saved;
  }

  Future<AppNotificationEntry> notifyUpdateAvailable(AppReleaseInfo release) {
    final payload = UpdateNotificationPayload.fromRelease(
      release,
      status: AppUpdateStatus.available,
    );
    return upsert(
      kind: AppNotificationKind.update,
      level: AppNotificationLevel.warning,
      title: '有 ${release.version} 更新',
      message: release.releaseNotesSummary,
      source: 'update',
      dedupeKey: release.notificationDedupeKey,
      payloadJson: payload.toJson(),
    );
  }

  Future<AppNotificationEntry> updateUpdateNotification({
    required AppReleaseInfo release,
    required AppUpdateStatus status,
    required String title,
    AppNotificationLevel level = AppNotificationLevel.info,
  }) {
    final payload = UpdateNotificationPayload.fromRelease(
      release,
      status: status,
    );
    return upsert(
      kind: AppNotificationKind.update,
      level: level,
      title: title,
      message: release.releaseNotesSummary,
      source: 'update',
      dedupeKey: release.notificationDedupeKey,
      payloadJson: payload.toJson(),
    );
  }

  Future<AppNotificationEntry> notifyTaskCompleted(MediaTask task) {
    final payload = TaskNotificationPayload(
      taskId: task.id,
      fileName: task.fileName,
      outputPath: task.outputPath,
    );
    return notify(
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.success,
      title: '任务成功',
      message: task.outputPath?.trim().isNotEmpty == true
          ? '${task.fileName}\n已保存至 ${task.outputPath!.trim()}'
          : '${task.fileName} 已处理完成',
      source: 'task',
      payloadJson: payload.toJson(),
    );
  }

  Future<AppNotificationEntry> notifyTaskFailed(MediaTask task) {
    final payload = TaskNotificationPayload(
      taskId: task.id,
      fileName: task.fileName,
      outputPath: task.outputPath,
    );
    return notify(
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.error,
      title: '任务失败',
      message: task.errorMessage?.trim().isNotEmpty == true
          ? '${task.fileName}\n${task.errorMessage!.trim()}'
          : '${task.fileName}\n媒体处理未能完成',
      source: 'task',
      payloadJson: payload.toJson(),
    );
  }

  Future<void> markAllAsRead() {
    return repository.markAllAsRead(DateTime.now());
  }

  Future<void> dismissAll() {
    return repository.dismissAll(DateTime.now());
  }

  Future<T> track<T>({
    AppNotificationKind kind = AppNotificationKind.general,
    required String source,
    required String successTitle,
    String successMessage = '',
    required String failureTitle,
    String Function(Object error)? failureMessage,
    required Future<T> Function() operation,
  }) async {
    try {
      final result = await operation();
      await notify(
        kind: kind,
        level: AppNotificationLevel.success,
        title: successTitle,
        message: successMessage,
        source: source,
      );
      return result;
    } on Object catch (error) {
      await notify(
        kind: kind,
        level: AppNotificationLevel.error,
        title: failureTitle,
        message: failureMessage?.call(error) ?? error.toString(),
        source: source,
      );
      rethrow;
    }
  }

  void dispose() {
    unawaited(_presentationController.close());
  }
}
