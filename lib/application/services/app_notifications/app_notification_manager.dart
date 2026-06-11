import 'dart:async';

import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:uuid/uuid.dart';

typedef AppNotificationActionCallback = void Function();

class AppNotificationAction {
  const AppNotificationAction({required this.label, required this.onPressed});

  final String label;
  final AppNotificationActionCallback onPressed;
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
    required AppNotificationLevel level,
    required String title,
    String message = '',
    required String source,
    String? payloadJson,
    AppNotificationAction? action,
  }) async {
    final notification = AppNotificationEntry(
      id: _uuid.v4(),
      level: level,
      title: title,
      message: message,
      source: source,
      createdAt: DateTime.now(),
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

  Future<T> track<T>({
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
        level: AppNotificationLevel.success,
        title: successTitle,
        message: successMessage,
        source: source,
      );
      return result;
    } on Object catch (error) {
      await notify(
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
