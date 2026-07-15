import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_list_tile.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

typedef WorkbenchTaskPositionCallback =
    void Function(MediaTask task, Offset position);
typedef WorkbenchTaskFolderPositionCallback =
    void Function(TaskFolder folder, Offset position);
typedef WorkbenchTaskFolderDropCallback =
    void Function(MediaTask task, TaskFolder folder);
typedef WorkbenchTaskSelectionCallback =
    void Function(Set<String> taskIds, {bool toggle});
typedef WorkbenchReorderCommitCallback =
    FutureOr<void> Function(int oldIndex, int newIndex);

class WorkbenchTaskListCard extends StatefulWidget {
  const WorkbenchTaskListCard({
    super.key,
    required this.taskList,
    required this.taskFolders,
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
    required this.onFolderContextMenu,
    required this.onToggleTaskSelection,
    required this.onSelectTasksWithRectangle,
    required this.onMoveTaskToFolder,
    required this.onOpenFolderSettings,
    required this.onOpenFolderContents,
    required this.onStartFolder,
    required this.onPauseFolder,
    required this.onRetryFolder,
    required this.onRelinkFolder,
    required this.onShowFolderLog,
    required this.onDeleteFolder,
    this.guideViewportKey,
    this.guideLastTaskKey,
    this.onGuideMetricsChanged,
    this.onDoubleTapBackground,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final AsyncValue<List<TaskFolder>> taskFolders;
  final Set<String> selectedTaskIds;
  final bool selectionMode;
  final ImageProvider? Function(MediaTask task) thumbnailForTask;
  final WorkbenchReorderCommitCallback onReorder;
  final ValueChanged<MediaTask> onOpenTask;
  final ValueChanged<MediaTask> onStart;
  final ValueChanged<MediaTask> onPause;
  final ValueChanged<MediaTask> onRemove;
  final ValueChanged<MediaTask> onRetry;
  final ValueChanged<MediaTask> onRelink;
  final ValueChanged<MediaTask> onShowLog;
  final ValueChanged<MediaTask> onRevealOutput;
  final WorkbenchTaskPositionCallback onContextMenu;
  final WorkbenchTaskFolderPositionCallback onFolderContextMenu;
  final ValueChanged<MediaTask> onToggleTaskSelection;
  final WorkbenchTaskSelectionCallback onSelectTasksWithRectangle;
  final WorkbenchTaskFolderDropCallback onMoveTaskToFolder;
  final ValueChanged<TaskFolder> onOpenFolderSettings;
  final ValueChanged<TaskFolder> onOpenFolderContents;
  final ValueChanged<TaskFolder> onStartFolder;
  final ValueChanged<TaskFolder> onPauseFolder;
  final ValueChanged<TaskFolder> onRetryFolder;
  final ValueChanged<TaskFolder> onRelinkFolder;
  final ValueChanged<TaskFolder> onShowFolderLog;
  final ValueChanged<TaskFolder> onDeleteFolder;
  final GlobalKey? guideViewportKey;
  final GlobalKey? guideLastTaskKey;
  final ValueChanged<GuideListMetrics>? onGuideMetricsChanged;
  final VoidCallback? onDoubleTapBackground;

  @override
  State<WorkbenchTaskListCard> createState() => _WorkbenchTaskListCardState();
}

class _WorkbenchTaskListCardState extends State<WorkbenchTaskListCard> {
  static const double _taskFolderDropEdgeInset = 16;
  static const Duration _backgroundDoubleTapTimeout = Duration(
    milliseconds: 300,
  );
  static const double _backgroundTapSlop = 18;

  final Map<String, GlobalKey> _taskItemKeys = {};
  final Map<String, GlobalKey> _folderDropKeys = {};
  final Map<String, Rect> _dragFolderRects = {};
  ScrollPosition? _dragScrollPosition;
  double? _dragScrollOffsetAtStart;
  Offset? _selectionStart;
  Offset? _selectionCurrent;
  String? _hoveredFolderId;
  MediaTask? _draggingTaskForReorder;
  Offset? _taskReorderPointerPosition;
  List<String>? _optimisticItemOrder;
  var _reorderCommitGeneration = 0;
  var _reorderCommitInFlight = false;
  ({List<WorkbenchListItem> items, int oldIndex, int newIndex})?
  _pendingFallbackReorder;
  GuideListMetrics? _lastReportedGuideMetrics;
  var _guideMetricsReportScheduled = false;
  int? _backgroundTapPointer;
  Offset? _backgroundPointerDownPosition;
  Duration? _lastBackgroundTapTime;
  Offset? _lastBackgroundTapPosition;

  @override
  Widget build(BuildContext context) {
    final content = widget.taskList.when(
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
    _scheduleGuideMetricsReport();
    return KeyedSubtree(
      key: widget.guideViewportKey,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _reportGuideMetrics(notification.metrics.maxScrollExtent > 0);
          return false;
        },
        child: content,
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<MediaTask> tasks,
    List<TaskFolder> folders,
  ) {
    final items = _resolveVisualItems(buildWorkbenchListItems(tasks, folders));
    if (items.isEmpty) {
      return _buildEmpty();
    }

    final listView = FrameLeanReorderableListView.builder(
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: widget.selectionMode
          ? (_, _) {}
          : (oldIndex, newIndex) {
              _commitOptimisticReorder(
                items: items,
                oldIndex: oldIndex,
                newIndex: newIndex,
              );
            },
      onReorderStart: (index) {
        _startTaskHandleDrag(index, items, folders);
      },
      onReorderUpdate: (details) {
        _updateTaskHandleDrag(details.globalPosition, folders);
      },
      onReorderCancel: (_) => _clearTaskHandleDrag(),
      gapBehavior: (details) {
        return _shouldMoveTaskReorderGap(details, folders);
      },
      onDrop: (details) {
        return _handleFrameLeanReorderDrop(
          details: details,
          items: items,
          folders: folders,
        );
      },
      onDropCompleted: (_, _) => _commitPendingFallbackReorder(),
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
          index: index,
          itemCount: items.length,
        );
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (event) =>
                _handleBackgroundPointerDown(event, items),
            onPointerUp: (event) => _handleBackgroundPointerUp(event, items),
            onPointerCancel: (_) => _clearBackgroundPointer(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                if (_draggingTaskForReorder != null) {
                  return;
                }
                setState(() {
                  _selectionStart = details.localPosition;
                  _selectionCurrent = details.localPosition;
                });
              },
              onPanUpdate: (details) {
                if (_draggingTaskForReorder != null) {
                  return;
                }
                setState(() {
                  _selectionCurrent = details.localPosition;
                });
              },
              onPanEnd: (_) {
                if (_draggingTaskForReorder != null) {
                  _clearRectangleSelection();
                  return;
                }
                _finishRectangleSelection(context, tasks);
              },
              onPanCancel: _clearRectangleSelection,
              child: listView,
            ),
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
        !_reorderCommitInFlight &&
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
        key: index == itemCount - 1 ? widget.guideLastTaskKey : null,
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
            onSecondaryTapDown: (details) {
              widget.onFolderContextMenu(folder, details.globalPosition);
            },
            dragHandle: _FolderDragHandleSlot(
              index: index,
              enabled: dragEnabled,
              selectionMode: widget.selectionMode,
            ),
            dropHighlighted: _hoveredFolderId == folder.id,
            dropDisabled: dropDisabled,
          ),
        ),
      ),
    );
    return child;
  }

  Widget _buildTaskItem({
    required MediaTask task,
    required int index,
    required int itemCount,
  }) {
    final dragEnabled =
        !_reorderCommitInFlight && task.status != TaskStatus.running;
    final selectedForBatch = widget.selectedTaskIds.contains(task.id);
    final tile = MediaTaskListTile(
      task: task,
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
          : _TaskDragHandleSlot(index: index, enabled: dragEnabled),
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
      child: KeyedSubtree(
        key: index == itemCount - 1 ? widget.guideLastTaskKey : null,
        child: tile,
      ),
    );
  }

  void _scheduleGuideMetricsReport() {
    if (_guideMetricsReportScheduled || widget.onGuideMetricsChanged == null) {
      return;
    }
    _guideMetricsReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guideMetricsReportScheduled = false;
      if (!mounted) {
        return;
      }
      final itemContext = widget.guideLastTaskKey?.currentContext;
      final position = itemContext == null
          ? null
          : Scrollable.maybeOf(itemContext, axis: Axis.vertical)?.position;
      _reportGuideMetrics((position?.maxScrollExtent ?? 0) > 0);
    });
  }

  void _reportGuideMetrics(bool hasScrollableContent) {
    final metrics = GuideListMetrics(
      hasScrollableContent: hasScrollableContent,
    );
    if (_lastReportedGuideMetrics == metrics) {
      return;
    }
    _lastReportedGuideMetrics = metrics;
    widget.onGuideMetricsChanged?.call(metrics);
  }

  bool _canDropTaskIntoFolder(MediaTask task, TaskFolder folder) {
    return task.folderId == null && task.mediaKind == folder.mediaKind;
  }

  FrameLeanReorderGapBehavior _shouldMoveTaskReorderGap(
    FrameLeanReorderGapDetails details,
    List<TaskFolder> folders,
  ) {
    final task = _draggingTaskForReorder;
    if (task == null) {
      return FrameLeanReorderGapBehavior.move;
    }
    for (final folder in folders) {
      if (!_canDropTaskIntoFolder(task, folder)) {
        continue;
      }
      final folderRect = _folderRectForDrag(folder.id);
      if (folderRect?.contains(details.globalPosition) ?? false) {
        return FrameLeanReorderGapBehavior.restoreOrigin;
      }
    }
    return FrameLeanReorderGapBehavior.move;
  }

  FrameLeanReorderDropDisposition _handleFrameLeanReorderDrop({
    required FrameLeanReorderDropDetails details,
    required List<WorkbenchListItem> items,
    required List<TaskFolder> folders,
  }) {
    final task = _draggingTaskForReorder;
    if (task == null) {
      _clearTaskHandleDrag();
      return FrameLeanReorderDropDisposition.reorder;
    }

    final targetFolder = _folderDropTargetAt(
      details.globalPosition,
      folders: folders,
      task: task,
    );
    if (targetFolder != null) {
      _clearTaskHandleDrag();
      widget.onMoveTaskToFolder(task, targetFolder);
      return FrameLeanReorderDropDisposition.accepted;
    }

    final sortTarget = _sortTargetAt(details.globalPosition, items);
    if (sortTarget != null && details.oldIndex == details.newIndex) {
      final newIndex = _newReorderIndexForSortTarget(
        oldIndex: details.oldIndex,
        targetIndex: sortTarget.itemIndex,
        afterTarget: sortTarget.afterItem,
        itemCount: items.length,
      );
      if (newIndex != details.oldIndex) {
        _pendingFallbackReorder = (
          items: [...items],
          oldIndex: details.oldIndex,
          newIndex: newIndex,
        );
      }
      _clearTaskHandleDrag();
      return FrameLeanReorderDropDisposition.accepted;
    }

    _clearTaskHandleDrag();
    return FrameLeanReorderDropDisposition.reorder;
  }

  List<WorkbenchListItem> _resolveVisualItems(
    List<WorkbenchListItem> sourceItems,
  ) {
    final optimisticOrder = _optimisticItemOrder;
    if (optimisticOrder == null) {
      return sourceItems;
    }

    final sourceByKey = {
      for (final item in sourceItems) item.identityKey: item,
    };
    if (sourceByKey.length != optimisticOrder.length ||
        optimisticOrder.any((key) => !sourceByKey.containsKey(key))) {
      _optimisticItemOrder = null;
      return sourceItems;
    }

    final sourceOrder = sourceItems.map((item) => item.identityKey).toList();
    if (_sameItemOrder(sourceOrder, optimisticOrder)) {
      _optimisticItemOrder = null;
      return sourceItems;
    }

    return optimisticOrder.map((key) => sourceByKey[key]!).toList();
  }

  bool _sameItemOrder(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  void _commitOptimisticReorder({
    required List<WorkbenchListItem> items,
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= items.length) {
      return;
    }

    final visualIndex = (newIndex > oldIndex ? newIndex - 1 : newIndex)
        .clamp(0, items.length - 1)
        .toInt();
    if (visualIndex == oldIndex) {
      final generation = ++_reorderCommitGeneration;
      unawaited(
        _persistReorder(
          generation: generation,
          oldIndex: oldIndex,
          newIndex: newIndex,
        ),
      );
      return;
    }

    final reorderedItems = [...items];
    final movedItem = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(visualIndex, movedItem);
    final generation = ++_reorderCommitGeneration;
    setState(() {
      _optimisticItemOrder = reorderedItems
          .map((item) => item.identityKey)
          .toList();
      _reorderCommitInFlight = true;
    });
    unawaited(
      _persistReorder(
        generation: generation,
        oldIndex: oldIndex,
        newIndex: newIndex,
      ),
    );
  }

  Future<void> _persistReorder({
    required int generation,
    required int oldIndex,
    required int newIndex,
  }) async {
    try {
      await widget.onReorder(oldIndex, newIndex);
    } on Object {
      if (mounted && generation == _reorderCommitGeneration) {
        setState(() {
          _optimisticItemOrder = null;
          _reorderCommitInFlight = false;
        });
      }
      return;
    }

    if (mounted && generation == _reorderCommitGeneration) {
      setState(() {
        _reorderCommitInFlight = false;
      });
    }
  }

  void _startTaskHandleDrag(
    int index,
    List<WorkbenchListItem> items,
    List<TaskFolder> folders,
  ) {
    final task = index >= 0 && index < items.length ? items[index].task : null;
    if (task == null) {
      _clearTaskHandleDrag();
      return;
    }
    final folderContext = folders.isEmpty
        ? null
        : _folderDropKeys[folders.first.id]?.currentContext;
    _dragScrollPosition = folderContext == null
        ? null
        : Scrollable.maybeOf(folderContext, axis: Axis.vertical)?.position;
    _dragScrollOffsetAtStart = _dragScrollPosition?.pixels;
    _dragFolderRects
      ..clear()
      ..addEntries(
        folders
            .map((folder) {
              return MapEntry(folder.id, _folderRectForDrag(folder.id));
            })
            .where((entry) => entry.value != null)
            .map((entry) => MapEntry(entry.key, entry.value!)),
      );
    setState(() {
      _pendingFallbackReorder = null;
      _draggingTaskForReorder = task;
      _taskReorderPointerPosition = null;
      _hoveredFolderId = null;
    });
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

    setState(() {
      _draggingTaskForReorder = task;
      _taskReorderPointerPosition = globalPosition;
      _hoveredFolderId = nextHoveredFolderId;
    });
  }

  void _clearTaskHandleDrag() {
    if (_draggingTaskForReorder == null &&
        _taskReorderPointerPosition == null &&
        _hoveredFolderId == null &&
        _dragFolderRects.isEmpty &&
        _dragScrollPosition == null &&
        _dragScrollOffsetAtStart == null) {
      return;
    }
    setState(() {
      _draggingTaskForReorder = null;
      _taskReorderPointerPosition = null;
      _hoveredFolderId = null;
      _dragFolderRects.clear();
      _dragScrollPosition = null;
      _dragScrollOffsetAtStart = null;
    });
  }

  void _commitPendingFallbackReorder() {
    final pendingReorder = _pendingFallbackReorder;
    _pendingFallbackReorder = null;
    if (pendingReorder == null || !mounted) {
      return;
    }
    _commitOptimisticReorder(
      items: pendingReorder.items,
      oldIndex: pendingReorder.oldIndex,
      newIndex: pendingReorder.newIndex,
    );
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
      final folderRect = _folderRectForDrag(folder.id);
      if (folderRect == null) {
        continue;
      }
      if (_folderDropBodyRect(folderRect).contains(globalPosition)) {
        return folder;
      }
    }

    return null;
  }

  Rect? _folderRectForDrag(String folderId) {
    final capturedRect = _dragFolderRects[folderId];
    if (capturedRect != null) {
      final startOffset = _dragScrollOffsetAtStart;
      final currentOffset = _dragScrollPosition?.pixels;
      final scrollDelta = startOffset == null || currentOffset == null
          ? 0.0
          : startOffset - currentOffset;
      return capturedRect.shift(Offset(0, scrollDelta));
    }
    return _globalRectFor(_folderDropKeys[folderId]);
  }

  _WorkbenchSortTarget? _sortTargetAt(
    Offset? globalPosition,
    List<WorkbenchListItem> items,
  ) {
    if (globalPosition == null) {
      return null;
    }

    for (var index = 0; index < items.length; index += 1) {
      final folder = items[index].folder;
      final task = items[index].task;
      final itemRect = folder != null
          ? _globalRectFor(_folderDropKeys[folder.id])
          : task != null
          ? _globalRectFor(_taskItemKeys[task.id])
          : null;
      if (itemRect == null) {
        continue;
      }
      if (!itemRect.contains(globalPosition)) {
        continue;
      }
      return _WorkbenchSortTarget(
        itemIndex: index,
        afterItem: globalPosition.dy > itemRect.center.dy,
      );
    }

    return null;
  }

  Rect? _globalRectFor(GlobalKey? key) {
    final itemContext = key?.currentContext;
    final itemBox = itemContext?.findRenderObject() as RenderBox?;
    if (itemBox == null || !itemBox.hasSize) {
      return null;
    }
    return itemBox.localToGlobal(Offset.zero) & itemBox.size;
  }

  void _handleBackgroundPointerDown(
    PointerDownEvent event,
    List<WorkbenchListItem> items,
  ) {
    final isBackground =
        event.buttons == kPrimaryButton &&
        _sortTargetAt(event.position, items) == null;
    if (!isBackground || widget.onDoubleTapBackground == null) {
      _clearBackgroundPointer(resetTapSequence: true);
      return;
    }
    _backgroundTapPointer = event.pointer;
    _backgroundPointerDownPosition = event.position;
  }

  void _handleBackgroundPointerUp(
    PointerUpEvent event,
    List<WorkbenchListItem> items,
  ) {
    if (_backgroundTapPointer != event.pointer) {
      return;
    }
    final downPosition = _backgroundPointerDownPosition;
    _clearBackgroundPointer();
    if (downPosition == null ||
        (event.position - downPosition).distance > _backgroundTapSlop ||
        _sortTargetAt(event.position, items) != null) {
      _clearBackgroundPointer(resetTapSequence: true);
      return;
    }

    final previousTime = _lastBackgroundTapTime;
    final previousPosition = _lastBackgroundTapPosition;
    final isDoubleTap =
        previousTime != null &&
        previousPosition != null &&
        event.timeStamp - previousTime <= _backgroundDoubleTapTimeout &&
        (event.position - previousPosition).distance <= _backgroundTapSlop;
    if (isDoubleTap) {
      _lastBackgroundTapTime = null;
      _lastBackgroundTapPosition = null;
      widget.onDoubleTapBackground?.call();
      return;
    }
    _lastBackgroundTapTime = event.timeStamp;
    _lastBackgroundTapPosition = event.position;
  }

  void _clearBackgroundPointer({bool resetTapSequence = false}) {
    _backgroundTapPointer = null;
    _backgroundPointerDownPosition = null;
    if (resetTapSequence) {
      _lastBackgroundTapTime = null;
      _lastBackgroundTapPosition = null;
    }
  }

  int _newReorderIndexForSortTarget({
    required int oldIndex,
    required int targetIndex,
    required bool afterTarget,
    required int itemCount,
  }) {
    if (oldIndex == targetIndex) {
      return oldIndex;
    }
    final insertionTarget = afterTarget
        ? oldIndex < targetIndex
              ? targetIndex
              : targetIndex + 1
        : oldIndex < targetIndex
        ? targetIndex - 1
        : targetIndex;
    final clampedTargetIndex = insertionTarget.clamp(0, itemCount - 1).toInt();
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTapBackground,
      child: const SizedBox.expand(),
    );
  }
}

class WorkbenchListItem {
  const WorkbenchListItem.task(this.task) : folder = null;

  const WorkbenchListItem.folder(this.folder) : task = null;

  final MediaTask? task;
  final TaskFolder? folder;

  String get identityKey =>
      task == null ? 'folder:${folder!.id}' : 'task:${task!.id}';
}

class _WorkbenchSortTarget {
  const _WorkbenchSortTarget({
    required this.itemIndex,
    required this.afterItem,
  });

  final int itemIndex;
  final bool afterItem;
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
  const _TaskDragHandleSlot({required this.index, required this.enabled});

  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final handle = _TaskDragHandle(enabled: enabled);
    if (!enabled) {
      return handle;
    }
    return FrameLeanReorderableDragStartListener(
      index: index,
      enabled: enabled,
      child: handle,
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
    return FrameLeanReorderableDragStartListener(
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
          WorkbenchIcons.dragIndicator,
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
