import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class WorkbenchBottomBar extends StatelessWidget {
  const WorkbenchBottomBar({
    super.key,
    required this.taskList,
    required this.hasRunningTask,
    required this.queueActionInFlight,
    required this.selectionMode,
    required this.selectionEnabled,
    required this.onAddFiles,
    required this.onAddFolder,
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
  final VoidCallback onAddFiles;
  final VoidCallback onAddFolder;
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
                  _AddTaskMenuButton(
                    onImportFiles: onAddFiles,
                    onImportFolder: onAddFolder,
                  ),
                  const SizedBox(width: 12),
                  _DockIconButton(
                    tooltip: selectionMode ? '退出多选' : '多选任务',
                    icon: selectionMode
                        ? Icons.close_rounded
                        : Icons.select_all_rounded,
                    onPressed: selectionEnabled ? onToggleSelectionMode : null,
                    color: selectionMode ? colors.primary : null,
                    active: selectionMode,
                  ),
                  const SizedBox(width: 12),
                  _DockIconButton(
                    tooltip: '设置',
                    icon: Icons.settings,
                    onPressed: onOpenSettings,
                  ),
                  const Spacer(),
                  _DockIconButton(
                    tooltip: '清空列表',
                    icon: Icons.delete_outline_rounded,
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

enum _AddTaskMenuAction { files, folder }

class _AddTaskMenuButton extends StatelessWidget {
  const _AddTaskMenuButton({
    required this.onImportFiles,
    required this.onImportFolder,
  });

  final VoidCallback onImportFiles;
  final VoidCallback onImportFolder;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return PopupMenuButton<_AddTaskMenuAction>(
      tooltip: '添加任务',
      color: colors.surface,
      offset: const Offset(0, -4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (action) {
        switch (action) {
          case _AddTaskMenuAction.files:
            onImportFiles();
          case _AddTaskMenuAction.folder:
            onImportFolder();
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _AddTaskMenuAction.files,
            child: _AddTaskMenuItem(
              icon: Icons.insert_drive_file_outlined,
              label: '导入文件',
            ),
          ),
          PopupMenuItem(
            value: _AddTaskMenuAction.folder,
            child: _AddTaskMenuItem(
              icon: Icons.folder_open_rounded,
              label: '导入文件夹',
            ),
          ),
        ];
      },
      child: _DockIconButtonContent(
        tooltip: '添加任务',
        icon: Icons.add_rounded,
        forceEnabled: true,
        size: 26,
      ),
    );
  }
}

class _AddTaskMenuItem extends StatelessWidget {
  const _AddTaskMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.iconMuted),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: colors.textPrimary, fontSize: 12)),
      ],
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return _DockIconButtonContent(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
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
    this.forceEnabled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool active;
  final bool forceEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final enabled = forceEnabled || onPressed != null;
    final iconColor = !enabled
        ? colors.textTertiary
        : active
        ? colors.onPrimary
        : color ?? colors.textPrimary;

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
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
        child: forceEnabled && onPressed == null
            ? Icon(icon, size: size, color: iconColor)
            : IconButton(
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
            hasRunningTask ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 34,
          ),
        ),
      ),
    );
  }
}
