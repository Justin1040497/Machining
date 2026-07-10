import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';

class AppNotificationEntry {
  const AppNotificationEntry({
    required this.id,
    this.kind = AppNotificationKind.general,
    required this.level,
    required this.title,
    required this.message,
    required this.source,
    required this.createdAt,
    this.dedupeKey,
    this.readAt,
    this.dismissedAt,
    this.payloadJson,
  });

  final String id;
  final AppNotificationKind kind;
  final AppNotificationLevel level;
  final String title;
  final String message;
  final String source;
  final DateTime createdAt;
  final String? dedupeKey;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final String? payloadJson;

  bool get isUnread => readAt == null;

  bool get isDismissed => dismissedAt != null;

  String get displayMessage {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return title;
    }
    return '$title：$trimmedMessage';
  }
}
