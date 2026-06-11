import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';

class WorkbenchTopBar extends StatelessWidget {
  const WorkbenchTopBar({
    super.key,
    required this.themeMode,
    required this.onToggleThemeMode,
    required this.onOpenNotifications,
    this.showBottomBorder = false,
  });

  final AppThemeMode themeMode;
  final VoidCallback onToggleThemeMode;
  final VoidCallback onOpenNotifications;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: WorkbenchConstants.appTopBarHeight,
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
                _TopBarIconButton(
                  tooltip: '通知中心',
                  icon: Icons.notifications_none_rounded,
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
