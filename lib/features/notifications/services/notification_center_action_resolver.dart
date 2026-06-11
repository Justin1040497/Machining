import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/value_objects/task_notification_payload.dart';

enum NotificationCenterActionType { revealOutput }

class NotificationCenterActionDescriptor {
  const NotificationCenterActionDescriptor({
    required this.type,
    required this.target,
  });

  final NotificationCenterActionType type;
  final String target;
}

abstract final class NotificationCenterActionResolver {
  static NotificationCenterActionDescriptor? resolve(
    AppNotificationEntry notification,
  ) {
    if (notification.kind != AppNotificationKind.task ||
        notification.level != AppNotificationLevel.success) {
      return null;
    }

    final payload = TaskNotificationPayload.tryParse(notification.payloadJson);
    final outputPath = payload?.outputPath?.trim();
    if (outputPath == null || outputPath.isEmpty) {
      return null;
    }

    return NotificationCenterActionDescriptor(
      type: NotificationCenterActionType.revealOutput,
      target: outputPath,
    );
  }
}
