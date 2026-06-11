import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/features/notifications/providers/notification_center_provider.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/workbench_notice.dart';
import 'package:framelean/infrastructure/providers/app_notification_provider.dart';

class AppNotificationHost extends StatelessWidget {
  const AppNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (context) => _AppNotificationLayer(child: child)),
      ],
    );
  }
}

class _AppNotificationLayer extends ConsumerStatefulWidget {
  const _AppNotificationLayer({required this.child});

  final Widget child;

  @override
  ConsumerState<_AppNotificationLayer> createState() =>
      _AppNotificationLayerState();
}

class _AppNotificationLayerState extends ConsumerState<_AppNotificationLayer> {
  static const _animationDuration = Duration(milliseconds: 220);

  final ValueNotifier<bool> visible = ValueNotifier(false);
  ProviderSubscription<AsyncValue<AppNotificationPresentation>>? subscription;
  ProviderSubscription<bool>? centerVisibilitySubscription;
  AppNotificationPresentation? presentation;
  AppNotificationPresentation? pendingPresentation;
  Timer? hideTimer;
  Timer? removeTimer;

  @override
  void initState() {
    super.initState();
    subscription = ref.listenManual<AsyncValue<AppNotificationPresentation>>(
      appNotificationPresentationsProvider,
      (_, next) {
        if (!next.hasValue) {
          return;
        }
        if (ref.read(notificationCenterVisibilityProvider)) {
          return;
        }
        final event = next.requireValue;
        show(event);
      },
    );
    centerVisibilitySubscription = ref.listenManual<bool>(
      notificationCenterVisibilityProvider,
      (_, centerVisible) {
        if (centerVisible) {
          hide(clearPending: true);
        }
      },
    );
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    removeTimer?.cancel();
    subscription?.close();
    centerVisibilitySubscription?.close();
    visible.dispose();
    super.dispose();
  }

  void show(AppNotificationPresentation nextPresentation) {
    pendingPresentation = nextPresentation;
    hideTimer?.cancel();
    hideTimer = null;

    if (presentation == null && removeTimer == null) {
      showPending();
      return;
    }

    visible.value = false;
    scheduleRemoval();
  }

  void showPending() {
    final nextPresentation = pendingPresentation;
    if (nextPresentation == null || !mounted) {
      return;
    }

    pendingPresentation = null;
    setState(() => presentation = nextPresentation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          presentation != nextPresentation ||
          pendingPresentation != null ||
          removeTimer != null) {
        return;
      }
      visible.value = true;
    });
    hideTimer = Timer(switch (nextPresentation.notification.level) {
      AppNotificationLevel.error => const Duration(seconds: 6),
      AppNotificationLevel.warning => const Duration(seconds: 5),
      AppNotificationLevel.info ||
      AppNotificationLevel.success => const Duration(seconds: 3),
    }, hide);
  }

  void hide({bool clearPending = false}) {
    hideTimer?.cancel();
    hideTimer = null;
    if (clearPending) {
      pendingPresentation = null;
    }
    if (presentation == null) {
      return;
    }
    visible.value = false;
    scheduleRemoval();
  }

  void scheduleRemoval() {
    removeTimer ??= Timer(_animationDuration, completeRemoval);
  }

  void completeRemoval() {
    removeTimer = null;
    if (!mounted) {
      return;
    }

    if (pendingPresentation != null) {
      showPending();
      return;
    }

    setState(() => presentation = null);
  }

  @override
  Widget build(BuildContext context) {
    final current = presentation;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (current != null)
          WorkbenchNotice(
            title: current.notification.title,
            message: current.notification.message,
            level: current.notification.level,
            visibleListenable: visible,
            actionLabel: current.action?.label,
            onActionPressed: current.action == null
                ? null
                : () {
                    hide();
                    current.action!.onPressed();
                  },
            onDismissed: hide,
          ),
      ],
    );
  }
}
