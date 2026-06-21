import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/constants.dart';

final notificationCenterVisibilityProvider =
    NotifierProvider<NotificationCenterVisibilityController, bool>(
      NotificationCenterVisibilityController.new,
    );

final notificationCenterHighlightProvider =
    NotifierProvider<NotificationCenterHighlightController, String?>(
      NotificationCenterHighlightController.new,
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

class NotificationCenterHighlightController extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void highlight(String notificationId) {
    _timer?.cancel();
    state = notificationId;
    _timer = Timer(notificationCenterClearDelay, clear);
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }
}
