import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/bottom_bar.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/task_list_card.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/top_bar.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/drop_overlay.dart';

class WorkbenchShell extends StatelessWidget {
  const WorkbenchShell({
    super.key,
    required this.taskList,
    required this.selectedTask,
    required this.importEnabled,
    required this.importDragging,
    required this.hasRunningTask,
    required this.queueActionInFlight,
    required this.thumbnailForTask,
    required this.onImportDraggingChanged,
    required this.onImportDrop,
    required this.onReorder,
    required this.onOpenTask,
    required this.onStart,
    required this.onPause,
    required this.onRemove,
    required this.onRetry,
    required this.onRelink,
    required this.onShowLog,
    required this.onContextMenu,
    required this.onAddTask,
    required this.onOpenSettings,
    required this.onClearTasks,
    required this.onPrimaryQueuePressed,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final MediaTask? selectedTask;
  final bool importEnabled;
  final bool importDragging;
  final bool hasRunningTask;
  final bool queueActionInFlight;
  final ImageProvider? Function(MediaTask task) thumbnailForTask;
  final ValueChanged<bool> onImportDraggingChanged;
  final ValueChanged<DropDoneDetails> onImportDrop;
  final ReorderCallback onReorder;
  final ValueChanged<MediaTask> onOpenTask;
  final ValueChanged<MediaTask> onStart;
  final ValueChanged<MediaTask> onPause;
  final ValueChanged<MediaTask> onRemove;
  final ValueChanged<MediaTask> onRetry;
  final ValueChanged<MediaTask> onRelink;
  final ValueChanged<MediaTask> onShowLog;
  final WorkbenchTaskPositionCallback onContextMenu;
  final VoidCallback onAddTask;
  final VoidCallback onOpenSettings;
  final VoidCallback onClearTasks;
  final VoidCallback onPrimaryQueuePressed;

  @override
  Widget build(BuildContext context) {
    final reserveTopNoticeArea =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
    final topInset = reserveTopNoticeArea
        ? WorkbenchConstants.appTopBarHeight
        : 0.0;

    return DropTarget(
      enable: importEnabled,
      onDragEntered: (_) {
        if (importEnabled && !importDragging) {
          onImportDraggingChanged(true);
        }
      },
      onDragExited: (_) {
        if (importEnabled && importDragging) {
          onImportDraggingChanged(false);
        }
      },
      onDragDone: onImportDrop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: WorkbenchConstants.minWorkbenchWidth,
                  minHeight: WorkbenchConstants.minWorkbenchHeight,
                  maxWidth:
                      constraints.maxWidth <
                          WorkbenchConstants.minWorkbenchWidth
                      ? WorkbenchConstants.minWorkbenchWidth
                      : constraints.maxWidth,
                  maxHeight:
                      constraints.maxHeight <
                          WorkbenchConstants.minWorkbenchHeight
                      ? WorkbenchConstants.minWorkbenchHeight
                      : constraints.maxHeight,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
                  child: Stack(
                    children: [
                      if (defaultTargetPlatform == TargetPlatform.macOS)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: WorkbenchTopBar(),
                        ),
                      if (defaultTargetPlatform == TargetPlatform.windows)
                        const Positioned(
                          key: Key('windows-notice-safe-area'),
                          left: 0,
                          top: 0,
                          right: 0,
                          height: WorkbenchConstants.appTopBarHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE6E6E6)),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        top: topInset,
                        bottom: 48,
                        child: WorkbenchTaskListCard(
                          taskList: taskList,
                          selectedTask: selectedTask,
                          thumbnailForTask: thumbnailForTask,
                          onReorder: onReorder,
                          onOpenTask: onOpenTask,
                          onStart: onStart,
                          onPause: onPause,
                          onRemove: onRemove,
                          onRetry: onRetry,
                          onRelink: onRelink,
                          onShowLog: onShowLog,
                          onContextMenu: onContextMenu,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: WorkbenchBottomBar(
                          taskList: taskList,
                          hasRunningTask: hasRunningTask,
                          queueActionInFlight: queueActionInFlight,
                          onAddTask: onAddTask,
                          onOpenSettings: onOpenSettings,
                          onClearTasks: onClearTasks,
                          onPrimaryQueuePressed: onPrimaryQueuePressed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (importDragging) const WorkbenchDropOverlay(),
        ],
      ),
    );
  }
}
