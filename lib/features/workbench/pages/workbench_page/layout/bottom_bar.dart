import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class WorkbenchBottomBar extends StatelessWidget {
  const WorkbenchBottomBar({
    super.key,
    required this.taskList,
    required this.hasRunningTask,
    required this.queueActionInFlight,
    required this.selectionMode,
    required this.selectionEnabled,
    required this.onAddTasks,
    required this.onToggleSelectionMode,
    required this.onOpenSettings,
    required this.onClearTasks,
    required this.onPrimaryQueuePressed,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final bool hasRunningTask;
  final bool queueActionInFlight;
  final bool selectionMode;
  final bool selectionEnabled;
  final VoidCallback onAddTasks;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onOpenSettings;
  final VoidCallback onClearTasks;
  final VoidCallback onPrimaryQueuePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final hasTasks = taskList.hasValue && taskList.requireValue.isNotEmpty;

    return SizedBox(
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.expand(
            child: Container(
              color: colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  _DockIconButton(
                    tooltip: '添加文件或文件夹',
                    icon: WorkbenchIcons.add,
                    onPressed: onAddTasks,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  _DockIconButton(
                    tooltip: selectionMode ? '退出多选' : '多选任务',
                    icon: selectionMode
                        ? WorkbenchIcons.close
                        : WorkbenchIcons.selectAll,
                    onPressed: selectionEnabled ? onToggleSelectionMode : null,
                    color: selectionMode ? colors.primary : null,
                    active: selectionMode,
                  ),
                  const SizedBox(width: 12),
                  _DockIconButton(
                    tooltip: '设置',
                    icon: WorkbenchIcons.settings,
                    onPressed: onOpenSettings,
                  ),
                  const Spacer(),
                  _DockIconButton(
                    tooltip: '清空列表',
                    icon: WorkbenchIcons.delete,
                    color: colors.statusFailed,
                    onPressed: hasTasks ? onClearTasks : null,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 62 / 2 - 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PrimaryQueueButton(
                  hasTasks: hasTasks,
                  hasRunningTask: hasRunningTask,
                  queueActionInFlight: queueActionInFlight,
                  onPressed: onPrimaryQueuePressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 22,
    this.color,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return _DockIconButtonContent(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      size: size,
      color: color,
      active: active,
    );
  }
}

class _DockIconButtonContent extends StatelessWidget {
  const _DockIconButtonContent({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.size = 22,
    this.color,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final enabled = onPressed != null;
    final iconColor = !enabled
        ? colors.textTertiary
        : active
        ? colors.onPrimary
        : color ?? colors.textPrimary;

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: hoverTransition,
        curve: Curves.easeOutCubic,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active && enabled ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active && enabled ? colors.primary : Colors.transparent,
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: size, color: iconColor),
        ),
      ),
    );
  }
}

class _PrimaryQueueButton extends StatelessWidget {
  const _PrimaryQueueButton({
    required this.hasTasks,
    required this.hasRunningTask,
    required this.queueActionInFlight,
    required this.onPressed,
  });

  final bool hasTasks;
  final bool hasRunningTask;
  final bool queueActionInFlight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Tooltip(
      message: hasRunningTask ? '暂停所有任务' : '开始执行',
      child: SizedBox(
        width: 68,
        height: 68,
        child: FilledButton(
          onPressed: hasTasks && !queueActionInFlight ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            disabledBackgroundColor: colors.progress,
            foregroundColor: colors.onPrimary,
            disabledForegroundColor: colors.textTertiary,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Icon(
            hasRunningTask ? WorkbenchIcons.pause : WorkbenchIcons.resume,
            size: 34,
          ),
        ),
      ),
    );
  }
}
