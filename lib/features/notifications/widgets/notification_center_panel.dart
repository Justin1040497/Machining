import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/presentation/app_layout_constants.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/features/notifications/providers/notification_center_provider.dart';
import 'package:framelean/features/notifications/services/notification_center_action_resolver.dart';

class NotificationCenterPanel extends ConsumerStatefulWidget {
  const NotificationCenterPanel({
    super.key,
    required this.visible,
    required this.onClose,
    required this.onRevealOutput,
  });

  final bool visible;
  final VoidCallback onClose;
  final Future<void> Function(String outputPath) onRevealOutput;

  @override
  ConsumerState<NotificationCenterPanel> createState() =>
      _NotificationCenterPanelState();
}

class _NotificationCenterPanelState
    extends ConsumerState<NotificationCenterPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> barrierAnimation;
  late final Animation<Offset> panelAnimation;
  final FocusNode focusNode = FocusNode(debugLabel: 'notification-center');
  ProviderSubscription<AsyncValue<List<AppNotificationEntry>>>?
  notificationsSubscription;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 190),
      value: widget.visible ? 1 : 0,
    );
    barrierAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    panelAnimation =
        Tween<Offset>(begin: const Offset(1.08, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    notificationsSubscription = ref
        .listenManual<AsyncValue<List<AppNotificationEntry>>>(
          appNotificationsProvider,
          (_, next) {
            if (widget.visible &&
                next.asData?.value.any(
                      (notification) => notification.isUnread,
                    ) ==
                    true) {
              unawaited(
                ref.read(appNotificationManagerProvider).markAllAsRead(),
              );
            }
          },
          fireImmediately: true,
        );
    if (widget.visible) {
      requestFocusAndMarkRead();
    }
  }

  @override
  void didUpdateWidget(NotificationCenterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }

    if (widget.visible) {
      unawaited(animationController.forward());
      requestFocusAndMarkRead();
    } else {
      unawaited(animationController.reverse());
      focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    notificationsSubscription?.close();
    focusNode.dispose();
    animationController.dispose();
    super.dispose();
  }

  void requestFocusAndMarkRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visible) {
        return;
      }
      focusNode.requestFocus();
      unawaited(ref.read(appNotificationManagerProvider).markAllAsRead());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final notifications = ref.watch(appNotificationsProvider);
    final highlightedNotificationId = ref.watch(
      notificationCenterHighlightProvider,
    );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Focus(
          focusNode: focusNode,
          autofocus: widget.visible,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, _) {
              final availablePanelWidth = MediaQuery.sizeOf(context).width - 36;
              final panelWidth = math.min(
                380.0,
                math.max(249.0, availablePanelWidth),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: barrierAnimation,
                      child: GestureDetector(
                        key: const Key('notification-center-barrier'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onClose,
                        child: ColoredBox(
                          color: Colors.black.withAlpha(
                            Theme.of(context).brightness == Brightness.dark
                                ? 88
                                : 46,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppLayoutConstants.topBarHeight + 10,
                    right: 18,
                    bottom: 74,
                    width: panelWidth,
                    child: SlideTransition(
                      position: panelAnimation,
                      child: Material(
                        key: const Key('notification-center-panel'),
                        color: colors.surface,
                        elevation: 2,
                        shadowColor: colors.shadow,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: colors.border),
                        ),
                        child: Column(
                          children: [
                            _NotificationCenterHeader(
                              hasNotifications:
                                  notifications.asData?.value.isNotEmpty ==
                                  true,
                              onClear: () {
                                unawaited(
                                  ref
                                      .read(appNotificationManagerProvider)
                                      .dismissAll(),
                                );
                              },
                            ),
                            Expanded(
                              child: notifications.when(
                                data: (items) => _NotificationList(
                                  notifications: items,
                                  onRevealOutput: widget.onRevealOutput,
                                  highlightedNotificationId:
                                      highlightedNotificationId,
                                ),
                                loading: () => Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                error: (error, _) => _NotificationEmptyState(
                                  icon: Icons.error_outline_rounded,
                                  message: '通知读取失败\n$error',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationCenterHeader extends StatelessWidget {
  const _NotificationCenterHeader({
    required this.hasNotifications,
    required this.onClear,
  });

  final bool hasNotifications;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 10, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '通知中心',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Tooltip(
              message: '清空通知',
              child: IconButton(
                key: const Key('notification-center-clear'),
                onPressed: hasNotifications ? onClear : null,
                icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                color: colors.textPrimary,
                disabledColor: colors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                style: IconButton.styleFrom(
                  hoverColor: colors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.onRevealOutput,
    required this.highlightedNotificationId,
  });

  final List<AppNotificationEntry> notifications;
  final Future<void> Function(String outputPath) onRevealOutput;
  final String? highlightedNotificationId;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const _NotificationEmptyState(
        icon: Icons.notifications_none_rounded,
        message: '暂无通知',
      );
    }

    return ListView.separated(
      key: const Key('notification-center-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final action = NotificationCenterActionResolver.resolve(notification);
        return _NotificationListItem(
          key: ValueKey(notification.id),
          notification: notification,
          action: action,
          onRevealOutput: onRevealOutput,
          highlighted: notification.id == highlightedNotificationId,
        );
      },
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  const _NotificationListItem({
    super.key,
    required this.notification,
    required this.action,
    required this.onRevealOutput,
    required this.highlighted,
  });

  final AppNotificationEntry notification;
  final NotificationCenterActionDescriptor? action;
  final Future<void> Function(String outputPath) onRevealOutput;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final accentColor = switch (notification.level) {
      AppNotificationLevel.error => colors.statusFailed,
      AppNotificationLevel.warning => colors.statusRunning,
      AppNotificationLevel.info ||
      AppNotificationLevel.success => colors.primary,
    };

    return TweenAnimationBuilder<double>(
      key: ValueKey('${notification.id}-$highlighted'),
      tween: Tween(begin: 0, end: highlighted ? 1 : 0),
      duration: highlighted
          ? const Duration(milliseconds: 1500)
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final pulse = highlighted ? math.sin(value * math.pi * 3).abs() : 0.0;
        final highlightColor = Color.lerp(
          colors.surface,
          colors.primarySoft,
          pulse * 0.55,
        )!;
        final borderColor = Color.lerp(
          colors.border,
          colors.primary,
          pulse * 0.45,
        )!;

        return Semantics(
          container: true,
          label: notification.displayMessage,
          child: Container(
            key: const Key('notification-center-item'),
            decoration: BoxDecoration(
              color: highlightColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 9, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Container(
                key: const Key('notification-center-accent'),
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (action != null)
                        _NotificationActionButton(
                          action: action!,
                          onRevealOutput: onRevealOutput,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatNotificationTime(notification.createdAt),
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 10,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (notification.message.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectionArea(
                      child: Text(
                        notification.message.trim(),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNotificationTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return time;
  }

  return '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} $time';
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    required this.action,
    required this.onRevealOutput,
  });

  final NotificationCenterActionDescriptor action;
  final Future<void> Function(String outputPath) onRevealOutput;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Tooltip(
      message: '打开成果物所在位置',
      child: IconButton(
        key: const Key('notification-reveal-output'),
        onPressed: () {
          switch (action.type) {
            case NotificationCenterActionType.revealOutput:
              unawaited(onRevealOutput(action.target));
          }
        },
        icon: const Icon(Icons.folder_outlined, size: 15),
        color: colors.textPrimary,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        style: IconButton.styleFrom(
          hoverColor: colors.surfaceMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: colors.iconMuted),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
