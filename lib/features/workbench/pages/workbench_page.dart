import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/clear_tasks_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/compression_confirmation_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/import_failure_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/restart_unelevated_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_completed_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_context_menu.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_log_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_rename_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_about_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/workbench_notice_controller.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_external_link_opener.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_file_picker.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_file_revealer.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_import_handler.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_task_thumbnail_store.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_windows_privilege.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/infrastructure/providers/execution_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/theme_prefs_cache.dart';

const Object _configValueNotProvided = Object();
const String _frameLeanGitHubUrl = 'https://github.com/zhouycheng/FrameLean';
const String _frameLeanGiteeUrl = 'https://gitee.com/zhouycheng/FrameLean';

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
  String? syncedConfigTaskId;
  String? syncedQualityTaskKey;
  bool workbenchImportDragging = false;
  bool queueActionInFlight = false;
  final WorkbenchTaskThumbnailStore thumbnailStore =
      WorkbenchTaskThumbnailStore();
  final WorkbenchNoticeController noticeController =
      WorkbenchNoticeController();
  final Set<String> notifiedAnalysisErrorKeys = {};
  final Set<String> notifiedCompletedTaskKeys = {};
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
    noticeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskList = ref.watch(mediaTaskListProvider);
    final tasks = taskList.hasValue
        ? taskList.requireValue
        : const <MediaTask>[];
    final selectedTask = resolveSelectedTask(tasks);
    syncTaskThumbnailsAfterBuild(tasks);

    final hasRunningTask = tasks.any(
      (task) => task.status == TaskStatus.running,
    );
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      body: WorkbenchShell(
        taskList: taskList,
        selectedTask: selectedTask,
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
        onContextMenu: (task, position) {
          unawaited(showTaskContextMenu(task, position));
        },
        onAddTask: pickAndAddTasks,
        onOpenSettings: () {
          unawaited(openSettingsPage());
        },
        themeMode: themeMode,
        onToggleThemeMode: () {
          unawaited(toggleThemeMode());
        },
        onOpenAbout: () {
          unawaited(showAboutDialog());
        },
        onClearTasks: confirmClearTasks,
        onPrimaryQueuePressed: () {
          unawaited(handlePrimaryQueueAction(hasRunningTask));
        },
      ),
    );
  }

  void handleTaskListChanged(
    AsyncValue<List<MediaTask>>? previous,
    AsyncValue<List<MediaTask>> next,
  ) {
    if (previous != null) {
      notifyAnalysisErrors(next.asData?.value);
      notifyCompletedTasks(previous.asData?.value, next.asData?.value);
    }

    final tasks = next.asData?.value ?? const <MediaTask>[];
    final selectedTask = resolveSelectedTask(tasks);
    syncSelectedTaskIdAfterBuild(selectedTask);
    syncSelectedTaskConfigAfterBuild(selectedTask);
    syncQualityPresetAfterBuild(selectedTask);
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
        selectedEncoderBackend = EncoderBackend.auto;
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

  void notifyCompletedTasks(
    List<MediaTask>? previousTasks,
    List<MediaTask>? nextTasks,
  ) {
    if (previousTasks == null || nextTasks == null) {
      return;
    }

    final previousStatusById = {
      for (final task in previousTasks) task.id: task.status,
    };

    for (final task in nextTasks) {
      if (task.status != TaskStatus.completed) {
        continue;
      }

      if (previousStatusById[task.id] == TaskStatus.completed) {
        continue;
      }

      final key = '${task.id}:${task.outputPath}:${task.completedAt}';
      if (!notifiedCompletedTaskKeys.add(key)) {
        continue;
      }

      unawaited(showTaskCompletedDialog(task));
    }
  }

  Future<void> showTaskCompletedDialog(MediaTask task) async {
    if (!mounted) {
      return;
    }

    final outputPath = task.outputPath?.trim();
    final outputFileSize = await readOutputFileSize(outputPath);
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return TaskCompletedDialog(
          outputPath: outputPath,
          sourceFileSize: task.sourceFileFingerprint?.fileSize,
          outputFileSize: outputFileSize,
          onClose: () => Navigator.of(context).pop(),
          onReveal: outputPath == null || outputPath.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop();
                  unawaited(revealPathInFileManager(outputPath));
                },
        );
      },
    );
  }

  Future<int?> readOutputFileSize(String? outputPath) async {
    if (outputPath == null || outputPath.isEmpty) {
      return null;
    }

    try {
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        return null;
      }

      return outputFile.length();
    } on Object {
      return null;
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

  void reorderTasks(int oldIndex, int newIndex) {
    final reorderFuture = ref
        .read(mediaTaskListProvider.notifier)
        .reorderTasks(oldIndex: oldIndex, newIndex: newIndex);
    unawaited(
      reorderFuture.catchError((Object error, StackTrace stackTrace) {
        if (mounted) {
          showWorkbenchSnackBar('任务排序保存失败: $error');
        }
      }),
    );
  }

  Future<void> openSettingsPage() async {
    final saved = await context.push<bool>('/settings');
    if (!mounted) {
      return;
    }

    setState(() {
      workbenchImportDragging = false;
    });
    if (saved == true) {
      showWorkbenchSnackBar('设置已保存');
    }
  }

  Future<void> toggleThemeMode() async {
    if (themeModeChangeInFlight) {
      return;
    }

    themeModeChangeInFlight = true;
    final oldMode = ref.read(appThemeModeProvider);
    final nextMode = oldMode.toggled;
    ref.read(appThemeModeProvider.notifier).setThemeMode(nextMode);

    try {
      final repository = ref.read(appSettingsRepositoryProvider);
      final settings = await LoadAppSettingsUseCase(
        repository: repository,
      ).call();
      await repository.saveSettings(settings.copyWith(themeMode: nextMode));
      unawaited(ThemePrefsCache.write(nextMode));
    } on Object catch (error) {
      ref.read(appThemeModeProvider.notifier).setThemeMode(oldMode);
      showWorkbenchSnackBar('主题切换失败: $error');
    } finally {
      themeModeChangeInFlight = false;
    }
  }

  Future<void> showAboutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return WorkbenchAboutDialog(
          onClose: () => Navigator.of(dialogContext).pop(),
          onOpenGitHub: () {
            unawaited(openGitHubProject());
          },
          onOpenGitee: () {
            unawaited(openGiteeProject());
          },
        );
      },
    );
  }

  Future<void> openGitHubProject() async {
    await openExternalLink(_frameLeanGitHubUrl);
  }

  Future<void> openGiteeProject() async {
    await openExternalLink(_frameLeanGiteeUrl);
  }

  Future<void> openExternalLink(String url) async {
    final result = await WorkbenchExternalLinkOpener.open(url);
    if (!result.succeeded) {
      showWorkbenchSnackBar(result.message!);
    }
  }

  Future<void> showTaskConfigurationDialog(MediaTask task) async {
    final isVideoTask = task.mediaKind == MediaKind.video;
    final initialQualityIndex = isVideoTask
        ? WorkbenchQualityPolicy.initialQualityIndexForTask(task)
        : selectedQualityIndex;
    final initialSmartPreset = isVideoTask
        ? task.config.smartPreset ??
              WorkbenchQualityPolicy.smartPresetForQualityIndex(
                task.config.compressionCrf,
              )
        : selectedSmartPreset;
    final initialOutputFormat = isVideoTask
        ? task.config.outputFormat
        : selectedOutputFormat;
    final initialVideoCodec = isVideoTask
        ? task.config.videoCodec
        : selectedVideoCodec;
    final initialResolutionPreset = isVideoTask
        ? task.config.resolutionPreset
        : selectedResolutionPreset;
    final initialCompressionMode = task.config.compressionMode;

    setState(() {
      selectedTaskId = task.id;
      selectedOutputFormat = initialOutputFormat;
      selectedVideoCodec = initialVideoCodec;
      selectedEncoderBackend = EncoderBackend.auto;
      selectedResolutionPreset = initialResolutionPreset;
      selectedCompressionMode = initialCompressionMode;
      selectedSmartPreset = initialSmartPreset;
      selectedQualityIndex = initialQualityIndex;
      syncedConfigTaskId = task.id;
      syncedQualityTaskKey = '${task.id}:${task.analysisUpdatedAt}';
    });

    final draft = await showWorkbenchTaskConfigurationEditor(
      context: context,
      task: task,
      thumbnail: thumbnailForTask(task),
      selectedQualityIndex: initialQualityIndex,
      selectedOutputFormat: initialOutputFormat,
      selectedVideoCodec: initialVideoCodec,
      selectedEncoderBackend: EncoderBackend.auto,
      selectedResolutionPreset: initialResolutionPreset,
      selectedCompressionMode: initialCompressionMode,
      selectedSmartPreset: initialSmartPreset,
      selectedTargetSizeRatio: isVideoTask
          ? WorkbenchQualityPolicy.initialTargetSizeRatioForTask(task)
          : WorkbenchConstants.defaultTargetSizeRatio,
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

    final isTargetSize = draft.compressionMode == CompressionMode.targetSize;
    final targetSizeRatio = WorkbenchQualityPolicy.normalizeTargetSizeRatio(
      draft.targetSizeRatio,
    );
    final resolvedQualityIndex = isTargetSize
        ? WorkbenchQualityPolicy.qualityIndexForTargetSizeRatio(targetSizeRatio)
        : draft.qualityIndex;
    final qualityOption =
        WorkbenchConstants.qualityOptions[resolvedQualityIndex];
    final targetSizeBytes =
        WorkbenchQualityPolicy.targetSizeBytesForTargetRatio(
          task,
          targetSizeRatio,
        );

    try {
      await updateSelectedTaskConfig(
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

      if (!mounted) {
        return;
      }

      setState(() {
        selectedQualityIndex = resolvedQualityIndex;
        selectedOutputFormat = draft.outputFormat;
        selectedVideoCodec = draft.videoCodec;
        selectedEncoderBackend = draft.encoderBackend;
        selectedResolutionPreset = draft.resolutionPreset;
        selectedCompressionMode = isTargetSize
            ? CompressionMode.targetSize
            : CompressionMode.preset;
        selectedSmartPreset = draft.smartPreset;
      });
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  void openTask(MediaTask task) {
    if (task.status == TaskStatus.missingSource) {
      unawaited(relinkMissingSource(task));
      return;
    }

    unawaited(showTaskConfigurationDialog(task));
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
    try {
      final files = await WorkbenchFilePicker.pickMediaFiles();
      final paths = files
          .map((file) => file.path)
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
          syncedConfigTaskId = null;
          syncedQualityTaskKey = null;
        });
      }
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
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
      syncedConfigTaskId = null;
      syncedQualityTaskKey = null;
    });
  }

  Future<void> deleteTask(MediaTask task) async {
    await ref.read(mediaTaskListProvider.notifier).deleteTaskById(task.id);
    if (selectedTaskId == task.id) {
      setState(() {
        selectedTaskId = null;
        syncedConfigTaskId = null;
        syncedQualityTaskKey = null;
      });
    }
  }

  Future<void> relinkMissingSource(MediaTask task) async {
    final file = await WorkbenchFilePicker.pickMediaFile();
    final newInputPath = file?.path.trim();
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
  }

  Future<void> showTaskContextMenu(
    MediaTask task,
    Offset globalPosition,
  ) async {
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
  }

  Future<void> revealTaskInFileManager(MediaTask task) async {
    final result = await WorkbenchFileRevealer.revealTask(task);
    if (!result.succeeded) {
      showWorkbenchSnackBar(result.message!);
    }
  }

  Future<void> revealPathInFileManager(String targetPath) async {
    final result = await WorkbenchFileRevealer.revealPath(targetPath);
    if (!result.succeeded) {
      showWorkbenchSnackBar(result.message!);
    }
  }

  Future<void> renameTask(MediaTask task) async {
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
  }

  Future<void> showTaskLog(MediaTask task) async {
    if (!mounted) {
      return;
    }

    await TaskLogDialog.show(
      context,
      task,
      logStore: ref.read(executionLogStoreProvider),
    );
  }

  Future<void> retryTask(MediaTask task) async {
    try {
      await ref.read(mediaTaskListProvider.notifier).retryTaskById(task.id);
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  Future<void> startOrResumeTask(
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
        () => startOrResumeTask(task, allowExtremeCompression: true),
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

    noticeController.show(context, message, action: action);
  }
}
