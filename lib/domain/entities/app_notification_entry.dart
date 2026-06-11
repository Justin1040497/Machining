import 'package:framelean/domain/enums/app_notification_level.dart';

class AppNotificationEntry {
  const AppNotificationEntry({
    required this.id,
    required this.level,
    required this.title,
    required this.message,
    required this.source,
    required this.createdAt,
    this.readAt,
    this.dismissedAt,
    this.payloadJson,
  });

  final String id;
  final AppNotificationLevel level;
  final String title;
  final String message;
  final String source;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final String? payloadJson;

  String get displayMessage {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return title;
    }
    return '$title：$trimmedMessage';
  }
}
