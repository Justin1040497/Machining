import 'package:flutter/material.dart';
import 'package:framelean/app/presentation/app_layout_constants.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';

class WorkbenchTopBar extends StatelessWidget {
  const WorkbenchTopBar({
    super.key,
    required this.themeMode,
    required this.onToggleThemeMode,
    required this.onOpenNotifications,
    this.unreadNotificationCount = 0,
    this.showNotificationBadge = true,
    this.showBottomBorder = false,
  });

  final AppThemeMode themeMode;
  final VoidCallback onToggleThemeMode;
  final VoidCallback onOpenNotifications;
  final int unreadNotificationCount;
  final bool showNotificationBadge;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: AppLayoutConstants.topBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: showBottomBorder
              ? Border(bottom: BorderSide(color: colors.border))
              : null,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TopBarIconButton(
                  tooltip: isDark ? '切换为浅色模式' : '切换为深色模式',
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  onPressed: onToggleThemeMode,
                ),
                const SizedBox(width: 8),
                _NotificationTopBarButton(
                  unreadCount: unreadNotificationCount,
                  showBadge: showNotificationBadge,
                  onPressed: onOpenNotifications,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTopBarButton extends StatelessWidget {
  const _NotificationTopBarButton({
    required this.unreadCount,
    required this.showBadge,
    required this.onPressed,
  });

  final int unreadCount;
  final bool showBadge;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _TopBarIconButton(
          tooltip: '通知中心',
          icon: Icons.notifications_none_rounded,
          onPressed: onPressed,
        ),
        if (showBadge && unreadCount > 0)
          Positioned(
            key: const Key('notification-unread-badge'),
            top: -3,
            right: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.statusFailed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: colors.onDanger,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: colors.iconMuted,
          hoverColor: colors.surfaceMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
