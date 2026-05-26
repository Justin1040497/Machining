import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/app_settings_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/clear_tasks_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/compression_confirmation_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/import_failure_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_completed_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_context_menu.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_rename_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/workbench_notice_controller.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_file_picker.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_file_revealer.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_import_handler.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_task_thumbnail_store.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:path/path.dart' as path;

const Object _configValueNotProvided = Object();

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
  bool appSettingsDialogOpen = false;
  bool queueActionInFlight = false;
  final WorkbenchTaskThumbnailStore thumbnailStore =
      WorkbenchTaskThumbnailStore();
  final WorkbenchNoticeController noticeController =
      WorkbenchNoticeController();
  final Set<String> notifiedAnalysisErrorKeys = {};
  final Set<String> notifiedCompletedTaskKeys = {};

  @override
  void dispose() {
    noticeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<MediaTask>>>(mediaTaskListProvider, (
      previous,
      next,
    ) {
      notifyAnalysisErrors(next.asData?.value);
      notifyCompletedTasks(previous?.asData?.value, next.asData?.value);
    });
    final taskList = ref.watch(mediaTaskListProvider);
    final tasks = taskList.hasValue
        ? taskList.requireValue
        : const <MediaTask>[];
    final selectedTask = resolveSelectedTask(tasks);
    syncSelectedTaskIdAfterBuild(selectedTask);
    syncSelectedTaskConfigAfterBuild(selectedTask);
    syncQualityPresetAfterBuild(selectedTask);
    syncTaskThumbnailsAfterBuild(tasks);

    final hasRunningTask = tasks.any(
      (task) => task.status == TaskStatus.running,
    );

    return Scaffold(
      body: WorkbenchShell(
        taskList: taskList,
        selectedTask: selectedTask,
        importEnabled: !appSettingsDialogOpen,
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
        onReorder: (oldIndex, newIndex) {
          ref
              .read(mediaTaskListProvider.notifier)
              .reorderTasks(oldIndex: oldIndex, newIndex: newIndex);
        },
        onOpenTask: openTask,
        onStart: startOrResumeTask,
        onPause: pauseTask,
        onRemove: deleteTask,
        onRetry: retryTask,
        onRelink: relinkMissingSource,
        onContextMenu: (task, position) {
          unawaited(showTaskContextMenu(task, position));
        },
        onAddTask: pickAndAddTasks,
        onOpenSettings: () {
          unawaited(showAppSettingsDialog());
        },
        onClearTasks: confirmClearTasks,
        onPrimaryQueuePressed: () {
          unawaited(handlePrimaryQueueAction(hasRunningTask));
        },
      ),
    );
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

    final syncKey = '$taskId:${selectedTask!.analysisUpdatedAt}';
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return TaskCompletedDialog(
          fileName: outputPath == null || outputPath.isEmpty
              ? task.fileName
              : path.basename(outputPath),
          outputPath: outputPath,
          onClose: () => Navigator.of(context).pop(),
          onReveal: outputPath == null || outputPath.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop();
                  unawaited(revealPathInFileManager(outputPath));
                },
          onRestart: () {
            Navigator.of(context).pop();
            unawaited(retryTask(task));
          },
        );
      },
    );
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
    final taskList = ref.read(mediaTaskListProvider);
    if (!taskList.hasValue) {
      return;
    }

    for (final task in taskList.requireValue) {
      if (task.status == TaskStatus.running) {
        await pauseTask(task);
      }
    }
  }

  Future<void> showAppSettingsDialog() async {
    try {
      final settings = await LoadAppSettingsUseCase(
        repository: ref.read(appSettingsRepositoryProvider),
      ).call();
      if (!mounted) {
        return;
      }

      setState(() {
        appSettingsDialogOpen = true;
        workbenchImportDragging = false;
      });

      try {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return WorkbenchAppSettingsDialog(
              initialSettings: settings,
              fallbackDefaultDirectory: WorkbenchFilePicker.defaultExportPath,
              onClose: () => Navigator.of(dialogContext).pop(),
              onPickOutputDirectory: WorkbenchFilePicker.pickOutputDirectory,
              onPickFfmpegPath: WorkbenchFilePicker.pickExecutablePath,
              onPickFfprobePath: WorkbenchFilePicker.pickExecutablePath,
              onSave: (updatedSettings) async {
                try {
                  await saveAppSettings(updatedSettings);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  showWorkbenchSnackBar('设置已保存');
                } on Object catch (error) {
                  showWorkbenchSnackBar(error.toString());
                }
              },
            );
          },
        );
      } finally {
        if (mounted) {
          setState(() {
            appSettingsDialogOpen = false;
            workbenchImportDragging = false;
          });
        }
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      showWorkbenchSnackBar('设置打开失败: $error');
    }
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    await SaveAppSettingsUseCase(
      repository: ref.read(appSettingsRepositoryProvider),
      ffmpegLocator: ref.read(ffmpegLocatorProvider),
    ).call(settings);
    ref.invalidate(ffmpegRuntimeProvider);
  }

  Future<void> showTaskConfigurationDialog(MediaTask task) async {
    final initialQualityIndex =
        WorkbenchQualityPolicy.initialQualityIndexForTask(task);
    final initialSmartPreset =
        task.config.smartPreset ??
        WorkbenchQualityPolicy.smartPresetForQualityIndex(
          task.config.compressionCrf,
        );

    setState(() {
      selectedTaskId = task.id;
      selectedOutputFormat = task.config.outputFormat;
      selectedVideoCodec = task.config.videoCodec;
      selectedEncoderBackend = EncoderBackend.auto;
      selectedResolutionPreset = task.config.resolutionPreset;
      selectedCompressionMode = task.config.compressionMode;
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
      selectedOutputFormat: task.config.outputFormat,
      selectedVideoCodec: task.config.videoCodec,
      selectedEncoderBackend: EncoderBackend.auto,
      selectedResolutionPreset: task.config.resolutionPreset,
      selectedCompressionMode: task.config.compressionMode,
      selectedSmartPreset: initialSmartPreset,
      selectedTargetSizeRatio:
          WorkbenchQualityPolicy.initialTargetSizeRatioForTask(task),
      onOpenSource: () {
        unawaited(revealPathInFileManager(task.inputPath));
      },
    );
    if (!mounted || draft == null) {
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
      final files = await WorkbenchFilePicker.pickVideoFiles();
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
    if (appSettingsDialogOpen) {
      return;
    }

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
    final file = await WorkbenchFilePicker.pickVideoFile();
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
      config: task.config.copyWith(
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
