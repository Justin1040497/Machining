import 'dart:async';

import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/execution/task_execution_notification_summary.dart';
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
  AppNotificationManager({required this.repository, this.readSettings});

  final AppNotificationRepository repository;
  final Future<AppSettings> Function()? readSettings;
  final Uuid _uuid = const Uuid();
  final StreamController<AppNotificationPresentation> _presentationController =
      StreamController<AppNotificationPresentation>.broadcast();

  Stream<AppNotificationPresentation> get presentations =>
      _presentationController.stream;

  Future<AppNotificationEntry> notifyInteraction({
    AppNotificationLevel level = AppNotificationLevel.info,
    required String title,
    String message = '',
    required String source,
  }) async {
    final notification = AppNotificationEntry(
      id: _uuid.v4(),
      kind: AppNotificationKind.interaction,
      level: level,
      title: title,
      message: message,
      source: source,
      createdAt: DateTime.now(),
    );
    return _deliver(
      eventType: NotificationEventType.interactionHint,
      notification: notification,
    );
  }

  Future<AppNotificationEntry> notify({
    AppNotificationKind kind = AppNotificationKind.general,
    required AppNotificationLevel level,
    required String title,
    String message = '',
    required String source,
    String? dedupeKey,
    String? payloadJson,
    AppNotificationAction? action,
    NotificationEventType? eventType,
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
    return _deliver(
      eventType:
          eventType ??
          (level == AppNotificationLevel.error
              ? NotificationEventType.workbenchOperationFailed
              : NotificationEventType.workbenchOperationSucceeded),
      notification: notification,
      action: action,
    );
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
    NotificationEventType eventType = NotificationEventType.updateAvailable,
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
    return _deliver(
      eventType: eventType,
      notification: notification,
      action: action,
      upsert: true,
    );
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
      source: notificationSourceUpdate,
      dedupeKey: release.notificationDedupeKey,
      payloadJson: payload.toJson(),
      eventType: NotificationEventType.updateAvailable,
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
      source: notificationSourceUpdate,
      dedupeKey: release.notificationDedupeKey,
      payloadJson: payload.toJson(),
      eventType: status == AppUpdateStatus.failed
          ? NotificationEventType.updateFailed
          : NotificationEventType.updateAvailable,
    );
  }

  Future<AppNotificationEntry> notifyTaskCompleted(
    MediaTask task, [
    TaskExecutionNotificationSummary? summary,
  ]) {
    final outputPath = summary?.outputPath ?? task.outputPath;
    final payload = TaskNotificationPayload(
      taskId: task.id,
      fileName: task.fileName,
      outputPath: outputPath,
      sourceFileSize:
          summary?.sourceFileSize ?? task.sourceFileFingerprint?.fileSize,
      outputFileSize: summary?.outputFileSize,
      durationMs: summary?.durationMs,
    );
    return notify(
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.success,
      title: '任务成功',
      message: _taskSuccessMessage(task, summary),
      source: notificationSourceTask,
      payloadJson: payload.toJson(),
      eventType: NotificationEventType.taskCompleted,
    );
  }

  Future<AppNotificationEntry> notifyTaskFailed(
    MediaTask task, [
    TaskExecutionNotificationSummary? summary,
  ]) {
    final reason = _failureReason(task, summary);
    final suggestion = summary?.failureSuggestion ?? _failureSuggestion(task);
    final payload = TaskNotificationPayload(
      taskId: task.id,
      fileName: task.fileName,
      outputPath: task.outputPath,
      sourceFileSize:
          summary?.sourceFileSize ?? task.sourceFileFingerprint?.fileSize,
      outputFileSize: summary?.outputFileSize,
      durationMs: summary?.durationMs,
      failureReason: reason,
      failureSuggestion: suggestion,
    );
    return notify(
      kind: AppNotificationKind.task,
      level: AppNotificationLevel.error,
      title: '任务失败',
      message: _taskFailureMessage(
        fileName: task.fileName,
        reason: reason,
        suggestion: suggestion,
      ),
      source: notificationSourceTask,
      payloadJson: payload.toJson(),
      eventType: NotificationEventType.taskFailed,
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
    NotificationEventType successEventType =
        NotificationEventType.settingsSaveSucceeded,
    NotificationEventType failureEventType =
        NotificationEventType.settingsSaveFailed,
  }) async {
    try {
      final result = await operation();
      await notify(
        kind: kind,
        level: AppNotificationLevel.success,
        title: successTitle,
        message: successMessage,
        source: source,
        eventType: successEventType,
      );
      return result;
    } on Object catch (error) {
      await notify(
        kind: kind,
        level: AppNotificationLevel.error,
        title: failureTitle,
        message: failureMessage?.call(error) ?? error.toString(),
        source: source,
        eventType: failureEventType,
      );
      rethrow;
    }
  }

  void dispose() {
    unawaited(_presentationController.close());
  }

  Future<AppNotificationEntry> _deliver({
    required NotificationEventType eventType,
    required AppNotificationEntry notification,
    AppNotificationAction? action,
    bool upsert = false,
  }) async {
    final mode = await _deliveryModeFor(eventType);
    if (mode == NotificationDeliveryMode.disabled) {
      return notification;
    }

    var delivered = notification;
    if (mode == NotificationDeliveryMode.persistent) {
      delivered = upsert
          ? await repository.upsertNotificationByDedupeKey(notification)
          : notification;
      if (!upsert) {
        await repository.saveNotification(delivered);
      }
    }

    if (!_presentationController.isClosed && !delivered.isDismissed) {
      _presentationController.add(
        AppNotificationPresentation(notification: delivered, action: action),
      );
    }
    return delivered;
  }

  Future<NotificationDeliveryMode> _deliveryModeFor(
    NotificationEventType eventType,
  ) async {
    final loader = readSettings;
    if (loader == null) {
      return defaultNotificationPolicies[eventType] ??
          NotificationDeliveryMode.transient;
    }
    try {
      final settings = await loader();
      return settings.notificationPolicies[eventType] ??
          defaultNotificationPolicies[eventType] ??
          NotificationDeliveryMode.transient;
    } on Object {
      return defaultNotificationPolicies[eventType] ??
          NotificationDeliveryMode.transient;
    }
  }
}

String _taskSuccessMessage(
  MediaTask task,
  TaskExecutionNotificationSummary? summary,
) {
  final sourceSize =
      summary?.sourceFileSize ?? task.sourceFileFingerprint?.fileSize;
  final outputSize = summary?.outputFileSize;
  final outputPath = summary?.outputPath ?? task.outputPath;
  return [
    '文件：${task.fileName}',
    '体积：${_formatBytes(sourceSize)} -> ${_formatBytes(outputSize)}',
    '压缩比例：${_formatCompressionReduction(sourceSize, outputSize)}',
    '保存至：${_formatText(outputPath)}',
    '耗时：${_formatDuration(summary?.durationMs)}',
  ].join('\n');
}

String _taskFailureMessage({
  required String fileName,
  required String reason,
  required String suggestion,
}) {
  return ['文件：$fileName', '原因：$reason', '建议：$suggestion'].join('\n');
}

String _failureReason(
  MediaTask task,
  TaskExecutionNotificationSummary? summary,
) {
  // 优先使用 queue runner 已友好化的 failureReason。
  // 若 summary 缺失（防御场景），不直接暴露 task.errorMessage 里的技术细节，
  // 统一走兜底友好文案。
  final reason = summary?.failureReason;
  if (reason != null && reason.trim().isNotEmpty) {
    return reason.trim();
  }
  return '媒体处理未能完成';
}

String _failureSuggestion(MediaTask task) {
  // queue runner 已通过 summary 提供友好建议，此函数仅作 summary 缺失时的兜底。
  // 保留对已有友好化 errorMessage 的场景判断，避免破坏无 summary 的调用路径。
  final reason = task.errorMessage?.trim() ?? '';
  final ineffectiveOutput =
      reason.contains('不小于源文件') ||
      reason.contains('未有效压缩') ||
      reason.contains('无法验证');
  if (task.mediaKind == MediaKind.image && ineffectiveOutput) {
    return '建议切换 WebP/JPG 格式、降低质量，或更换输出格式后重新压缩。';
  }
  if (task.mediaKind == MediaKind.audio && ineffectiveOutput) {
    return '建议降低音频码率、改用更高压缩率的音频格式后重试。';
  }
  return '建议查看任务日志获取详细信息，或重试该任务。';
}

String _formatBytes(int? bytes) {
  if (bytes == null || bytes < 0) {
    return '-';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  if (unitIndex == 0) {
    return '${value.round()} ${units[unitIndex]}';
  }
  final digits = value >= 10 ? 0 : 1;
  final text = value.toStringAsFixed(digits);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} ${units[unitIndex]}';
}

String _formatCompressionReduction(int? sourceSize, int? outputSize) {
  if (sourceSize == null || outputSize == null || sourceSize <= 0) {
    return '-';
  }
  final reduced = ((sourceSize - outputSize) / sourceSize) * 100;
  return '${reduced.toStringAsFixed(1)}%';
}

String _formatDuration(int? durationMs) {
  if (durationMs == null || durationMs < 0) {
    return '-';
  }
  final seconds = (durationMs / 1000).round();
  if (seconds < 60) {
    return '$seconds 秒';
  }
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    return '$minutes 分 $remainingSeconds 秒';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours 小时 $remainingMinutes 分 $remainingSeconds 秒';
}

String _formatText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '-';
  }
  return trimmed;
}
