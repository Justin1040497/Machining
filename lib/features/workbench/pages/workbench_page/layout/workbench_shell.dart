import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/presentation/app_layout_constants.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/bottom_bar.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/task_list_card.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/top_bar.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/drop_overlay.dart';

class WorkbenchShell extends StatelessWidget {
  const WorkbenchShell({
    super.key,
    required this.taskList,
    required this.taskFolders,
    required this.selectedTaskIds,
    required this.selectionMode,
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
    required this.onRevealOutput,
    required this.onContextMenu,
    required this.onToggleSelectionMode,
    required this.onToggleTaskSelection,
    required this.onSelectTasksWithRectangle,
    required this.onCreateFolderFromSelection,
    required this.onMoveTaskToFolder,
    required this.onOpenFolderSettings,
    required this.onOpenFolderContents,
    required this.onStartFolder,
    required this.onPauseFolder,
    required this.onRetryFolder,
    required this.onRelinkFolder,
    required this.onShowFolderLog,
    required this.onDeleteFolder,
    required this.onAddTask,
    required this.onOpenSettings,
    required this.themeMode,
    required this.onToggleThemeMode,
    required this.onOpenNotifications,
    this.updateState,
    this.onOpenUpdate,
    this.unreadNotificationCount = 0,
    this.showNotificationBadge = true,
    required this.onClearTasks,
    required this.onPrimaryQueuePressed,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final AsyncValue<List<TaskFolder>> taskFolders;
  final Set<String> selectedTaskIds;
  final bool selectionMode;
  final bool importEnabled;
  final bool importDragging;
  final bool hasRunningTask;
  final bool queueActionInFlight;
  final ImageProvider? Function(MediaTask task) thumbnailForTask;
  final ValueChanged<bool> onImportDraggingChanged;
  final ValueChanged<DropDoneDetails> onImportDrop;
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
  final VoidCallback onToggleSelectionMode;
  final ValueChanged<MediaTask> onToggleTaskSelection;
  final WorkbenchTaskSelectionCallback onSelectTasksWithRectangle;
  final VoidCallback onCreateFolderFromSelection;
  final WorkbenchTaskFolderDropCallback onMoveTaskToFolder;
  final ValueChanged<TaskFolder> onOpenFolderSettings;
  final ValueChanged<TaskFolder> onOpenFolderContents;
  final ValueChanged<TaskFolder> onStartFolder;
  final ValueChanged<TaskFolder> onPauseFolder;
  final ValueChanged<TaskFolder> onRetryFolder;
  final ValueChanged<TaskFolder> onRelinkFolder;
  final ValueChanged<TaskFolder> onShowFolderLog;
  final ValueChanged<TaskFolder> onDeleteFolder;
  final VoidCallback onAddTask;
  final VoidCallback onOpenSettings;
  final AppThemeMode themeMode;
  final VoidCallback onToggleThemeMode;
  final VoidCallback onOpenNotifications;
  final AppUpdateState? updateState;
  final VoidCallback? onOpenUpdate;
  final int unreadNotificationCount;
  final bool showNotificationBadge;
  final VoidCallback onClearTasks;
  final VoidCallback onPrimaryQueuePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final reserveTopNoticeArea =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
    final topInset = reserveTopNoticeArea
        ? AppLayoutConstants.topBarHeight
        : 0.0;
    final looseTaskCount =
        taskList.asData?.value.where((task) => task.folderId == null).length ??
        0;
    final selectedCount = selectedTaskIds.length;

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
                  decoration: BoxDecoration(color: colors.surfaceCanvas),
                  child: Stack(
                    children: [
                      if (defaultTargetPlatform == TargetPlatform.macOS)
                        Align(
                          alignment: Alignment.topCenter,
                          child: WorkbenchTopBar(
                            themeMode: themeMode,
                            onToggleThemeMode: onToggleThemeMode,
                            onOpenNotifications: onOpenNotifications,
                            updateState: updateState,
                            onOpenUpdate: onOpenUpdate,
                            unreadNotificationCount: unreadNotificationCount,
                            showNotificationBadge: showNotificationBadge,
                          ),
                        ),
                      if (defaultTargetPlatform == TargetPlatform.windows)
                        Positioned(
                          key: Key('windows-notice-safe-area'),
                          left: 0,
                          top: 0,
                          right: 0,
                          height: AppLayoutConstants.topBarHeight,
                          child: WorkbenchTopBar(
                            themeMode: themeMode,
                            onToggleThemeMode: onToggleThemeMode,
                            onOpenNotifications: onOpenNotifications,
                            updateState: updateState,
                            onOpenUpdate: onOpenUpdate,
                            unreadNotificationCount: unreadNotificationCount,
                            showNotificationBadge: showNotificationBadge,
                            showBottomBorder: true,
                          ),
                        ),
                      Positioned.fill(
                        top: topInset,
                        bottom: 48,
                        child: WorkbenchTaskListCard(
                          taskList: taskList,
                          taskFolders: taskFolders,
                          selectedTaskIds: selectedTaskIds,
                          selectionMode: selectionMode,
                          thumbnailForTask: thumbnailForTask,
                          onReorder: onReorder,
                          onOpenTask: onOpenTask,
                          onStart: onStart,
                          onPause: onPause,
                          onRemove: onRemove,
                          onRetry: onRetry,
                          onRelink: onRelink,
                          onShowLog: onShowLog,
                          onRevealOutput: onRevealOutput,
                          onContextMenu: onContextMenu,
                          onToggleTaskSelection: onToggleTaskSelection,
                          onSelectTasksWithRectangle:
                              onSelectTasksWithRectangle,
                          onMoveTaskToFolder: onMoveTaskToFolder,
                          onOpenFolderSettings: onOpenFolderSettings,
                          onOpenFolderContents: onOpenFolderContents,
                          onStartFolder: onStartFolder,
                          onPauseFolder: onPauseFolder,
                          onRetryFolder: onRetryFolder,
                          onRelinkFolder: onRelinkFolder,
                          onShowFolderLog: onShowFolderLog,
                          onDeleteFolder: onDeleteFolder,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: WorkbenchBottomBar(
                          taskList: taskList,
                          hasRunningTask: hasRunningTask,
                          queueActionInFlight: queueActionInFlight,
                          selectionMode: selectionMode,
                          selectionEnabled: looseTaskCount > 0,
                          onAddTask: onAddTask,
                          onToggleSelectionMode: onToggleSelectionMode,
                          onOpenSettings: onOpenSettings,
                          onClearTasks: onClearTasks,
                          onPrimaryQueuePressed: onPrimaryQueuePressed,
                        ),
                      ),
                      if (selectedCount > 0)
                        Positioned(
                          right: 24,
                          bottom: 78,
                          child: FloatingActionButton.extended(
                            heroTag: 'create-task-folder-from-selection',
                            onPressed: onCreateFolderFromSelection,
                            icon: const Icon(Icons.create_new_folder_rounded),
                            label: Text('创建任务夹 $selectedCount'),
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
