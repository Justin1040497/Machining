import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/value_objects/task_notification_payload.dart';
import 'package:framelean/features/notifications/providers/notification_center_provider.dart';
import 'package:framelean/app/notifications/app_notification_notice.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_settings_provider.dart';

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
        final event = next.requireValue;
        playCompletionSoundIfNeeded(event);
        if (ref.read(notificationCenterVisibilityProvider)) {
          return;
        }
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

  void playCompletionSoundIfNeeded(AppNotificationPresentation event) {
    final notification = event.notification;
    if (notification.kind != AppNotificationKind.task ||
        notification.level != AppNotificationLevel.success) {
      return;
    }

    unawaited(
      ref
          .read(appSettingsProvider.future)
          .then((settings) {
            return ref
                .read(taskCompletionSoundPlayerProvider)
                .play(settings.taskCompletionSound);
          })
          .catchError((_) {}),
    );
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
    hideTimer = Timer(displayDurationFor(nextPresentation), hide);
  }

  Duration displayDurationFor(AppNotificationPresentation presentation) {
    final notification = presentation.notification;
    if (isTaskCompletionNotification(notification)) {
      final showCompletionDialog =
          ref
              .read(appSettingsProvider)
              .asData
              ?.value
              .showTaskCompletionDialog ??
          true;
      if (!showCompletionDialog) {
        return const Duration(seconds: 8);
      }
    }

    return switch (notification.level) {
      AppNotificationLevel.error => const Duration(seconds: 6),
      AppNotificationLevel.warning => const Duration(seconds: 5),
      AppNotificationLevel.info ||
      AppNotificationLevel.success => const Duration(seconds: 3),
    };
  }

  bool isTaskCompletionNotification(AppNotificationEntry notification) {
    return notification.kind == AppNotificationKind.task &&
        notification.level == AppNotificationLevel.success;
  }

  String transientMessageFor(AppNotificationEntry notification) {
    if (notification.kind != AppNotificationKind.task) {
      return notification.message;
    }

    final payload = TaskNotificationPayload.tryParse(notification.payloadJson);
    final fileName = payload?.fileName.trim();
    if (fileName == null || fileName.isEmpty) {
      return notification.message;
    }

    return switch (notification.level) {
      AppNotificationLevel.success => '$fileName 已处理完成',
      AppNotificationLevel.error => '$fileName 处理失败，点击查看详情',
      AppNotificationLevel.info ||
      AppNotificationLevel.warning => notification.message,
    };
  }

  _NotificationViewAction? actionFor(AppNotificationPresentation presentation) {
    final action = presentation.action;
    if (action != null) {
      return _NotificationViewAction(
        label: action.label,
        tooltip: action.tooltip,
        onPressed: action.onPressed,
      );
    }

    if (!isTaskCompletionNotification(presentation.notification)) {
      return null;
    }

    final payload = TaskNotificationPayload.tryParse(
      presentation.notification.payloadJson,
    );
    final outputPath = payload?.outputPath?.trim();
    if (outputPath == null || outputPath.isEmpty) {
      return null;
    }

    return _NotificationViewAction(
      label: '打开文件夹',
      tooltip: '打开成果物所在位置',
      icon: Icons.folder_outlined,
      onPressed: () {
        unawaited(ref.read(fileRevealerProvider).revealPath(outputPath));
      },
    );
  }

  void openCenterAndHighlight(AppNotificationPresentation presentation) {
    ref
        .read(notificationCenterHighlightProvider.notifier)
        .highlight(presentation.notification.id);
    ref.read(notificationCenterVisibilityProvider.notifier).open();
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
    final action = current == null ? null : actionFor(current);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (current != null)
          AppNotificationNotice(
            title: current.notification.title,
            message: transientMessageFor(current.notification),
            level: current.notification.level,
            visibleListenable: visible,
            actionLabel: action?.label,
            actionIcon: action?.icon,
            actionTooltip: action?.tooltip,
            onActionPressed: action == null
                ? null
                : () {
                    hide();
                    action.onPressed();
                  },
            onTap: () {
              hide();
              openCenterAndHighlight(current);
            },
            onDismissed: hide,
          ),
      ],
    );
  }
}

class _NotificationViewAction {
  const _NotificationViewAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? tooltip;
}
