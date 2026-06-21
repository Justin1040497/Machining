import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:framelean/app/presentation/widgets/reorderable/framelean_reorderable_list_view.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';
import 'package:framelean/app/constants.dart';

typedef TaskFolderTaskCommitCallback = Future<void> Function(MediaTask task);
typedef TaskFolderReorderCommitCallback =
    FutureOr<void> Function(int oldIndex, int newIndex);

class TaskFolderContentPanel extends StatefulWidget {
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
  final TaskFolderTaskCommitCallback onRemoveTask;
  final ValueChanged<MediaTask> onStart;
  final ValueChanged<MediaTask> onPause;
  final ValueChanged<MediaTask> onRetry;
  final ValueChanged<MediaTask> onRelink;
  final ValueChanged<MediaTask> onShowLog;
  final ValueChanged<MediaTask> onRevealOutput;
  final TaskFolderReorderCommitCallback onReorder;

  @override
  State<TaskFolderContentPanel> createState() => _TaskFolderContentPanelState();
}

class _TaskFolderContentPanelState extends State<TaskFolderContentPanel>
    with SingleTickerProviderStateMixin {
  final _panelKey = GlobalKey();
  final _listViewportKey = GlobalKey();
  late final AnimationController _animationController;
  late final Animation<double> _barrierAnimation;
  late final Animation<Offset> _panelAnimation;
  final FocusNode _focusNode = FocusNode(debugLabel: 'task-folder-panel');
  final Set<String> _pendingRemovalIds = {};
  List<String>? _optimisticOrder;
  TaskFolder? _displayFolder;
  List<MediaTask> _displayTasks = const [];
  String? _draggingTaskId;
  bool _dragging = false;
  bool _hoveringScrim = false;
  bool _removeCommitInFlight = false;
  bool _reorderCommitInFlight = false;
  int _reorderGeneration = 0;

  @override
  void initState() {
    super.initState();
    _displayFolder = widget.folder;
    _displayTasks = widget.tasks;
    _animationController = AnimationController(
      vsync: this,
      duration: expandCollapseTransition,
      reverseDuration: reverseTransition,
      value: widget.visible ? 1 : 0,
    );
    _barrierAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _panelAnimation =
        Tween<Offset>(begin: const Offset(-1.08, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    if (widget.visible) {
      _requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant TaskFolderContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.folder != null) {
      _displayFolder = widget.folder;
      _displayTasks = widget.tasks;
    } else if (widget.visible) {
      _displayTasks = widget.tasks;
    }

    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        unawaited(_animationController.forward());
        _requestFocus();
      } else {
        unawaited(
          _animationController.reverse().whenComplete(() {
            if (!mounted || widget.visible) {
              return;
            }
            setState(() {
              _displayFolder = null;
              _displayTasks = const [];
            });
          }),
        );
        _focusNode.unfocus();
      }
    }

    if (oldWidget.folder?.id != widget.folder?.id) {
      _pendingRemovalIds.clear();
      _optimisticOrder = null;
      _draggingTaskId = null;
      _dragging = false;
      _hoveringScrim = false;
      _removeCommitInFlight = false;
      _reorderCommitInFlight = false;
      _reorderGeneration += 1;
      return;
    }

    final sourceIds = widget.tasks.map((task) => task.id).toSet();
    _pendingRemovalIds.removeWhere((id) => !sourceIds.contains(id));
    final sourceOrder = widget.tasks.map((task) => task.id).toList();
    if (_sameOrder(sourceOrder, _optimisticOrder)) {
      _optimisticOrder = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visible) {
        return;
      }
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final currentFolder = _displayFolder;
    if (currentFolder == null) {
      return const SizedBox.shrink();
    }

    final visualTasks = _resolveVisualTasks();
    final panelWidth = (MediaQuery.sizeOf(context).width - 36)
        .clamp(280, 420)
        .toDouble();
    final scrimColor = _hoveringScrim
        ? colors.primary.withAlpha(
            Theme.of(context).brightness == Brightness.dark ? 54 : 34,
          )
        : Colors.black.withAlpha(
            Theme.of(context).brightness == Brightness.dark ? 88 : 46,
          );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.visible,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: _barrierAnimation,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dragging ? null : widget.onClose,
                    child: AnimatedContainer(
                      key: const Key('task-folder-drop-scrim'),
                      duration: fastTransition,
                      color: scrimColor,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topBarHeight + 10,
                bottom: 74,
                left: 18,
                width: panelWidth,
                child: SlideTransition(
                  position: _panelAnimation,
                  child: Material(
                    key: _panelKey,
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
                                      '${visualTasks.length} 个任务',
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
                                onPressed: widget.onClose,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        Expanded(
                          child: SizedBox.expand(
                            key: _listViewportKey,
                            child: FrameLeanReorderableListView.builder(
                              padding: const EdgeInsets.all(12),
                              buildDefaultDragHandles: false,
                              allowCrossAxisDrag: true,
                              itemCount: visualTasks.length,
                              onReorder: (oldIndex, newIndex) {
                                _commitOptimisticReorder(
                                  tasks: visualTasks,
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                );
                              },
                              onReorderStart: (index) {
                                if (index < 0 || index >= visualTasks.length) {
                                  return;
                                }
                                setState(() {
                                  _draggingTaskId = visualTasks[index].id;
                                  _dragging = true;
                                  _hoveringScrim = false;
                                });
                              },
                              onReorderUpdate: (details) {
                                _updateDropHover(details.globalPosition);
                              },
                              onReorderEnd: (_) => _clearDragState(),
                              onReorderCancel: (_) => _clearDragState(),
                              gapBehavior: (details) {
                                return _isInsideList(details.globalPosition)
                                    ? FrameLeanReorderGapBehavior.move
                                    : FrameLeanReorderGapBehavior.restoreOrigin;
                              },
                              onDrop: (details) {
                                final task = _draggingTaskFor(
                                  visualTasks,
                                  details,
                                );
                                if (task == null) {
                                  return FrameLeanReorderDropDisposition
                                      .cancelled;
                                }
                                if (_isOnScrim(details.globalPosition)) {
                                  unawaited(_removeTask(task));
                                  return FrameLeanReorderDropDisposition
                                      .accepted;
                                }
                                if (!_isInsideList(details.globalPosition)) {
                                  return FrameLeanReorderDropDisposition
                                      .cancelled;
                                }
                                return FrameLeanReorderDropDisposition.reorder;
                              },
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
                              acceptedDropProxyDecorator:
                                  (child, index, animation) {
                                    return FadeTransition(
                                      key: const Key(
                                        'task-folder-accepted-drop-proxy',
                                      ),
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.94,
                                          end: 1,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              itemBuilder: (context, index) {
                                final task = visualTasks[index];
                                final actionsEnabled =
                                    !_removeCommitInFlight &&
                                    !_reorderCommitInFlight;
                                final dragEnabled =
                                    actionsEnabled &&
                                    task.status != TaskStatus.running;
                                return Padding(
                                  key: ValueKey('folder-task-${task.id}'),
                                  padding: EdgeInsets.only(
                                    bottom: index == visualTasks.length - 1
                                        ? 0
                                        : 8,
                                  ),
                                  child: MediaTaskListTile(
                                    task: task,
                                    thumbnail: widget.thumbnailForTask(task),
                                    onStart: () => widget.onStart(task),
                                    onPause: () => widget.onPause(task),
                                    onRetry: () => widget.onRetry(task),
                                    onRelink: () => widget.onRelink(task),
                                    onShowLog: () => widget.onShowLog(task),
                                    onRevealOutput: () =>
                                        widget.onRevealOutput(task),
                                    onRemove: actionsEnabled
                                        ? () => unawaited(_removeTask(task))
                                        : null,
                                    removeTooltip: '移出任务夹',
                                    removeIcon:
                                        Icons.remove_circle_outline_rounded,
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MediaTask> _resolveVisualTasks() {
    final sourceTasks = _displayTasks
        .where((task) => !_pendingRemovalIds.contains(task.id))
        .toList();
    final optimisticOrder = _optimisticOrder;
    if (optimisticOrder == null) {
      return sourceTasks;
    }

    final sourceById = {for (final task in sourceTasks) task.id: task};
    if (sourceById.length != optimisticOrder.length ||
        optimisticOrder.any((id) => !sourceById.containsKey(id))) {
      _optimisticOrder = null;
      return sourceTasks;
    }
    final sourceOrder = sourceTasks.map((task) => task.id).toList();
    if (_sameOrder(sourceOrder, optimisticOrder)) {
      _optimisticOrder = null;
      return sourceTasks;
    }
    return optimisticOrder.map((id) => sourceById[id]!).toList();
  }

  bool _sameOrder(List<String> source, List<String>? target) {
    if (target == null || source.length != target.length) {
      return false;
    }
    for (var index = 0; index < source.length; index += 1) {
      if (source[index] != target[index]) {
        return false;
      }
    }
    return true;
  }

  void _commitOptimisticReorder({
    required List<MediaTask> tasks,
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= tasks.length) {
      return;
    }
    final visualIndex = (newIndex > oldIndex ? newIndex - 1 : newIndex)
        .clamp(0, tasks.length - 1)
        .toInt();
    final generation = ++_reorderGeneration;
    if (visualIndex != oldIndex) {
      final reordered = [...tasks];
      final movedTask = reordered.removeAt(oldIndex);
      reordered.insert(visualIndex, movedTask);
      setState(() {
        _optimisticOrder = reordered.map((task) => task.id).toList();
        _reorderCommitInFlight = true;
      });
    }
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
      if (mounted && generation == _reorderGeneration) {
        setState(() {
          _optimisticOrder = null;
          _reorderCommitInFlight = false;
        });
      }
      return;
    }
    if (mounted && generation == _reorderGeneration) {
      setState(() {
        _reorderCommitInFlight = false;
      });
    }
  }

  Future<void> _removeTask(MediaTask task) async {
    if (_removeCommitInFlight || _pendingRemovalIds.contains(task.id)) {
      return;
    }
    setState(() {
      _pendingRemovalIds.add(task.id);
      _removeCommitInFlight = true;
      _dragging = false;
      _hoveringScrim = false;
    });
    try {
      await widget.onRemoveTask(task);
    } on Object {
      if (mounted) {
        setState(() {
          _pendingRemovalIds.remove(task.id);
          _removeCommitInFlight = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _removeCommitInFlight = false;
      });
    }
  }

  MediaTask? _draggingTaskFor(
    List<MediaTask> tasks,
    FrameLeanReorderDropDetails details,
  ) {
    final taskId = _draggingTaskId;
    if (taskId != null) {
      for (final task in tasks) {
        if (task.id == taskId) {
          return task;
        }
      }
    }
    return details.oldIndex >= 0 && details.oldIndex < tasks.length
        ? tasks[details.oldIndex]
        : null;
  }

  void _updateDropHover(Offset globalPosition) {
    final hoveringScrim = _isOnScrim(globalPosition);
    if (_hoveringScrim == hoveringScrim && _dragging) {
      return;
    }
    setState(() {
      _dragging = true;
      _hoveringScrim = hoveringScrim;
    });
  }

  void _clearDragState() {
    if (!_dragging && !_hoveringScrim && _draggingTaskId == null) {
      return;
    }
    setState(() {
      _draggingTaskId = null;
      _dragging = false;
      _hoveringScrim = false;
    });
  }

  bool _isOnScrim(Offset globalPosition) {
    final panelRect = _globalRectFor(_panelKey);
    return panelRect != null && !panelRect.contains(globalPosition);
  }

  bool _isInsideList(Offset globalPosition) {
    return _globalRectFor(_listViewportKey)?.contains(globalPosition) ?? false;
  }

  Rect? _globalRectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
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
    return FrameLeanReorderableDragStartListener(
      index: index,
      enabled: enabled,
      child: handle,
    );
  }
}
