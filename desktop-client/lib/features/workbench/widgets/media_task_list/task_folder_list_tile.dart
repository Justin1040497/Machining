import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_action_button.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class TaskFolderListTile extends StatelessWidget {
  const TaskFolderListTile({
    super.key,
    required this.folder,
    required this.tasks,
    required this.onOpenSettings,
    required this.onOpenContents,
    required this.onDelete,
    this.onStart,
    this.onPause,
    this.onRetry,
    this.onRelink,
    this.onShowLog,
    this.onSecondaryTapDown,
    this.dragHandle,
    this.dropHighlighted = false,
    this.dropDisabled = false,
    this.dropStateKey,
  });

  final TaskFolder folder;
  final List<MediaTask> tasks;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenContents;
  final VoidCallback onDelete;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onRetry;
  final VoidCallback? onRelink;
  final VoidCallback? onShowLog;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Widget? dragHandle;
  final bool dropHighlighted;
  final bool dropDisabled;
  final Key? dropStateKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final completedCount = tasks
        .where((task) => task.status == TaskStatus.completed)
        .length;
    final failedCount = tasks
        .where(
          (task) =>
              task.status == TaskStatus.executionFailed ||
              task.status == TaskStatus.analysisFailed,
        )
        .length;
    final progress = tasks.isEmpty
        ? 0.0
        : tasks.map((task) => task.progress).reduce((a, b) => a + b) /
              tasks.length;
    final primaryAction = _resolvePrimaryAction();
    final missingSourceCount = tasks
        .where((task) => task.status == TaskStatus.missingSource)
        .length;
    final hasLoggableTask = tasks.any(_isLoggableTask);
    final hasRunningTask = tasks.any(
      (task) => task.status == TaskStatus.running,
    );
    final hasProgressBackground = hasRunningTask && progress > 0;

    final activeDrop = dropHighlighted && !dropDisabled;
    final borderColor = dropDisabled
        ? colors.border
        : activeDrop
        ? colors.primary
        : colors.borderStrong;
    final folderColor = dropDisabled ? colors.iconMuted : colors.primary;
    final titleColor = dropDisabled ? colors.textTertiary : colors.textPrimary;
    final subtitleColor = dropDisabled ? colors.iconMuted : colors.textTertiary;
    final contentOpacity = dropDisabled ? 0.48 : 1.0;

    return AnimatedOpacity(
      key: dropStateKey ?? ValueKey('task-folder-drop-state-${folder.id}'),
      duration: hoverTransition,
      curve: Curves.easeOutCubic,
      opacity: contentOpacity,
      child: AnimatedScale(
        duration: hoverTransition,
        curve: Curves.easeOutCubic,
        scale: activeDrop ? 1.018 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onOpenSettings,
            onSecondaryTapDown: onSecondaryTapDown,
            child: AnimatedContainer(
              duration: hoverTransition,
              height: 86,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: activeDrop ? 7 : 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: activeDrop ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (hasProgressBackground)
                    Positioned.fill(
                      key: ValueKey('task-folder-progress-${folder.id}'),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0, 1).toDouble(),
                        child: ColoredBox(color: colors.progress),
                      ),
                    ),
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      dragHandle ?? const SizedBox(width: 24),
                      const SizedBox(width: 5),
                      Icon(WorkbenchIcons.folder, color: folderColor, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 14.flSp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _subtitle(
                                completedCount: completedCount,
                                failedCount: failedCount,
                                missingSourceCount: missingSourceCount,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 11.flSp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (primaryAction != null)
                        MediaTaskIconButton(
                          tooltip: primaryAction.tooltip,
                          onPressed: primaryAction.onPressed,
                          icon: primaryAction.icon,
                        )
                      else
                        const SizedBox(width: 36, height: 36),
                      if (hasLoggableTask) ...[
                        const SizedBox(width: 4),
                        MediaTaskIconButton(
                          tooltip: '查看夹内任务日志',
                          onPressed: onShowLog,
                          icon: WorkbenchIcons.log,
                        ),
                      ],
                      const SizedBox(width: 4),
                      MediaTaskIconButton(
                        tooltip: '查看夹内任务',
                        onPressed: onOpenContents,
                        icon: WorkbenchIcons.folderOpen,
                      ),
                      const SizedBox(width: 4),
                      MediaTaskIconButton(
                        tooltip: '删除任务夹并释放任务',
                        onPressed: onDelete,
                        icon: WorkbenchIcons.delete,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TaskFolderPrimaryAction? _resolvePrimaryAction() {
    if (tasks.any((task) => task.status == TaskStatus.running)) {
      return _TaskFolderPrimaryAction(
        tooltip: '暂停任务夹任务',
        icon: WorkbenchIcons.pause,
        onPressed: onPause,
      );
    }

    if (tasks.any(_isStartableTask)) {
      return _TaskFolderPrimaryAction(
        tooltip: '开始任务夹下一项',
        icon: WorkbenchIcons.play,
        onPressed: onStart,
      );
    }

    if (tasks.any(_isRetryableTask)) {
      return _TaskFolderPrimaryAction(
        tooltip: '重来任务夹终态任务',
        icon: WorkbenchIcons.replay,
        onPressed: onRetry,
      );
    }

    return null;
  }

  String _subtitle({
    required int completedCount,
    required int failedCount,
    required int missingSourceCount,
  }) {
    final missingPart = missingSourceCount > 0
        ? ' · 源文件丢失 $missingSourceCount'
        : '';
    return '${tasks.length} 个任务 · 已完成 $completedCount · 失败 $failedCount$missingPart';
  }

  bool _isStartableTask(MediaTask task) {
    return task.status == TaskStatus.paused || task.canStartExecution;
  }

  bool _isRetryableTask(MediaTask task) {
    return task.status == TaskStatus.completed ||
        task.status == TaskStatus.executionFailed ||
        task.status == TaskStatus.analysisFailed ||
        task.status == TaskStatus.cancelled;
  }

  bool _isLoggableTask(MediaTask task) {
    return task.status == TaskStatus.running ||
        task.status == TaskStatus.completed ||
        task.status == TaskStatus.executionFailed ||
        task.status == TaskStatus.analysisFailed ||
        task.status == TaskStatus.paused;
  }
}

class _TaskFolderPrimaryAction {
  const _TaskFolderPrimaryAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
}
