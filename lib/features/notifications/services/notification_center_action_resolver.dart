import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/task_notification_payload.dart';
import 'package:framelean/domain/value_objects/update_notification_payload.dart';

enum NotificationCenterActionType {
  revealOutput,
  openUpdateLog,
  startUpdateDownload,
}

class NotificationCenterActionDescriptor {
  const NotificationCenterActionDescriptor({
    required this.type,
    required this.target,
    required this.tooltip,
    this.label,
  });

  final NotificationCenterActionType type;
  final String target;
  final String tooltip;
  final String? label;
}

abstract final class NotificationCenterActionResolver {
  static List<NotificationCenterActionDescriptor> resolveAll(
    AppNotificationEntry notification,
  ) {
    if (notification.kind == AppNotificationKind.update) {
      return _resolveUpdateActions(notification);
    }

    if (notification.kind != AppNotificationKind.task ||
        notification.level != AppNotificationLevel.success) {
      return const [];
    }

    final payload = TaskNotificationPayload.tryParse(notification.payloadJson);
    final outputPath = payload?.outputPath?.trim();
    if (outputPath == null || outputPath.isEmpty) {
      return const [];
    }

    return [
      NotificationCenterActionDescriptor(
        type: NotificationCenterActionType.revealOutput,
        target: outputPath,
        tooltip: '打开成果物所在位置',
        label: '打开输出文件位置',
      ),
    ];
  }

  static NotificationCenterActionDescriptor? resolve(
    AppNotificationEntry notification,
  ) {
    final actions = resolveAll(notification);
    return actions.isEmpty ? null : actions.first;
  }

  static List<NotificationCenterActionDescriptor> _resolveUpdateActions(
    AppNotificationEntry notification,
  ) {
    final payload = UpdateNotificationPayload.tryParse(
      notification.payloadJson,
    );
    if (payload == null) {
      return const [];
    }

    final target =
        '${payload.platform}:${payload.version}:${payload.buildNumber}';
    final downloadLabel = payload.platform == 'macos-universal2'
        ? '下载 DMG'
        : '下载更新';
    if (payload.status == AppUpdateStatus.completed) {
      return [
        NotificationCenterActionDescriptor(
          type: NotificationCenterActionType.openUpdateLog,
          target: target,
          tooltip: '查看版本日志',
          label: '查看版本日志',
        ),
      ];
    }

    return [
      NotificationCenterActionDescriptor(
        type: NotificationCenterActionType.openUpdateLog,
        target: target,
        tooltip: '查看版本日志',
        label: '查看版本日志',
      ),
      if (payload.status == AppUpdateStatus.available)
        NotificationCenterActionDescriptor(
          type: NotificationCenterActionType.startUpdateDownload,
          target: target,
          tooltip: downloadLabel,
          label: downloadLabel,
        ),
    ];
  }
}
