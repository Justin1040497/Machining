import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationCenterVisibilityProvider =
    NotifierProvider<NotificationCenterVisibilityController, bool>(
      NotificationCenterVisibilityController.new,
    );

class NotificationCenterVisibilityController extends Notifier<bool> {
  @override
  bool build() => false;

  void open() {
    state = true;
  }

  void close() {
    state = false;
  }

  void toggle() {
    state = !state;
  }
}
