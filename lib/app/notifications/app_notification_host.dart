import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
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
  static const _visibleDuration = Duration(seconds: 4);
  static const _animationDuration = Duration(milliseconds: 220);

  final ValueNotifier<bool> visible = ValueNotifier(false);
  ProviderSubscription<AsyncValue<AppNotificationPresentation>>? subscription;
  AppNotificationPresentation? presentation;
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
        final event = next.requireValue;
        show(event);
      },
    );
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    removeTimer?.cancel();
    subscription?.close();
    visible.dispose();
    super.dispose();
  }

  void show(AppNotificationPresentation nextPresentation) {
    hideTimer?.cancel();
    removeTimer?.cancel();
    setState(() {
      presentation = nextPresentation;
      visible.value = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || presentation != nextPresentation) {
        return;
      }
      visible.value = true;
    });
    hideTimer = Timer(_visibleDuration, hide);
  }

  void hide() {
    hideTimer?.cancel();
    hideTimer = null;
    visible.value = false;
    removeTimer?.cancel();
    removeTimer = Timer(_animationDuration, () {
      removeTimer = null;
      if (mounted) {
        setState(() => presentation = null);
      }
    });
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
            message: current.notification.displayMessage,
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
