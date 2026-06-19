import 'dart:async';

import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/execution/task_execution_notification_summary.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/enums/media_kind.dart';
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
      readAt: DateTime.now(),
      dismissedAt: DateTime.now(),
    );
    if (!_presentationController.isClosed) {
      _presentationController.add(
        AppNotificationPresentation(notification: notification),
      );
    }
    return notification;
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
      source: 'task',
      payloadJson: payload.toJson(),
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
  final reason = summary?.failureReason ?? task.errorMessage;
  if (reason == null || reason.trim().isEmpty) {
    return '媒体处理未能完成';
  }
  return reason.trim();
}

String _failureSuggestion(MediaTask task) {
  final reason = task.errorMessage?.trim() ?? '';
  final ineffectiveOutput =
      reason.contains('不小于源文件') ||
      reason.contains('未有效压缩') ||
      reason.contains('无法验证');
  if (task.mediaKind == MediaKind.image && ineffectiveOutput) {
    return '建议切换 WebP/JPG 格式、降低质量，或更换输出格式后重新压缩。';
  }
  return '建议查看任务日志，确认源文件、输出目录和 FFmpeg 运行时后重试。';
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
