import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class WorkbenchTopBar extends StatelessWidget {
  const WorkbenchTopBar({
    super.key,
    required this.themeMode,
    required this.onToggleThemeMode,
    required this.onOpenNotifications,
    this.updateState,
    this.onOpenUpdate,
    this.unreadNotificationCount = 0,
    this.showNotificationBadge = true,
    this.showBottomBorder = false,
  });

  final AppThemeMode themeMode;
  final VoidCallback onToggleThemeMode;
  final VoidCallback onOpenNotifications;
  final AppUpdateState? updateState;
  final VoidCallback? onOpenUpdate;
  final int unreadNotificationCount;
  final bool showNotificationBadge;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: topBarHeight,
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
                if (updateState?.isActive == true && onOpenUpdate != null) ...[
                  _UpdateTopBarButton(
                    state: updateState!,
                    onPressed: onOpenUpdate!,
                  ),
                  const SizedBox(width: 8),
                ],
                _TopBarIconButton(
                  tooltip: isDark ? '切换为浅色模式' : '切换为深色模式',
                  icon: isDark
                      ? WorkbenchIcons.lightMode
                      : WorkbenchIcons.darkMode,
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

class _UpdateTopBarButton extends StatelessWidget {
  const _UpdateTopBarButton({required this.state, required this.onPressed});

  final AppUpdateState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final status = state.status;
    final downloading = status == AppUpdateStatus.downloading;
    final paused = status == AppUpdateStatus.paused;

    final String label;
    Color dotColor;
    switch (status) {
      case AppUpdateStatus.downloading:
        label = '下载中 ${state.progressPercent}%';
        dotColor = colors.primary;
      case AppUpdateStatus.paused:
        label = '已暂停 ${state.progressPercent}%';
        dotColor = colors.textTertiary;
      case AppUpdateStatus.downloaded:
        label = '已就绪';
        dotColor = colors.statusRunning;
      case AppUpdateStatus.failed:
        label = '更新失败';
        dotColor = colors.statusFailed;
      default:
        final version = state.release?.version;
        label = version != null ? '新版本 v$version' : '有新版本';
        dotColor = colors.primary;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180, minHeight: 28),
      child: Material(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (downloading || paused)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      value: downloading ? state.progress : null,
                      strokeWidth: 2,
                      color: colors.primary,
                      backgroundColor: colors.primarySoft.withAlpha(120),
                    ),
                  )
                else
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 3),
                Icon(
                  WorkbenchIcons.chevronRight,
                  size: 14,
                  color: colors.textTertiary,
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
          icon: WorkbenchIcons.notifications,
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
