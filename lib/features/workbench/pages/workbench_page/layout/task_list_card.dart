import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
typedef WorkbenchTaskSelectionCallback =
    void Function(Set<String> taskIds, {bool toggle});

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
    required this.onRevealOutput,
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
  final ValueChanged<MediaTask> onRevealOutput;
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
  static const double _taskFolderDropEdgeInset = 16;

  final Map<String, GlobalKey> _taskItemKeys = {};
  final Map<String, GlobalKey> _folderDropKeys = {};
  final GlobalKey _listStackKey = GlobalKey();
  Offset? _selectionStart;
  Offset? _selectionCurrent;
  String? _hoveredFolderId;
  Rect? _hoveredFolderAnchorRect;
  MediaTask? _draggingTaskForReorder;
  Offset? _taskReorderPointerPosition;
  int? _draggingTaskTopLevelIndex;
  List<WorkbenchListItem> _draggingTopLevelItems = const [];

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
      onReorder: widget.selectionMode
          ? (_, _) {}
          : (oldIndex, newIndex) {
              _handleReorder(
                oldIndex: oldIndex,
                newIndex: newIndex,
                folders: folders,
              );
            },
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
          items: items,
          index: index,
          itemCount: items.length,
        );
      },
    );

    return Stack(
      key: _listStackKey,
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
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
          ),
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
        if (_hoveredFolderId != null && _hoveredFolderAnchorRect != null)
          _buildHoveredFolderOverlay(tasks, folders),
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
    final dragEnabled =
        !widget.selectionMode &&
        !folderTasks.any((task) => task.status == TaskStatus.running);
    final draggingTask = _draggingTaskForReorder;
    final dropDisabled =
        draggingTask != null && !_canDropTaskIntoFolder(draggingTask, folder);
    final child = Container(
      key: ValueKey('folder-${folder.id}'),
      padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 13),
      margin: EdgeInsets.fromLTRB(
        27,
        index != 0 ? 6 : 30,
        27,
        index != itemCount - 1 ? 0 : 48,
      ),
      child: KeyedSubtree(
        key: _folderDropKeyFor(folder.id),
        child: TaskFolderListTile(
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
          dragHandle: _FolderDragHandleSlot(
            index: index,
            enabled: dragEnabled,
            selectionMode: widget.selectionMode,
          ),
          dropHighlighted: _hoveredFolderId == folder.id,
          dropDisabled: dropDisabled,
          dropGhosted: _hoveredFolderId == folder.id,
        ),
      ),
    );
    return child;
  }

  Widget _buildHoveredFolderOverlay(
    List<MediaTask> tasks,
    List<TaskFolder> folders,
  ) {
    final hoveredFolderId = _hoveredFolderId;
    final anchorRect = _hoveredFolderAnchorRect;
    if (hoveredFolderId == null || anchorRect == null) {
      return const SizedBox.shrink();
    }

    final stackBox =
        _listStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) {
      return const SizedBox.shrink();
    }

    TaskFolder? hoveredFolder;
    for (final folder in folders) {
      if (folder.id == hoveredFolderId) {
        hoveredFolder = folder;
        break;
      }
    }
    if (hoveredFolder == null) {
      return const SizedBox.shrink();
    }

    final topLeft = stackBox.globalToLocal(anchorRect.topLeft);
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: anchorRect.width,
      height: anchorRect.height,
      child: IgnorePointer(
        child: TaskFolderListTile(
          folder: hoveredFolder,
          tasks: folderTasksFor(tasks, hoveredFolder.id),
          onOpenSettings: () {},
          onOpenContents: () {},
          onDelete: () {},
          onStart: () {},
          onPause: () {},
          onRetry: () {},
          onRelink: () {},
          onShowLog: () {},
          dragHandle: const SizedBox(width: 24),
          dropHighlighted: true,
          dropStateKey: ValueKey('task-folder-hover-overlay-$hoveredFolderId'),
        ),
      ),
    );
  }

  Widget _buildTaskItem({
    required MediaTask task,
    required List<TaskFolder> folders,
    required List<WorkbenchListItem> items,
    required int index,
    required int itemCount,
  }) {
    final dragEnabled = task.status != TaskStatus.running;
    final selectedForBatch = widget.selectedTaskIds.contains(task.id);
    final tile = MediaTaskListTile(
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
      onRevealOutput: () => widget.onRevealOutput(task),
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
              enabled: dragEnabled,
              onPointerDown: (event) {
                _startTaskHandleDrag(
                  task,
                  event.position,
                  folders,
                  items,
                  index,
                );
              },
              onPointerMove: (event) {
                _updateTaskHandleDrag(event.position, folders);
              },
              onPointerUp: (event) {
                _endTaskHandleDrag(event.position);
              },
              onPointerCancel: _cancelTaskHandleDrag,
            ),
    );

    return Container(
      key: _taskKeyFor(task.id),
      padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 13),
      margin: EdgeInsets.fromLTRB(
        27,
        index != 0 ? 6 : 30,
        27,
        index != itemCount - 1 ? 0 : 48,
      ),
      child: tile,
    );
  }

  bool _canDropTaskIntoFolder(MediaTask task, TaskFolder folder) {
    return task.folderId == null && task.mediaKind == folder.mediaKind;
  }

  void _handleReorder({
    required int oldIndex,
    required int newIndex,
    required List<TaskFolder> folders,
  }) {
    final task = _draggingTaskForReorder;
    final targetFolder = task == null
        ? null
        : _folderDropTargetAt(
            _taskReorderPointerPosition,
            folders: folders,
            task: task,
          );
    _clearTaskHandleDrag();

    if (task != null && targetFolder != null) {
      widget.onMoveTaskToFolder(task, targetFolder);
      return;
    }

    widget.onReorder(oldIndex, newIndex);
  }

  void _startTaskHandleDrag(
    MediaTask task,
    Offset globalPosition,
    List<TaskFolder> folders,
    List<WorkbenchListItem> items,
    int index,
  ) {
    _draggingTaskTopLevelIndex = index;
    _draggingTopLevelItems = items;
    _setTaskHandleDragState(
      task: task,
      globalPosition: globalPosition,
      folders: folders,
    );
  }

  void _updateTaskHandleDrag(Offset globalPosition, List<TaskFolder> folders) {
    final task = _draggingTaskForReorder;
    if (task == null) {
      return;
    }
    _setTaskHandleDragState(
      task: task,
      globalPosition: globalPosition,
      folders: folders,
    );
  }

  void _endTaskHandleDrag(Offset globalPosition) {
    _taskReorderPointerPosition = globalPosition;
    _completeTaskHandleDragAfterFrame();
  }

  void _cancelTaskHandleDrag() {
    _scheduleClearTaskHandleDrag();
  }

  void _setTaskHandleDragState({
    required MediaTask task,
    required Offset globalPosition,
    required List<TaskFolder> folders,
  }) {
    final hoveredFolder = _folderDropTargetAt(
      globalPosition,
      folders: folders,
      task: task,
    );
    final nextHoveredFolderId = hoveredFolder?.id;
    if (_draggingTaskForReorder?.id == task.id &&
        _taskReorderPointerPosition == globalPosition &&
        _hoveredFolderId == nextHoveredFolderId) {
      return;
    }

    final nextAnchorRect = nextHoveredFolderId == null
        ? null
        : _hoveredFolderId == nextHoveredFolderId
        ? _hoveredFolderAnchorRect
        : _folderGlobalRect(nextHoveredFolderId);
    setState(() {
      _draggingTaskForReorder = task;
      _taskReorderPointerPosition = globalPosition;
      _hoveredFolderId = nextHoveredFolderId;
      _hoveredFolderAnchorRect = nextAnchorRect;
    });
  }

  void _scheduleClearTaskHandleDrag() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draggingTaskForReorder == null) {
        return;
      }
      _clearTaskHandleDrag();
    });
  }

  void _completeTaskHandleDragAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final task = _draggingTaskForReorder;
      final oldIndex = _draggingTaskTopLevelIndex;
      if (task == null || oldIndex == null) {
        _clearTaskHandleDrag();
        return;
      }

      final targetFolder = _folderDropTargetAt(
        _taskReorderPointerPosition,
        folders: [
          for (final item in _draggingTopLevelItems)
            if (item.folder != null) item.folder!,
        ],
        task: task,
      );
      if (targetFolder != null) {
        _clearTaskHandleDrag();
        widget.onMoveTaskToFolder(task, targetFolder);
        return;
      }

      final sortTarget = _folderSortTargetAt(
        _taskReorderPointerPosition,
        _draggingTopLevelItems,
      );
      if (sortTarget != null) {
        final newIndex = _newReorderIndexForFolderSortTarget(
          oldIndex: oldIndex,
          folderIndex: sortTarget.folderIndex,
          afterFolder: sortTarget.afterFolder,
          itemCount: _draggingTopLevelItems.length,
        );
        _clearTaskHandleDrag();
        if (newIndex != oldIndex) {
          widget.onReorder(oldIndex, newIndex);
        }
        return;
      }

      _clearTaskHandleDrag();
    });
  }

  void _clearTaskHandleDrag() {
    if (_draggingTaskForReorder == null &&
        _taskReorderPointerPosition == null &&
        _hoveredFolderId == null &&
        _hoveredFolderAnchorRect == null &&
        _draggingTaskTopLevelIndex == null &&
        _draggingTopLevelItems.isEmpty) {
      return;
    }
    setState(() {
      _draggingTaskForReorder = null;
      _taskReorderPointerPosition = null;
      _hoveredFolderId = null;
      _hoveredFolderAnchorRect = null;
      _draggingTaskTopLevelIndex = null;
      _draggingTopLevelItems = const [];
    });
  }

  TaskFolder? _folderDropTargetAt(
    Offset? globalPosition, {
    required List<TaskFolder> folders,
    required MediaTask task,
  }) {
    if (globalPosition == null) {
      return null;
    }

    for (final folder in folders) {
      if (!_canDropTaskIntoFolder(task, folder)) {
        continue;
      }
      final folderContext = _folderDropKeys[folder.id]?.currentContext;
      final folderBox = folderContext?.findRenderObject() as RenderBox?;
      if (folderBox == null || !folderBox.hasSize) {
        continue;
      }
      final folderRect = folderBox.localToGlobal(Offset.zero) & folderBox.size;
      if (_folderDropBodyRect(folderRect).contains(globalPosition)) {
        return folder;
      }
    }

    return null;
  }

  Rect? _folderGlobalRect(String folderId) {
    final folderContext = _folderDropKeys[folderId]?.currentContext;
    final folderBox = folderContext?.findRenderObject() as RenderBox?;
    if (folderBox == null || !folderBox.hasSize) {
      return null;
    }
    return folderBox.localToGlobal(Offset.zero) & folderBox.size;
  }

  _FolderSortTarget? _folderSortTargetAt(
    Offset? globalPosition,
    List<WorkbenchListItem> items,
  ) {
    if (globalPosition == null) {
      return null;
    }

    for (var index = 0; index < items.length; index += 1) {
      final folder = items[index].folder;
      if (folder == null) {
        continue;
      }
      final folderContext = _folderDropKeys[folder.id]?.currentContext;
      final folderBox = folderContext?.findRenderObject() as RenderBox?;
      if (folderBox == null || !folderBox.hasSize) {
        continue;
      }
      final folderRect = folderBox.localToGlobal(Offset.zero) & folderBox.size;
      if (!folderRect.contains(globalPosition)) {
        continue;
      }
      return _FolderSortTarget(
        folderIndex: index,
        afterFolder: globalPosition.dy > folderRect.center.dy,
      );
    }

    return null;
  }

  int _newReorderIndexForFolderSortTarget({
    required int oldIndex,
    required int folderIndex,
    required bool afterFolder,
    required int itemCount,
  }) {
    final targetIndex = afterFolder
        ? oldIndex < folderIndex
              ? folderIndex
              : folderIndex + 1
        : oldIndex < folderIndex
        ? folderIndex - 1
        : folderIndex;
    final clampedTargetIndex = targetIndex.clamp(0, itemCount - 1).toInt();
    return clampedTargetIndex > oldIndex
        ? clampedTargetIndex + 1
        : clampedTargetIndex;
  }

  Rect _folderDropBodyRect(Rect folderRect) {
    if (folderRect.height <= _taskFolderDropEdgeInset * 2) {
      return folderRect;
    }
    return Rect.fromLTRB(
      folderRect.left,
      folderRect.top + _taskFolderDropEdgeInset,
      folderRect.right,
      folderRect.bottom - _taskFolderDropEdgeInset,
    );
  }

  GlobalKey _taskKeyFor(String taskId) {
    return _taskItemKeys.putIfAbsent(taskId, GlobalKey.new);
  }

  GlobalKey _folderDropKeyFor(String folderId) {
    return _folderDropKeys.putIfAbsent(folderId, GlobalKey.new);
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
      final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
      final toggle =
          pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.controlRight) ||
          pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.metaRight);
      widget.onSelectTasksWithRectangle(selectedIds, toggle: toggle);
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

class _FolderSortTarget {
  const _FolderSortTarget({
    required this.folderIndex,
    required this.afterFolder,
  });

  final int folderIndex;
  final bool afterFolder;
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
    required this.enabled,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final MediaTask task;
  final int index;
  final bool enabled;
  final void Function(PointerDownEvent event) onPointerDown;
  final void Function(PointerMoveEvent event) onPointerMove;
  final void Function(PointerUpEvent event) onPointerUp;
  final VoidCallback onPointerCancel;

  @override
  Widget build(BuildContext context) {
    final handle = _TaskDragHandle(enabled: enabled);
    if (!enabled || task.folderId != null) {
      return handle;
    }
    return Listener(
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      onPointerCancel: (_) => onPointerCancel(),
      child: ReorderableDragStartListener(
        index: index,
        enabled: enabled,
        child: handle,
      ),
    );
  }
}

class _FolderDragHandleSlot extends StatelessWidget {
  const _FolderDragHandleSlot({
    required this.index,
    required this.enabled,
    required this.selectionMode,
  });

  final int index;
  final bool enabled;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final handle = _TaskDragHandle(enabled: enabled && !selectionMode);
    if (!enabled || selectionMode) {
      return handle;
    }
    return ReorderableDragStartListener(
      index: index,
      enabled: enabled,
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
