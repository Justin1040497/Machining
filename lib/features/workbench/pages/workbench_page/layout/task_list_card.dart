import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_list_tile.dart';

typedef WorkbenchTaskPositionCallback =
    void Function(MediaTask task, Offset position);
typedef WorkbenchTaskFolderDropCallback =
    void Function(MediaTask task, TaskFolder folder);
typedef WorkbenchTaskSelectionCallback = void Function(Set<String> taskIds);

class WorkbenchTaskListCard extends StatefulWidget {
  const WorkbenchTaskListCard({
    super.key,
    required this.taskList,
    required this.taskFolders,
    required this.selectedTask,
    required this.selectedTaskIds,
    required this.selectionMode,
    required this.thumbnailForTask,
    required this.onReorder,
    required this.onOpenTask,
    required this.onStart,
    required this.onPause,
    required this.onRemove,
    required this.onRetry,
    required this.onRelink,
    required this.onShowLog,
    required this.onContextMenu,
    required this.onToggleTaskSelection,
    required this.onSelectTasksWithRectangle,
    required this.onMoveTaskToFolder,
    required this.onRejectTaskFolderDrop,
    required this.onOpenFolderSettings,
    required this.onOpenFolderContents,
    required this.onStartFolder,
    required this.onPauseFolder,
    required this.onRetryFolder,
    required this.onRelinkFolder,
    required this.onShowFolderLog,
    required this.onDeleteFolder,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final AsyncValue<List<TaskFolder>> taskFolders;
  final MediaTask? selectedTask;
  final Set<String> selectedTaskIds;
  final bool selectionMode;
  final ImageProvider? Function(MediaTask task) thumbnailForTask;
  final ReorderCallback onReorder;
  final ValueChanged<MediaTask> onOpenTask;
  final ValueChanged<MediaTask> onStart;
  final ValueChanged<MediaTask> onPause;
  final ValueChanged<MediaTask> onRemove;
  final ValueChanged<MediaTask> onRetry;
  final ValueChanged<MediaTask> onRelink;
  final ValueChanged<MediaTask> onShowLog;
  final WorkbenchTaskPositionCallback onContextMenu;
  final ValueChanged<MediaTask> onToggleTaskSelection;
  final WorkbenchTaskSelectionCallback onSelectTasksWithRectangle;
  final WorkbenchTaskFolderDropCallback onMoveTaskToFolder;
  final WorkbenchTaskFolderDropCallback onRejectTaskFolderDrop;
  final ValueChanged<TaskFolder> onOpenFolderSettings;
  final ValueChanged<TaskFolder> onOpenFolderContents;
  final ValueChanged<TaskFolder> onStartFolder;
  final ValueChanged<TaskFolder> onPauseFolder;
  final ValueChanged<TaskFolder> onRetryFolder;
  final ValueChanged<TaskFolder> onRelinkFolder;
  final ValueChanged<TaskFolder> onShowFolderLog;
  final ValueChanged<TaskFolder> onDeleteFolder;

  @override
  State<WorkbenchTaskListCard> createState() => _WorkbenchTaskListCardState();
}

class _WorkbenchTaskListCardState extends State<WorkbenchTaskListCard> {
  final Map<String, GlobalKey> _taskItemKeys = {};
  Offset? _selectionStart;
  Offset? _selectionCurrent;
  String? _hoveredFolderId;
  String? _rejectedFolderId;

  @override
  Widget build(BuildContext context) {
    return widget.taskList.when(
      loading: _buildLoading,
      error: (error, stackTrace) => _buildError(error),
      data: (tasks) {
        return widget.taskFolders.when(
          loading: _buildLoading,
          error: (error, stackTrace) => _buildError(error),
          data: (folders) => _buildList(context, tasks, folders),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<MediaTask> tasks,
    List<TaskFolder> folders,
  ) {
    final items = buildWorkbenchListItems(tasks, folders);
    if (items.isEmpty) {
      return _buildEmpty();
    }

    final listView = ReorderableListView.builder(
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: folders.isEmpty && !widget.selectionMode
          ? widget.onReorder
          : (_, _) {},
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.02).animate(animation),
            child: child,
          ),
        );
      },
      itemBuilder: (context, index) {
        final item = items[index];
        final task = item.task;
        final folder = item.folder;
        if (folder != null) {
          return _buildFolderItem(
            tasks: tasks,
            folders: folders,
            folder: folder,
            index: index,
            itemCount: items.length,
          );
        }

        if (task == null) {
          return const SizedBox.shrink(key: ValueKey('empty-task-list-item'));
        }
        return _buildTaskItem(
          task: task,
          folders: folders,
          index: index,
          itemCount: items.length,
        );
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: widget.selectionMode
              ? GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (details) {
                    setState(() {
                      _selectionStart = details.localPosition;
                      _selectionCurrent = details.localPosition;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _selectionCurrent = details.localPosition;
                    });
                  },
                  onPanEnd: (_) => _finishRectangleSelection(context, tasks),
                  onPanCancel: _clearRectangleSelection,
                  child: listView,
                )
              : listView,
        ),
        if (_selectionRect != null)
          Positioned.fromRect(
            rect: _selectionRect!,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFolderItem({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
    required TaskFolder folder,
    required int index,
    required int itemCount,
  }) {
    final folderTasks = folderTasksFor(tasks, folder.id);
    final child = Container(
      key: ValueKey('folder-${folder.id}'),
      padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 13),
      margin: EdgeInsets.fromLTRB(
        27,
        index != 0 ? 6 : 30,
        27,
        index != itemCount - 1 ? 0 : 48,
      ),
      child: DragTarget<MediaTask>(
        onWillAcceptWithDetails: (details) {
          final accepted = _canDropTaskIntoFolder(details.data, folder);
          setState(() {
            _hoveredFolderId = folder.id;
            _rejectedFolderId = accepted ? null : folder.id;
          });
          return accepted;
        },
        onAcceptWithDetails: (details) {
          setState(() {
            _hoveredFolderId = null;
            _rejectedFolderId = null;
          });
          widget.onMoveTaskToFolder(details.data, folder);
        },
        onLeave: (task) {
          setState(() {
            if (_hoveredFolderId == folder.id) {
              _hoveredFolderId = null;
            }
            if (_rejectedFolderId == folder.id) {
              _rejectedFolderId = null;
            }
          });
          if (task != null && !_canDropTaskIntoFolder(task, folder)) {
            widget.onRejectTaskFolderDrop(task, folder);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return TaskFolderListTile(
            folder: folder,
            tasks: folderTasks,
            onOpenSettings: () => widget.onOpenFolderSettings(folder),
            onOpenContents: () => widget.onOpenFolderContents(folder),
            onDelete: () => widget.onDeleteFolder(folder),
            onStart: () => widget.onStartFolder(folder),
            onPause: () => widget.onPauseFolder(folder),
            onRetry: () => widget.onRetryFolder(folder),
            onRelink: () => widget.onRelinkFolder(folder),
            onShowLog: () => widget.onShowFolderLog(folder),
            dropHighlighted: _hoveredFolderId == folder.id,
            dropRejected: _rejectedFolderId == folder.id,
          );
        },
      ),
    );
    return child;
  }

  Widget _buildTaskItem({
    required MediaTask task,
    required List<TaskFolder> folders,
    required int index,
    required int itemCount,
  }) {
    final dragEnabled = task.status != TaskStatus.running;
    final selectedForBatch = widget.selectedTaskIds.contains(task.id);

    return Container(
      key: _taskKeyFor(task.id),
      padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 13),
      margin: EdgeInsets.fromLTRB(
        27,
        index != 0 ? 6 : 30,
        27,
        index != itemCount - 1 ? 0 : 48,
      ),
      child: MediaTaskListTile(
        task: task,
        selected: selectedForBatch || widget.selectedTask?.id == task.id,
        thumbnail: widget.thumbnailForTask(task),
        onTap: widget.selectionMode
            ? () => widget.onToggleTaskSelection(task)
            : () => widget.onOpenTask(task),
        onStart: () => widget.onStart(task),
        onPause: () => widget.onPause(task),
        onRemove: () => widget.onRemove(task),
        onRetry: () => widget.onRetry(task),
        onRelink: () => widget.onRelink(task),
        onShowLog: () => widget.onShowLog(task),
        onSecondaryTapDown: widget.selectionMode
            ? null
            : (details) {
                widget.onContextMenu(task, details.globalPosition);
              },
        tooltipsEnabled: false,
        dragHandle: widget.selectionMode
            ? _TaskSelectionCheckbox(
                selected: selectedForBatch,
                onChanged: () => widget.onToggleTaskSelection(task),
              )
            : _TaskDragHandleSlot(
                task: task,
                index: index,
                folders: folders,
                enabled: dragEnabled,
              ),
      ),
    );
  }

  bool _canDropTaskIntoFolder(MediaTask task, TaskFolder folder) {
    return task.folderId == null && task.mediaKind == folder.mediaKind;
  }

  GlobalKey _taskKeyFor(String taskId) {
    return _taskItemKeys.putIfAbsent(taskId, GlobalKey.new);
  }

  Rect? get _selectionRect {
    final start = _selectionStart;
    final current = _selectionCurrent;
    if (start == null || current == null) {
      return null;
    }
    return Rect.fromPoints(start, current);
  }

  void _finishRectangleSelection(BuildContext context, List<MediaTask> tasks) {
    final rect = _selectionRect;
    if (rect == null || rect.width.abs() < 4 || rect.height.abs() < 4) {
      _clearRectangleSelection();
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      _clearRectangleSelection();
      return;
    }

    final selectionGlobalRect = Rect.fromPoints(
      box.localToGlobal(rect.topLeft),
      box.localToGlobal(rect.bottomRight),
    );
    final selectedIds = <String>{};
    for (final task in tasks.where((task) => task.folderId == null)) {
      final itemContext = _taskItemKeys[task.id]?.currentContext;
      final itemBox = itemContext?.findRenderObject() as RenderBox?;
      if (itemBox == null) {
        continue;
      }
      final itemRect = itemBox.localToGlobal(Offset.zero) & itemBox.size;
      if (selectionGlobalRect.overlaps(itemRect)) {
        selectedIds.add(task.id);
      }
    }

    if (selectedIds.isNotEmpty) {
      widget.onSelectTasksWithRectangle(selectedIds);
    }
    _clearRectangleSelection();
  }

  void _clearRectangleSelection() {
    setState(() {
      _selectionStart = null;
      _selectionCurrent = null;
    });
  }

  Widget _buildLoading() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Builder(
      builder: (context) {
        final colors = context.frameLeanColors;

        return Center(
          child: Text(
            '任务列表读取失败\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textTertiary, fontSize: 12.flSp),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Builder(
      builder: (context) {
        final colors = context.frameLeanColors;

        return Center(
          child: Text(
            '暂无任务\n点击左下角 + 添加媒体',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 12.flSp,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}

class WorkbenchListItem {
  const WorkbenchListItem.task(this.task) : folder = null;

  const WorkbenchListItem.folder(this.folder) : task = null;

  final MediaTask? task;
  final TaskFolder? folder;
}

List<WorkbenchListItem> buildWorkbenchListItems(
  List<MediaTask> tasks,
  List<TaskFolder> folders,
) {
  final items = <WorkbenchListItem>[
    ...folders.map(WorkbenchListItem.folder),
    ...tasks.where((task) => task.folderId == null).map(WorkbenchListItem.task),
  ];

  items.sort((a, b) {
    final leftOrder = a.folder?.sortOrder ?? a.task?.sortOrder ?? 0;
    final rightOrder = b.folder?.sortOrder ?? b.task?.sortOrder ?? 0;
    return leftOrder.compareTo(rightOrder);
  });

  return items;
}

List<MediaTask> folderTasksFor(List<MediaTask> tasks, String folderId) {
  return tasks.where((task) => task.folderId == folderId).toList()
    ..sort((a, b) {
      final order = (a.folderSortOrder ?? a.sortOrder).compareTo(
        b.folderSortOrder ?? b.sortOrder,
      );
      if (order != 0) {
        return order;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
}

class _TaskDragHandleSlot extends StatelessWidget {
  const _TaskDragHandleSlot({
    required this.task,
    required this.index,
    required this.folders,
    required this.enabled,
  });

  final MediaTask task;
  final int index;
  final List<TaskFolder> folders;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final handle = _TaskDragHandle(enabled: enabled);
    if (folders.isEmpty) {
      return ReorderableDragStartListener(
        index: index,
        enabled: enabled,
        child: handle,
      );
    }

    if (!enabled || task.folderId != null) {
      return handle;
    }

    return Draggable<MediaTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 48, height: 48, child: handle),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: handle),
      child: handle,
    );
  }
}

class _TaskDragHandle extends StatelessWidget {
  const _TaskDragHandle({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Semantics(
      label: enabled ? '拖动排序或拖入任务夹' : '运行中任务不能拖动',
      child: SizedBox(
        width: 24,
        height: 48,
        child: Icon(
          Icons.drag_indicator_rounded,
          color: enabled ? colors.iconMuted : colors.statusCancelled,
          size: 18,
        ),
      ),
    );
  }
}

class _TaskSelectionCheckbox extends StatelessWidget {
  const _TaskSelectionCheckbox({
    required this.selected,
    required this.onChanged,
  });

  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 48,
      child: Checkbox(
        value: selected,
        onChanged: (_) => onChanged(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
