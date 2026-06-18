import 'package:flutter/material.dart';
import 'package:framelean/app/presentation/app_layout_constants.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';

class TaskFolderContentPanel extends StatelessWidget {
  const TaskFolderContentPanel({
    super.key,
    required this.visible,
    required this.folder,
    required this.tasks,
    required this.thumbnailForTask,
    required this.onClose,
    required this.onRemoveTask,
    required this.onStart,
    required this.onPause,
    required this.onRetry,
    required this.onRelink,
    required this.onShowLog,
    required this.onRevealOutput,
    required this.onReorder,
  });

  final bool visible;
  final TaskFolder? folder;
  final List<MediaTask> tasks;
  final ImageProvider? Function(MediaTask task) thumbnailForTask;
  final VoidCallback onClose;
  final ValueChanged<MediaTask> onRemoveTask;
  final ValueChanged<MediaTask> onStart;
  final ValueChanged<MediaTask> onPause;
  final ValueChanged<MediaTask> onRetry;
  final ValueChanged<MediaTask> onRelink;
  final ValueChanged<MediaTask> onShowLog;
  final ValueChanged<MediaTask> onRevealOutput;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final currentFolder = folder;
    if (currentFolder == null) {
      return const SizedBox.shrink();
    }

    final panelWidth = (MediaQuery.sizeOf(context).width - 36)
        .clamp(280, 420)
        .toDouble();

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: ColoredBox(
                    color: Colors.black.withAlpha(
                      Theme.of(context).brightness == Brightness.dark ? 88 : 46,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: AppLayoutConstants.topBarHeight + 10,
              bottom: 74,
              left: visible ? 18 : -panelWidth - 24,
              width: panelWidth,
              child: Material(
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentFolder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14.flSp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${tasks.length} 个任务',
                                  style: TextStyle(
                                    color: colors.textTertiary,
                                    fontSize: 11.flSp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.border),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        buildDefaultDragHandles: false,
                        itemCount: tasks.length,
                        onReorder: onReorder,
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 1,
                                end: 1.015,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final dragEnabled = task.status != TaskStatus.running;
                          return Padding(
                            key: ValueKey('folder-task-${task.id}'),
                            padding: EdgeInsets.only(
                              bottom: index == tasks.length - 1 ? 0 : 8,
                            ),
                            child: MediaTaskListTile(
                              task: task,
                              thumbnail: thumbnailForTask(task),
                              onStart: () => onStart(task),
                              onPause: () => onPause(task),
                              onRetry: () => onRetry(task),
                              onRelink: () => onRelink(task),
                              onShowLog: () => onShowLog(task),
                              onRevealOutput: () => onRevealOutput(task),
                              onRemove: () => onRemoveTask(task),
                              removeTooltip: '移出任务夹',
                              removeIcon: Icons.remove_circle_outline_rounded,
                              dragHandle: _FolderTaskDragHandle(
                                index: index,
                                enabled: dragEnabled,
                              ),
                              tooltipsEnabled: false,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderTaskDragHandle extends StatelessWidget {
  const _FolderTaskDragHandle({required this.index, required this.enabled});

  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final handle = SizedBox(
      width: 24,
      height: 48,
      child: Icon(
        Icons.drag_indicator_rounded,
        color: enabled ? colors.iconMuted : colors.statusCancelled,
        size: 18,
      ),
    );
    if (!enabled) {
      return handle;
    }
    return ReorderableDragStartListener(
      index: index,
      enabled: enabled,
      child: handle,
    );
  }
}
