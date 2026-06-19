import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/app/widgets/update_restart_warning_dialog.dart';
import 'package:framelean/app/presentation/media_configuration_ui_constants.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/features/notifications/providers/notification_center_provider.dart';
import 'package:framelean/features/notifications/widgets/notification_center_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/clear_tasks_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/compression_confirmation_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/import_failure_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/restart_unelevated_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_context_menu.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_log_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_rename_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/update_release_notes_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_import_handler.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_task_thumbnail_store.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_windows_privilege.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_content_panel.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_settings_provider.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';

const Object _configValueNotProvided = Object();

@visibleForTesting
class WorkbenchTaskConfigurationInitialValues {
  const WorkbenchTaskConfigurationInitialValues({
    required this.qualityIndex,
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.compressionMode,
    required this.smartPreset,
    required this.targetSizeRatio,
  });

  final int qualityIndex;
  final OutputFormat outputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final ResolutionPreset resolutionPreset;
  final CompressionMode compressionMode;
  final SmartCompressionPreset smartPreset;
  final double targetSizeRatio;
}

@visibleForTesting
WorkbenchTaskConfigurationInitialValues
resolveWorkbenchTaskConfigurationInitialValues({
  required MediaTask task,
  required int selectedQualityIndex,
  required OutputFormat selectedOutputFormat,
  required VideoCodec selectedVideoCodec,
  required EncoderBackend selectedEncoderBackend,
  required ResolutionPreset selectedResolutionPreset,
  required SmartCompressionPreset selectedSmartPreset,
}) {
  final videoConfig = task.mediaKind == MediaKind.video
      ? task.config.video
      : null;
  final isVideoTask = videoConfig != null;

  return WorkbenchTaskConfigurationInitialValues(
    qualityIndex: isVideoTask
        ? WorkbenchQualityPolicy.initialQualityIndexForTask(task)
        : selectedQualityIndex,
    outputFormat: isVideoTask
        ? videoConfig.outputFormat.toVideoOutputFormat()
        : selectedOutputFormat,
    videoCodec: isVideoTask ? videoConfig.videoCodec : selectedVideoCodec,
    encoderBackend: isVideoTask
        ? videoConfig.encoderBackend
        : selectedEncoderBackend,
    resolutionPreset: isVideoTask
        ? videoConfig.resolutionPreset
        : selectedResolutionPreset,
    compressionMode: task.config.compressionMode,
    smartPreset: isVideoTask
        ? videoConfig.smartPreset ??
              WorkbenchQualityPolicy.smartPresetForQualityIndex(
                videoConfig.compressionCrf,
              )
        : selectedSmartPreset,
    targetSizeRatio: isVideoTask
        ? WorkbenchQualityPolicy.initialTargetSizeRatioForTask(task)
        : MediaConfigurationUiConstants.defaultTargetSizeRatio,
  );
}

@visibleForTesting
List<MediaTask> resolveOpenedTaskFolderTasks({
  required List<MediaTask> tasks,
  required TaskFolder? openedFolder,
}) {
  final folderId = openedFolder?.id;
  if (folderId == null) {
    return <MediaTask>[];
  }

  final folderTasks = tasks.where((task) => task.folderId == folderId).toList();
  folderTasks.sort(
    (a, b) => (a.folderSortOrder ?? a.sortOrder).compareTo(
      b.folderSortOrder ?? b.sortOrder,
    ),
  );
  return folderTasks;
}

class WorkbenchPage extends ConsumerStatefulWidget {
  const WorkbenchPage({super.key});

  @override
  ConsumerState<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends ConsumerState<WorkbenchPage> {
  int selectedQualityIndex = 2;
  OutputFormat selectedOutputFormat = OutputFormat.mp4;
  VideoCodec selectedVideoCodec = VideoCodec.h264;
  EncoderBackend selectedEncoderBackend = EncoderBackend.auto;
  ResolutionPreset selectedResolutionPreset = ResolutionPreset.original;
  CompressionMode selectedCompressionMode = CompressionMode.preset;
  SmartCompressionPreset selectedSmartPreset = SmartCompressionPreset.balanced;
  String? selectedTaskId;
  String? openedTaskFolderId;
  bool taskSelectionMode = false;
  final Set<String> selectedTaskIds = {};
  String? syncedConfigTaskId;
  String? syncedQualityTaskKey;
  bool workbenchImportDragging = false;
  bool queueActionInFlight = false;
  final WorkbenchTaskThumbnailStore thumbnailStore =
      WorkbenchTaskThumbnailStore();
  final Set<String> notifiedAnalysisErrorKeys = {};
  final Set<String> workbenchActionsInFlight = {};
  bool windowsPrivilegeNoticeShown = false;
  bool themeModeChangeInFlight = false;
  ProviderSubscription<AsyncValue<List<MediaTask>>>? taskListSubscription;

  @override
  void initState() {
    super.initState();
    taskListSubscription = ref.listenManual<AsyncValue<List<MediaTask>>>(
      mediaTaskListProvider,
      handleTaskListChanged,
      fireImmediately: true,
    );
    unawaited(showWindowsAdministratorDragNoticeIfNeeded());
  }

  @override
  void dispose() {
    taskListSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskList = ref.watch(mediaTaskListProvider);
    final taskFolders = ref.watch(taskFolderListProvider);
    final tasks = taskList.hasValue
        ? taskList.requireValue
        : const <MediaTask>[];
    final folders = taskFolders.asData?.value ?? const <TaskFolder>[];
    final openedFolder = resolveOpenedTaskFolder(folders);
    syncOpenedTaskFolderAfterBuild(openedFolder);
    final openedFolderTasks = resolveOpenedTaskFolderTasks(
      tasks: tasks,
      openedFolder: openedFolder,
    );
    syncTaskThumbnailsAfterBuild(tasks);

    final hasRunningTask = tasks.any(
      (task) => task.status == TaskStatus.running,
    );
    final themeMode = ref.watch(appThemeModeProvider);
    final unreadNotificationCount =
        ref.watch(appNotificationUnreadCountProvider).asData?.value ?? 0;
    final hideNotificationBadge =
        ref.watch(appSettingsProvider).asData?.value.hideNotificationBadge ??
        true;
    final notificationCenterVisible = ref.watch(
      notificationCenterVisibilityProvider,
    );
    final updateState =
        ref.watch(appUpdateProvider).asData?.value ?? AppUpdateState.initial();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          WorkbenchShell(
            taskList: taskList,
            taskFolders: taskFolders,
            selectedTaskIds: selectedTaskIds,
            selectionMode: taskSelectionMode,
            importEnabled: true,
            importDragging: workbenchImportDragging,
            hasRunningTask: hasRunningTask,
            queueActionInFlight: queueActionInFlight,
            thumbnailForTask: thumbnailForTask,
            onImportDraggingChanged: (dragging) {
              setState(() {
                workbenchImportDragging = dragging;
              });
            },
            onImportDrop: handleWorkbenchImportDrop,
            onReorder: reorderTasks,
            onOpenTask: openTask,
            onStart: startOrResumeTask,
            onPause: pauseTask,
            onRemove: deleteTask,
            onRetry: retryTask,
            onRelink: relinkMissingSource,
            onShowLog: showTaskLog,
            onRevealOutput: revealTaskOutput,
            onContextMenu: (task, position) {
              unawaited(showTaskContextMenu(task, position));
            },
            onToggleSelectionMode: toggleTaskSelectionMode,
            onToggleTaskSelection: toggleTaskSelection,
            onSelectTasksWithRectangle: selectTasksWithRectangle,
            onCreateFolderFromSelection: () {
              unawaited(createTaskFoldersFromSelection());
            },
            onMoveTaskToFolder: (task, folder) {
              unawaited(moveTaskIntoFolder(task, folder));
            },
            onOpenFolderSettings: (folder) {
              unawaited(showTaskFolderConfigurationDialog(folder));
            },
            onOpenFolderContents: openTaskFolder,
            onStartFolder: (folder) {
              unawaited(startTaskFolder(folder));
            },
            onPauseFolder: (folder) {
              unawaited(pauseTaskFolder(folder));
            },
            onRetryFolder: (folder) {
              unawaited(retryTaskFolder(folder));
            },
            onRelinkFolder: (folder) {
              unawaited(relinkTaskFolderMissingSource(folder));
            },
            onShowFolderLog: (folder) {
              unawaited(showTaskFolderLog(folder));
            },
            onDeleteFolder: deleteTaskFolder,
            onAddTask: pickAndAddTasks,
            onOpenSettings: () {
              unawaited(openSettingsPage());
            },
            themeMode: themeMode,
            onToggleThemeMode: () {
              unawaited(toggleThemeMode());
            },
            onOpenNotifications: openNotificationCenter,
            updateState: updateState,
            onOpenUpdate: () {
              unawaited(showCurrentUpdateDialog());
            },
            unreadNotificationCount: unreadNotificationCount,
            showNotificationBadge: !hideNotificationBadge,
            onClearTasks: confirmClearTasks,
            onPrimaryQueuePressed: () {
              unawaited(handlePrimaryQueueAction(hasRunningTask));
            },
          ),
          NotificationCenterPanel(
            visible: notificationCenterVisible,
            onClose: closeNotificationCenter,
            onRevealOutput: revealPathInFileManager,
            onOpenUpdateLog: openUpdateLogFromNotification,
            onStartUpdateDownload: startUpdateDownloadFromNotification,
          ),
          TaskFolderContentPanel(
            visible: openedFolder != null,
            folder: openedFolder,
            tasks: openedFolderTasks,
            thumbnailForTask: thumbnailForTask,
            onClose: closeTaskFolder,
            onRemoveTask: removeTaskFromFolder,
            onStart: startOrResumeTask,
            onPause: pauseTask,
            onRetry: retryTask,
            onRelink: relinkMissingSource,
            onShowLog: showTaskLog,
            onRevealOutput: revealTaskOutput,
            onReorder: reorderOpenedTaskFolderTasks,
          ),
        ],
      ),
    );
  }

  void handleTaskListChanged(
    AsyncValue<List<MediaTask>>? previous,
    AsyncValue<List<MediaTask>> next,
  ) {
    if (previous != null) {
      notifyAnalysisErrors(next.asData?.value);
    }

    final tasks = next.asData?.value ?? const <MediaTask>[];
    final selectedTask = resolveSelectedTask(tasks);
    syncSelectedTaskIdAfterBuild(selectedTask);
    syncSelectedTaskIdsAfterBuild(tasks);
    syncSelectedTaskConfigAfterBuild(selectedTask);
    syncQualityPresetAfterBuild(selectedTask);
  }

  void syncSelectedTaskIdsAfterBuild(List<MediaTask> tasks) {
    if (selectedTaskIds.isEmpty) {
      return;
    }

    final selectableIds = {
      for (final task in tasks)
        if (task.folderId == null) task.id,
    };
    final staleIds = selectedTaskIds.difference(selectableIds);
    if (staleIds.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || staleIds.every((id) => !selectedTaskIds.contains(id))) {
        return;
      }
      setState(() {
        selectedTaskIds.removeAll(staleIds);
        if (selectedTaskIds.isEmpty) {
          taskSelectionMode = false;
        }
      });
    });
  }

  void syncOpenedTaskFolderAfterBuild(TaskFolder? openedFolder) {
    if (openedTaskFolderId == null || openedFolder != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || openedTaskFolderId == null) {
        return;
      }
      setState(() {
        openedTaskFolderId = null;
      });
    });
  }

  Future<void> showWindowsAdministratorDragNoticeIfNeeded() async {
    final isElevated = await WorkbenchWindowsPrivilege.isRunningElevated();
    if (!isElevated || !mounted || windowsPrivilegeNoticeShown) {
      return;
    }

    windowsPrivilegeNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      showWorkbenchSnackBar(
        '管理员模式下 Windows 可能阻止拖入文件',
        action: SnackBarAction(
          label: '普通模式重启',
          onPressed: () => unawaited(restartInNormalMode()),
        ),
      );
    });
  }

  Future<void> restartInNormalMode() async {
    final taskList = ref.read(mediaTaskListProvider);
    final tasks = taskList.hasValue ? taskList.requireValue : null;
    final hasActiveTask =
        tasks?.any(
          (task) =>
              task.status == TaskStatus.running ||
              task.status == TaskStatus.paused,
        ) ??
        false;

    if (hasActiveTask) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const RestartUnelevatedDialog(),
      );
      if (confirmed != true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    try {
      await WorkbenchWindowsPrivilege.restartUnelevated();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      showWorkbenchSnackBar(error.toString());
    }
  }

  MediaTask? resolveSelectedTask(List<MediaTask> tasks) {
    if (tasks.isEmpty) {
      return null;
    }

    final currentId = selectedTaskId;
    if (currentId != null) {
      for (final task in tasks) {
        if (task.id == currentId) {
          return task;
        }
      }
    }

    return tasks.first;
  }

  void syncSelectedTaskIdAfterBuild(MediaTask? selectedTask) {
    final nextSelectedTaskId = selectedTask?.id;
    if (selectedTaskId == nextSelectedTaskId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || selectedTaskId == nextSelectedTaskId) {
        return;
      }

      setState(() {
        selectedTaskId = nextSelectedTaskId;
      });
    });
  }

  void syncSelectedTaskConfigAfterBuild(MediaTask? selectedTask) {
    final taskId = selectedTask?.id;
    if (taskId == null || syncedConfigTaskId == taskId) {
      return;
    }

    final config = selectedTask!.config;
    if (selectedTask.mediaKind != MediaKind.video) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || syncedConfigTaskId == taskId) {
          return;
        }

        setState(() {
          selectedCompressionMode = config.compressionMode;
          syncedConfigTaskId = taskId;
        });
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || syncedConfigTaskId == taskId) {
        return;
      }

      setState(() {
        selectedOutputFormat = config.outputFormat;
        selectedVideoCodec = config.videoCodec;
        selectedEncoderBackend = config.encoderBackend;
        selectedResolutionPreset = config.resolutionPreset;
        selectedCompressionMode = config.compressionMode;
        selectedSmartPreset =
            config.smartPreset ??
            WorkbenchQualityPolicy.smartPresetForQualityIndex(
              config.compressionCrf,
            );
        syncedConfigTaskId = taskId;
      });
    });
  }

  void syncQualityPresetAfterBuild(MediaTask? selectedTask) {
    final taskId = selectedTask?.id;
    if (taskId == null) {
      return;
    }
    if (selectedTask!.mediaKind != MediaKind.video) {
      return;
    }

    final syncKey = '$taskId:${selectedTask.analysisUpdatedAt}';
    if (syncedQualityTaskKey == syncKey) {
      return;
    }

    final nextIndex = WorkbenchQualityPolicy.initialQualityIndexForTask(
      selectedTask,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || syncedQualityTaskKey == syncKey) {
        return;
      }

      setState(() {
        selectedQualityIndex = nextIndex;
        syncedQualityTaskKey = syncKey;
      });
    });
  }

  void notifyAnalysisErrors(List<MediaTask>? tasks) {
    if (tasks == null) {
      return;
    }

    for (final task in tasks) {
      final message = task.analysisErrorMessage;
      if (message == null || message.trim().isEmpty) {
        continue;
      }

      final key = '${task.id}:$message';
      if (!notifiedAnalysisErrorKeys.add(key)) {
        continue;
      }

      showWorkbenchSnackBar('${task.fileName}: $message');
    }
  }

  ImageProvider? thumbnailForTask(MediaTask task) {
    return thumbnailStore.imageForTask(task);
  }

  void syncTaskThumbnailsAfterBuild(List<MediaTask> tasks) {
    thumbnailStore.scheduleGenerationAfterBuild(
      tasks: tasks,
      ref: ref,
      isMounted: () => mounted,
      onChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> pauseRunningTasks() async {
    try {
      final result = await ref
          .read(mediaTaskListProvider.notifier)
          .pauseAllRunningTasks();
      if (result.message != null) {
        showWorkbenchSnackBar(result.message!);
      }
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    try {
      await ref
          .read(mediaTaskListProvider.notifier)
          .reorderTasks(oldIndex: oldIndex, newIndex: newIndex);
    } on Object catch (error, stackTrace) {
      if (mounted) {
        showWorkbenchSnackBar('任务排序保存失败: $error');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> openSettingsPage() async {
    await runWorkbenchActionOnce('open-settings-page', () async {
      closeNotificationCenter();
      await context.push<void>('/settings');
      if (!mounted) {
        return;
      }

      ref.invalidate(appSettingsProvider);
      setState(() {
        workbenchImportDragging = false;
      });
    });
  }

  Future<void> runWorkbenchActionOnce(
    String key,
    Future<void> Function() action,
  ) async {
    if (!workbenchActionsInFlight.add(key)) {
      return;
    }

    try {
      await action();
    } finally {
      workbenchActionsInFlight.remove(key);
    }
  }

  Future<void> toggleThemeMode() async {
    if (themeModeChangeInFlight) {
      return;
    }

    themeModeChangeInFlight = true;
    final oldMode = ref.read(appThemeModeProvider);
    // Use the actual rendered brightness so that "follow system" toggles
    // to the opposite of what the user sees, not always to dark.
    final isCurrentlyDark = Theme.of(context).brightness == Brightness.dark;
    final nextMode = isCurrentlyDark ? AppThemeMode.light : AppThemeMode.dark;
    ref.read(appThemeModeProvider.notifier).setThemeMode(nextMode);

    try {
      final repository = ref.read(appSettingsRepositoryProvider);
      final settings = await LoadAppSettingsUseCase(
        repository: repository,
      ).call();
      await repository.saveSettings(settings.copyWith(themeMode: nextMode));
      unawaited(ref.read(themePreferencesCacheProvider).write(nextMode));
    } on Object catch (error) {
      ref.read(appThemeModeProvider.notifier).setThemeMode(oldMode);
      showWorkbenchSnackBar('主题切换失败: $error');
    } finally {
      themeModeChangeInFlight = false;
    }
  }

  void openNotificationCenter() {
    ref.read(notificationCenterVisibilityProvider.notifier).toggle();
  }

  void closeNotificationCenter() {
    ref.read(notificationCenterVisibilityProvider.notifier).close();
  }

  Future<void> openUpdateLogFromNotification(String target) async {
    closeNotificationCenter();
    final current = ref.read(appUpdateProvider).asData?.value;
    final release = current?.release;
    if (release != null &&
        target ==
            '${release.platform}:${release.version}:${release.buildNumber}') {
      await showCurrentUpdateDialog();
      return;
    }

    final notes = await _findReleaseNotesForTarget(target);
    if (!mounted) {
      return;
    }
    if (notes == null) {
      context.push('/settings/release-notes');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => UpdateReleaseNotesDialog.history(
        notes: notes,
        onOpenMore: () {
          Navigator.of(context).pop();
          context.push('/settings/release-notes?version=${notes.version}');
        },
      ),
    );
  }

  Future<void> startUpdateDownloadFromNotification(String target) async {
    closeNotificationCenter();
    await ref.read(appUpdateProvider.notifier).startOrResumeDownload();
  }

  Future<AppReleaseNotes?> _findReleaseNotesForTarget(String target) async {
    final parts = target.split(':');
    if (parts.length < 3) {
      return null;
    }
    final version = parts[1];
    final notes = await ref.read(appReleaseNotesProvider.future);
    for (final item in notes) {
      if (item.version == version) {
        return item;
      }
    }
    return null;
  }

  Future<void> showCurrentUpdateDialog() async {
    final updateState = ref.read(appUpdateProvider).asData?.value;
    if (!mounted || updateState?.release == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (dialogContext, ref, _) {
            final liveState =
                ref.watch(appUpdateProvider).asData?.value ?? updateState!;
            return UpdateReleaseNotesDialog.current(
              updateState: liveState,
              onStartDownload: () {
                unawaited(
                  ref.read(appUpdateProvider.notifier).startOrResumeDownload(),
                );
              },
              onPauseDownload: () {
                ref.read(appUpdateProvider.notifier).pauseDownload();
              },
              onInstallUpdate: () {
                unawaited(installUpdateWithTaskCheck());
              },
              onOpenMore: () {
                Navigator.of(dialogContext).pop();
                final release = liveState.release;
                context.push(
                  '/settings/release-notes?version=${release!.version}',
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> installUpdateWithTaskCheck() async {
    final tasks = ref.read(mediaTaskListProvider).asData?.value ?? const [];
    final hasUnfinishedTasks = tasks.any(_taskNeedsUpdateRestartWarning);
    if (hasUnfinishedTasks && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const UpdateRestartWarningDialog(),
      );
      if (confirmed != true) {
        return;
      }
      await ref.read(mediaTaskListProvider.notifier).pauseAllRunningTasks();
    }

    await ref.read(appUpdateProvider.notifier).installDownloadedUpdate();
  }

  MediaTaskConfig resolveVideoDraftConfig({
    required MediaTask task,
    required WorkbenchTaskConfigurationDraft draft,
    required bool usePerTaskTargetSize,
  }) {
    final isTargetSize = draft.compressionMode == CompressionMode.targetSize;
    final targetSizeRatio = WorkbenchQualityPolicy.normalizeTargetSizeRatio(
      draft.targetSizeRatio,
    );
    final resolvedQualityIndex = isTargetSize
        ? WorkbenchQualityPolicy.qualityIndexForTargetSizeRatio(targetSizeRatio)
        : draft.qualityIndex;
    final qualityOption =
        WorkbenchConstants.qualityOptions[resolvedQualityIndex];
    final targetSizeBytes = usePerTaskTargetSize
        ? WorkbenchQualityPolicy.targetSizeBytesForTargetRatio(
            task,
            targetSizeRatio,
          )
        : null;

    return draft.config.copyWith(
      outputFormat: draft.outputFormat,
      videoCodec: draft.videoCodec,
      encoderBackend: draft.encoderBackend,
      resolutionPreset: draft.resolutionPreset,
      compressionCrf: qualityOption.crf,
      compressionMode: isTargetSize
          ? CompressionMode.targetSize
          : CompressionMode.preset,
      smartPreset: isTargetSize ? null : draft.smartPreset,
      targetSizeBytes: isTargetSize ? targetSizeBytes : null,
      targetSizeRatio: isTargetSize ? targetSizeRatio : null,
    );
  }

  Future<void> showTaskFolderConfigurationDialog(TaskFolder folder) async {
    await runWorkbenchActionOnce(
      'show-task-folder-configuration-dialog',
      () async {
        final tasks = ref.read(mediaTaskListProvider).asData?.value ?? const [];
        final folderTasks = resolveOpenedTaskFolderTasks(
          tasks: tasks,
          openedFolder: folder,
        );
        final representativeTask = taskFolderRepresentativeTask(
          folder: folder,
          tasks: folderTasks,
        );
        final isVideoTask = representativeTask.mediaKind == MediaKind.video;
        final initialValues = resolveWorkbenchTaskConfigurationInitialValues(
          task: representativeTask,
          selectedQualityIndex: selectedQualityIndex,
          selectedOutputFormat: selectedOutputFormat,
          selectedVideoCodec: selectedVideoCodec,
          selectedEncoderBackend: selectedEncoderBackend,
          selectedResolutionPreset: selectedResolutionPreset,
          selectedSmartPreset: selectedSmartPreset,
        );

        final draft = await showWorkbenchTaskConfigurationEditor(
          context: context,
          task: representativeTask,
          thumbnail: folderTasks.isEmpty
              ? null
              : thumbnailForTask(folderTasks.first),
          title: '任务夹设置',
          selectedQualityIndex: initialValues.qualityIndex,
          selectedOutputFormat: initialValues.outputFormat,
          selectedVideoCodec: initialValues.videoCodec,
          selectedEncoderBackend: initialValues.encoderBackend,
          selectedResolutionPreset: initialValues.resolutionPreset,
          selectedCompressionMode: initialValues.compressionMode,
          selectedSmartPreset: initialValues.smartPreset,
          selectedTargetSizeRatio: initialValues.targetSizeRatio,
          onOpenSource: null,
        );
        if (!mounted || draft == null) {
          return;
        }

        final updatedConfig = isVideoTask
            ? resolveVideoDraftConfig(
                task: representativeTask,
                draft: draft,
                usePerTaskTargetSize: false,
              )
            : draft.config;

        try {
          await ref
              .read(mediaTaskListProvider.notifier)
              .applyTaskFolderConfig(
                folderId: folder.id,
                config: updatedConfig,
              );
          if (!mounted) {
            return;
          }
          showWorkbenchSnackBar('任务夹设置已应用');
        } on Object catch (error) {
          showWorkbenchSnackBar(error.toString());
        }
      },
    );
  }

  MediaTask taskFolderRepresentativeTask({
    required TaskFolder folder,
    required List<MediaTask> tasks,
  }) {
    final firstTask = tasks.isEmpty ? null : tasks.first;
    return MediaTask(
      id: 'folder-config-${folder.id}',
      inputPath: firstTask?.inputPath ?? folder.name,
      fileName: folder.name,
      mediaKind: folder.mediaKind,
      purpose: TaskPurpose.compression,
      status: TaskStatus.pending,
      config: folder.defaultConfig,
      progress: 0,
      sortOrder: folder.sortOrder,
      createdAt: folder.createdAt,
      sourceFileFingerprint: firstTask?.sourceFileFingerprint,
      analysisResult: firstTask?.analysisResult,
      analysisUpdatedAt: firstTask?.analysisUpdatedAt,
    );
  }

  Future<void> showTaskConfigurationDialog(MediaTask task) async {
    await runWorkbenchActionOnce('show-task-configuration-dialog', () async {
      final isVideoTask = task.mediaKind == MediaKind.video;
      final initialValues = resolveWorkbenchTaskConfigurationInitialValues(
        task: task,
        selectedQualityIndex: selectedQualityIndex,
        selectedOutputFormat: selectedOutputFormat,
        selectedVideoCodec: selectedVideoCodec,
        selectedEncoderBackend: selectedEncoderBackend,
        selectedResolutionPreset: selectedResolutionPreset,
        selectedSmartPreset: selectedSmartPreset,
      );

      setState(() {
        selectedTaskId = task.id;
        selectedOutputFormat = initialValues.outputFormat;
        selectedVideoCodec = initialValues.videoCodec;
        selectedEncoderBackend = initialValues.encoderBackend;
        selectedResolutionPreset = initialValues.resolutionPreset;
        selectedCompressionMode = initialValues.compressionMode;
        selectedSmartPreset = initialValues.smartPreset;
        selectedQualityIndex = initialValues.qualityIndex;
        syncedConfigTaskId = task.id;
        syncedQualityTaskKey = '${task.id}:${task.analysisUpdatedAt}';
      });

      final draft = await showWorkbenchTaskConfigurationEditor(
        context: context,
        task: task,
        thumbnail: thumbnailForTask(task),
        selectedQualityIndex: initialValues.qualityIndex,
        selectedOutputFormat: initialValues.outputFormat,
        selectedVideoCodec: initialValues.videoCodec,
        selectedEncoderBackend: initialValues.encoderBackend,
        selectedResolutionPreset: initialValues.resolutionPreset,
        selectedCompressionMode: initialValues.compressionMode,
        selectedSmartPreset: initialValues.smartPreset,
        selectedTargetSizeRatio: initialValues.targetSizeRatio,
        onOpenSource: () {
          unawaited(revealPathInFileManager(task.inputPath));
        },
      );
      if (!mounted || draft == null) {
        return;
      }

      if (!isVideoTask) {
        try {
          await updateSelectedTaskConfig(config: draft.config);
        } on Object catch (error) {
          showWorkbenchSnackBar(error.toString());
        }
        return;
      }

      try {
        final updatedConfig = resolveVideoDraftConfig(
          task: task,
          draft: draft,
          usePerTaskTargetSize: true,
        );

        await updateSelectedTaskConfig(config: updatedConfig);

        if (!mounted) {
          return;
        }

        setState(() {
          selectedQualityIndex =
              draft.compressionMode == CompressionMode.targetSize
              ? WorkbenchQualityPolicy.qualityIndexForTargetSizeRatio(
                  WorkbenchQualityPolicy.normalizeTargetSizeRatio(
                    draft.targetSizeRatio,
                  ),
                )
              : draft.qualityIndex;
          selectedOutputFormat = draft.outputFormat;
          selectedVideoCodec = draft.videoCodec;
          selectedEncoderBackend = draft.encoderBackend;
          selectedResolutionPreset = draft.resolutionPreset;
          selectedCompressionMode =
              draft.compressionMode == CompressionMode.targetSize
              ? CompressionMode.targetSize
              : CompressionMode.preset;
          selectedSmartPreset = draft.smartPreset;
        });
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  void openTask(MediaTask task) {
    if (task.status == TaskStatus.analyzing) {
      unawaited(
        ref
            .read(appNotificationManagerProvider)
            .notifyInteraction(
              title: '正在分析，请稍等',
              message: task.fileName,
              source: 'workbench',
            ),
      );
      return;
    }

    if (task.status == TaskStatus.missingSource) {
      unawaited(relinkMissingSource(task));
      return;
    }

    unawaited(showTaskConfigurationDialog(task));
  }

  void toggleTaskSelectionMode() {
    setState(() {
      taskSelectionMode = !taskSelectionMode;
      if (!taskSelectionMode) {
        selectedTaskIds.clear();
      }
    });
  }

  void toggleTaskSelection(MediaTask task) {
    if (task.folderId != null) {
      return;
    }

    setState(() {
      taskSelectionMode = true;
      if (!selectedTaskIds.add(task.id)) {
        selectedTaskIds.remove(task.id);
      }
      if (selectedTaskIds.isEmpty) {
        taskSelectionMode = true;
      }
    });
  }

  void selectTasksWithRectangle(Set<String> taskIds, {bool toggle = false}) {
    if (taskIds.isEmpty) {
      return;
    }
    setState(() {
      taskSelectionMode = true;
      if (toggle) {
        for (final taskId in taskIds) {
          if (!selectedTaskIds.add(taskId)) {
            selectedTaskIds.remove(taskId);
          }
        }
      } else {
        selectedTaskIds
          ..clear()
          ..addAll(taskIds);
      }
    });
  }

  Future<void> createTaskFoldersFromSelection() async {
    await runWorkbenchActionOnce(
      'create-task-folders-from-selection',
      () async {
        if (selectedTaskIds.isEmpty) {
          return;
        }

        try {
          final folders = await ref
              .read(mediaTaskListProvider.notifier)
              .createTaskFoldersFromTaskIds(selectedTaskIds.toList());
          if (!mounted) {
            return;
          }

          setState(() {
            selectedTaskIds.clear();
            taskSelectionMode = false;
            openedTaskFolderId = folders.length == 1 ? folders.single.id : null;
          });
          showWorkbenchSnackBar(
            folders.length == 1 ? '已创建任务夹' : '已按媒体类型创建 ${folders.length} 个任务夹',
          );
        } on Object catch (error) {
          showWorkbenchSnackBar(error.toString());
        }
      },
    );
  }

  Future<void> moveTaskIntoFolder(MediaTask task, TaskFolder folder) async {
    await runWorkbenchActionOnce('move-task-to-folder:${task.id}', () async {
      if (task.mediaKind != folder.mediaKind || task.folderId != null) {
        showWorkbenchSnackBar('任务夹只接受同类型媒体');
        return;
      }

      try {
        await ref
            .read(mediaTaskListProvider.notifier)
            .moveTaskToFolder(taskId: task.id, folderId: folder.id);
        if (!mounted) {
          return;
        }
        setState(() {
          selectedTaskIds.remove(task.id);
          if (selectedTaskIds.isEmpty) {
            taskSelectionMode = false;
          }
        });
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> handlePrimaryQueueAction(bool hasRunningTask) async {
    if (queueActionInFlight) {
      return;
    }

    setState(() {
      queueActionInFlight = true;
    });

    try {
      if (hasRunningTask) {
        await pauseRunningTasks();
        return;
      }

      await startExecutionQueue();
    } finally {
      if (mounted) {
        setState(() {
          queueActionInFlight = false;
        });
      }
    }
  }

  Future<void> pickAndAddTasks() async {
    await runWorkbenchActionOnce('pick-and-add-tasks', () async {
      try {
        final paths =
            (await ref.read(fileSelectionServiceProvider).pickMediaFiles())
                .where((path) => path.trim().isNotEmpty)
                .toList();
        if (paths.isEmpty) {
          return;
        }

        final createdTasks = await ref
            .read(mediaTaskListProvider.notifier)
            .createDraftsFromPaths(paths);
        if (createdTasks.isNotEmpty) {
          setState(() {
            selectedTaskId = createdTasks.first.id;
            selectedTaskIds.clear();
            taskSelectionMode = false;
            syncedConfigTaskId = null;
            syncedQualityTaskKey = null;
          });
        }
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> handleWorkbenchImportDrop(DropDoneDetails details) async {
    if (mounted) {
      setState(() {
        workbenchImportDragging = false;
      });
    }

    if (details.files.isEmpty) {
      return;
    }

    final result = await WorkbenchImportHandler.importDroppedPaths(
      paths: details.files.map((item) => item.path),
      notifier: ref.read(mediaTaskListProvider.notifier),
    );

    if (!mounted) {
      return;
    }

    if (result.createdTasks.isNotEmpty) {
      setState(() {
        selectedTaskId = result.createdTasks.first.id;
        selectedTaskIds.clear();
        taskSelectionMode = false;
        syncedConfigTaskId = null;
        syncedQualityTaskKey = null;
      });
    }

    showDroppedImportSnackBar(
      successCount: result.createdTasks.length,
      failures: result.failures,
    );
  }

  void showDroppedImportSnackBar({
    required int successCount,
    required List<DroppedImportFailure> failures,
  }) {
    if (failures.isEmpty) {
      showWorkbenchSnackBar('导入成功');
      return;
    }

    showWorkbenchSnackBar(
      '导入完成：成功 $successCount 个，失败 ${failures.length} 个',
      action: SnackBarAction(
        label: '日志',
        onPressed: () => showDroppedImportFailureDialog(failures),
      ),
    );
  }

  Future<void> showDroppedImportFailureDialog(
    List<DroppedImportFailure> failures,
  ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => ImportFailureDialog(failures: failures),
    );
  }

  Future<void> confirmClearTasks() async {
    await runWorkbenchActionOnce('confirm-clear-tasks', () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const ClearTasksDialog(),
      );

      if (confirmed != true) {
        return;
      }

      await ref.read(mediaTaskListProvider.notifier).clearTasks();
      setState(() {
        selectedTaskId = null;
        selectedTaskIds.clear();
        taskSelectionMode = false;
        syncedConfigTaskId = null;
        syncedQualityTaskKey = null;
      });
    });
  }

  Future<void> deleteTask(MediaTask task) async {
    await runWorkbenchActionOnce('delete-task:${task.id}', () async {
      await ref.read(mediaTaskListProvider.notifier).deleteTaskById(task.id);
      if (selectedTaskId == task.id) {
        setState(() {
          selectedTaskId = null;
          syncedConfigTaskId = null;
          syncedQualityTaskKey = null;
        });
      }
      if (selectedTaskIds.contains(task.id)) {
        setState(() {
          selectedTaskIds.remove(task.id);
          if (selectedTaskIds.isEmpty) {
            taskSelectionMode = false;
          }
        });
      }
    });
  }

  Future<void> relinkMissingSource(MediaTask task) async {
    await runWorkbenchActionOnce('relink-missing-source:${task.id}', () async {
      final newInputPath =
          (await ref.read(fileSelectionServiceProvider).pickMediaFile())
              ?.trim();
      if (newInputPath == null || newInputPath.isEmpty) {
        return;
      }

      try {
        await ref
            .read(mediaTaskListProvider.notifier)
            .replaceMissingSource(taskId: task.id, newInputPath: newInputPath);
        if (!mounted) {
          return;
        }

        setState(() {
          selectedTaskId = task.id;
          syncedConfigTaskId = null;
          syncedQualityTaskKey = null;
        });
        showWorkbenchSnackBar('源文件已重新链接');
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> showTaskContextMenu(
    MediaTask task,
    Offset globalPosition,
  ) async {
    await runWorkbenchActionOnce('show-task-context-menu', () async {
      final selectedAction = await showWorkbenchTaskContextMenu(
        context: context,
        task: task,
        globalPosition: globalPosition,
      );

      if (!mounted || selectedAction == null) {
        return;
      }

      switch (selectedAction) {
        case TaskContextMenuAction.revealInFileManager:
          await revealTaskInFileManager(task);
        case TaskContextMenuAction.relinkSource:
          await relinkMissingSource(task);
        case TaskContextMenuAction.rename:
          await renameTask(task);
        case TaskContextMenuAction.showLog:
          await showTaskLog(task);
        case TaskContextMenuAction.delete:
          await deleteTask(task);
      }
    });
  }

  Future<void> revealTaskInFileManager(MediaTask task) async {
    final targetPath = task.outputPath?.trim().isNotEmpty == true
        ? task.outputPath!.trim()
        : task.inputPath;
    final result = await ref.read(fileRevealerProvider).revealPath(targetPath);
    if (!result.succeeded) {
      showWorkbenchSnackBar(result.message!);
    }
  }

  Future<void> revealTaskOutput(MediaTask task) async {
    final outputPath = task.outputPath?.trim();
    if (outputPath == null || outputPath.isEmpty) {
      showWorkbenchSnackBar('任务还没有完成文件');
      return;
    }

    await revealPathInFileManager(outputPath);
  }

  Future<void> revealPathInFileManager(String targetPath) async {
    final result = await ref.read(fileRevealerProvider).revealPath(targetPath);
    if (!result.succeeded) {
      showWorkbenchSnackBar(result.message!);
    }
  }

  Future<void> renameTask(MediaTask task) async {
    await runWorkbenchActionOnce('rename-task:${task.id}', () async {
      final nextName = await showDialog<String>(
        context: context,
        builder: (context) => TaskRenameDialog(initialName: task.fileName),
      );

      if (!mounted || nextName == null) {
        return;
      }

      final trimmedName = nextName.trim();
      if (trimmedName.isEmpty) {
        showWorkbenchSnackBar('任务名称不能为空');
        return;
      }

      await ref
          .read(mediaTaskListProvider.notifier)
          .saveTask(task.copyWith(fileName: trimmedName));
    });
  }

  Future<void> showTaskLog(MediaTask task) async {
    await runWorkbenchActionOnce('show-task-log:${task.id}', () async {
      if (!mounted) {
        return;
      }

      await TaskLogDialog.show(
        context,
        task,
        logStore: ref.read(executionLogStoreProvider),
      );
    });
  }

  Future<void> retryTask(MediaTask task) async {
    await runWorkbenchActionOnce('retry-task:${task.id}', () async {
      try {
        await ref.read(mediaTaskListProvider.notifier).retryTaskById(task.id);
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> startOrResumeTask(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) async {
    await runWorkbenchActionOnce('start-or-resume-task:${task.id}', () {
      return startOrResumeTaskUnchecked(
        task,
        allowExtremeCompression: allowExtremeCompression,
      );
    });
  }

  Future<void> startOrResumeTaskUnchecked(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) async {
    try {
      final result = await ref
          .read(mediaTaskListProvider.notifier)
          .startOrResumeTaskById(
            task.id,
            allowExtremeCompression: allowExtremeCompression,
          );
      if (await confirmAndRestartWhenCompressionRequiresConfirmation(
        result,
        () => startOrResumeTaskUnchecked(task, allowExtremeCompression: true),
      )) {
        return;
      }
      if (result.message != null) {
        showWorkbenchSnackBar(result.message!);
      }
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  Future<void> pauseTask(MediaTask task) async {
    await runWorkbenchActionOnce('pause-task:${task.id}', () async {
      try {
        final result = await ref
            .read(mediaTaskListProvider.notifier)
            .pauseTaskById(task.id);
        if (result.message != null) {
          showWorkbenchSnackBar(result.message!);
        }
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> startExecutionQueue({
    bool allowExtremeCompression = false,
  }) async {
    try {
      final result = await ref
          .read(mediaTaskListProvider.notifier)
          .startExecutionQueue(
            allowExtremeCompression: allowExtremeCompression,
          );
      if (await confirmAndRestartWhenCompressionRequiresConfirmation(
        result,
        () => startExecutionQueue(allowExtremeCompression: true),
      )) {
        return;
      }
      if (result.message != null) {
        showWorkbenchSnackBar(result.message!);
      }
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  Future<bool> confirmAndRestartWhenCompressionRequiresConfirmation(
    FfmpegQueueStartResult result,
    Future<void> Function() restart,
  ) async {
    if (result.outcome !=
        FfmpegQueueStartOutcome.compressionConfirmationRequired) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    final confirmed = await showCompressionConfirmationDialog(
      result.message ?? '该视频已经压缩过，再压缩体积可能变大',
    );
    if (!mounted) {
      return true;
    }

    if (confirmed) {
      await restart();
      return true;
    }

    showWorkbenchSnackBar('已取消本次压缩');
    return true;
  }

  Future<bool> showCompressionConfirmationDialog(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CompressionConfirmationDialog(message: message),
    );

    return confirmed == true;
  }

  MediaTask? currentSelectedTask() {
    final taskList = ref.read(mediaTaskListProvider);
    if (!taskList.hasValue) {
      return null;
    }

    return resolveSelectedTask(taskList.requireValue);
  }

  TaskFolder? resolveOpenedTaskFolder(List<TaskFolder> folders) {
    final folderId = openedTaskFolderId;
    if (folderId == null) {
      return null;
    }

    for (final folder in folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    return null;
  }

  void openTaskFolder(TaskFolder folder) {
    setState(() {
      openedTaskFolderId = folder.id;
    });
  }

  void closeTaskFolder() {
    setState(() {
      openedTaskFolderId = null;
    });
  }

  Future<void> reorderOpenedTaskFolderTasks(int oldIndex, int newIndex) async {
    final folderId = openedTaskFolderId;
    if (folderId == null) {
      return;
    }
    try {
      await ref
          .read(mediaTaskListProvider.notifier)
          .reorderFolderTasks(
            folderId: folderId,
            oldIndex: oldIndex,
            newIndex: newIndex,
          );
    } on Object catch (error, stackTrace) {
      if (mounted) {
        showWorkbenchSnackBar('任务夹排序保存失败: $error');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void deleteTaskFolder(TaskFolder folder) {
    unawaited(
      runWorkbenchActionOnce('delete-task-folder:${folder.id}', () async {
        try {
          await ref
              .read(mediaTaskListProvider.notifier)
              .deleteTaskFolder(folder.id);
          if (openedTaskFolderId == folder.id) {
            closeTaskFolder();
          }
        } on Object catch (error) {
          showWorkbenchSnackBar(error.toString());
        }
      }),
    );
  }

  Future<void> startTaskFolder(
    TaskFolder folder, {
    bool allowExtremeCompression = false,
  }) async {
    await runWorkbenchActionOnce('start-task-folder:${folder.id}', () {
      return startTaskFolderUnchecked(
        folder,
        allowExtremeCompression: allowExtremeCompression,
      );
    });
  }

  Future<void> startTaskFolderUnchecked(
    TaskFolder folder, {
    bool allowExtremeCompression = false,
  }) async {
    try {
      final result = await ref
          .read(mediaTaskListProvider.notifier)
          .startNextTaskInFolder(
            folder.id,
            allowExtremeCompression: allowExtremeCompression,
          );
      if (await confirmAndRestartWhenCompressionRequiresConfirmation(
        result,
        () => startTaskFolderUnchecked(folder, allowExtremeCompression: true),
      )) {
        return;
      }
      if (result.message != null) {
        showWorkbenchSnackBar(result.message!);
      }
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  Future<void> pauseTaskFolder(TaskFolder folder) async {
    await runWorkbenchActionOnce('pause-task-folder:${folder.id}', () async {
      try {
        final result = await ref
            .read(mediaTaskListProvider.notifier)
            .pauseRunningTaskInFolder(folder.id);
        if (result.message != null) {
          showWorkbenchSnackBar(result.message!);
        }
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> retryTaskFolder(TaskFolder folder) async {
    await runWorkbenchActionOnce('retry-task-folder:${folder.id}', () async {
      try {
        await ref
            .read(mediaTaskListProvider.notifier)
            .retryTerminalTasksInFolder(folder.id);
        showWorkbenchSnackBar('任务夹终态任务已重置');
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    });
  }

  Future<void> relinkTaskFolderMissingSource(TaskFolder folder) async {
    await runWorkbenchActionOnce('relink-task-folder:${folder.id}', () async {
      final task = firstTaskInFolderWhere(
        folder: folder,
        predicate: (task) => task.status == TaskStatus.missingSource,
      );
      if (task == null) {
        showWorkbenchSnackBar('任务夹内没有缺失源文件任务');
        return;
      }
      await relinkMissingSource(task);
    });
  }

  Future<void> showTaskFolderLog(TaskFolder folder) async {
    await runWorkbenchActionOnce('show-task-folder-log:${folder.id}', () async {
      final tasks = ref.read(mediaTaskListProvider).asData?.value ?? const [];
      final folderTasks = resolveOpenedTaskFolderTasks(
        tasks: tasks,
        openedFolder: folder,
      );
      if (folderTasks.isEmpty) {
        showWorkbenchSnackBar('任务夹内没有任务');
        return;
      }
      await TaskFolderLogDialog.show(
        context,
        title: '${folder.name} 日志',
        tasks: folderTasks,
        logStore: ref.read(executionLogStoreProvider),
      );
    });
  }

  MediaTask? firstTaskInFolderWhere({
    required TaskFolder folder,
    required bool Function(MediaTask task) predicate,
  }) {
    final tasks = ref.read(mediaTaskListProvider).asData?.value ?? const [];
    for (final task in resolveOpenedTaskFolderTasks(
      tasks: tasks,
      openedFolder: folder,
    )) {
      if (predicate(task)) {
        return task;
      }
    }
    return null;
  }

  Future<void> removeTaskFromFolder(MediaTask task) async {
    await runWorkbenchActionOnce(
      'remove-task-from-folder:${task.id}',
      () async {
        try {
          await ref
              .read(mediaTaskListProvider.notifier)
              .removeTaskFromFolder(task.id);
          if (!mounted) {
            return;
          }
          setState(() {
            selectedTaskIds.remove(task.id);
          });
        } on Object catch (error) {
          showWorkbenchSnackBar(error.toString());
          rethrow;
        }
      },
    );
  }

  Future<void> updateSelectedTaskConfig({
    MediaTaskConfig? config,
    OutputFormat? outputFormat,
    VideoCodec? videoCodec,
    EncoderBackend? encoderBackend,
    ResolutionPreset? resolutionPreset,
    String? outputDirectory,
    int? compressionCrf,
    CompressionMode? compressionMode,
    Object? smartPreset = _configValueNotProvided,
    Object? targetSizeBytes = _configValueNotProvided,
    Object? targetSizeRatio = _configValueNotProvided,
    String? outputFileName,
  }) async {
    final task = currentSelectedTask();
    if (task == null) {
      return;
    }

    final updatedTask = task.copyWith(
      config:
          config ??
          task.config.copyWith(
            outputFormat: outputFormat,
            videoCodec: videoCodec,
            encoderBackend: encoderBackend,
            resolutionPreset: resolutionPreset,
            outputDirectory: outputDirectory,
            compressionCrf: compressionCrf,
            compressionMode: compressionMode,
            smartPreset: smartPreset,
            targetSizeBytes: targetSizeBytes,
            targetSizeRatio: targetSizeRatio,
            outputFileName: outputFileName,
          ),
    );

    await ref.read(mediaTaskListProvider.notifier).saveTask(updatedTask);
  }

  void showWorkbenchSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }

    unawaited(
      ref
          .read(appNotificationManagerProvider)
          .notify(
            level: notificationLevelForWorkbenchMessage(message),
            title: message,
            source: 'workbench',
            action: action == null
                ? null
                : AppNotificationAction(
                    label: action.label,
                    onPressed: action.onPressed,
                  ),
          ),
    );
  }
}

AppNotificationLevel notificationLevelForWorkbenchMessage(String message) {
  if (message.contains('失败') ||
      message.contains('错误') ||
      message.contains('无法') ||
      message.contains('异常')) {
    return AppNotificationLevel.error;
  }
  if (message.contains('成功') || message.contains('已')) {
    return AppNotificationLevel.success;
  }
  return AppNotificationLevel.info;
}

bool _taskNeedsUpdateRestartWarning(MediaTask task) {
  return task.status == TaskStatus.running ||
      task.status == TaskStatus.paused ||
      task.status == TaskStatus.pending ||
      task.status == TaskStatus.analyzing;
}
