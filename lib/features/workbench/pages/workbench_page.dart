import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:machining/application/services/ffmpeg_task_queue_runner.dart';
import 'package:machining/application/services/preview_frame_generator.dart';
import 'package:machining/application/services/video_thumbnail_generator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/bottom_bar.dart';
import 'package:machining/features/workbench/pages/workbench_page/constants.dart';
import 'package:machining/features/workbench/pages/workbench_page/drop_overlay.dart';
import 'package:machining/features/workbench/pages/workbench_page/file_info_panel.dart';
import 'package:machining/features/workbench/pages/workbench_page/formatters.dart';
import 'package:machining/features/workbench/pages/workbench_page/models.dart';
import 'package:machining/features/workbench/pages/workbench_page/task_configuration_dialog.dart';
import 'package:machining/features/workbench/pages/workbench_page/task_list_card.dart';
import 'package:machining/features/workbench/pages/workbench_page/top_bar.dart';
import 'package:machining/features/workbench/providers/media_task_notifier.dart';
import 'package:machining/infrastructure/providers/ffmpeg_provider.dart';
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
  ResolutionPreset selectedResolutionPreset = ResolutionPreset.p1080;
  CompressionMode selectedCompressionMode = CompressionMode.smart;
  SmartCompressionPreset selectedSmartPreset = SmartCompressionPreset.balanced;
  String? selectedTaskId;
  String? syncedConfigTaskId;
  String? syncedQualityTaskKey;
  bool saveToSourceDirectory = true;
  bool exportDirectoryDragging = false;
  bool workbenchImportDragging = false;
  bool queueActionInFlight = false;
  bool previewGenerating = false;
  double previewCompareRatio = 0.5;
  int selectedPreviewFrameIndex = 0;
  PreviewFrameResult? previewFrameResult;
  final Map<String, String> thumbnailPathByKey = {};
  final Set<String> thumbnailGenerationKeys = {};
  final Set<String> thumbnailFailureKeys = {};
  late final TextEditingController exportDirectoryController;
  late final TextEditingController outputFileNameController;
  final Set<String> notifiedAnalysisErrorKeys = {};
  final Set<String> notifiedCompletedTaskKeys = {};

  @override
  void initState() {
    super.initState();
    exportDirectoryController = TextEditingController(text: defaultExportPath);
    outputFileNameController = TextEditingController();
  }

  @override
  void dispose() {
    exportDirectoryController.dispose();
    outputFileNameController.dispose();
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

    return Scaffold(
      body: DropTarget(
        onDragEntered: (_) {
          if (!workbenchImportDragging) {
            setState(() {
              workbenchImportDragging = true;
            });
          }
        },
        onDragExited: (_) {
          if (workbenchImportDragging) {
            setState(() {
              workbenchImportDragging = false;
            });
          }
        },
        onDragDone: handleWorkbenchDrop,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
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
                final titleBarHeight = Platform.isMacOS
                    ? WorkbenchConstants.appTopBarHeight
                    : 0.0;

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
                        if (Platform.isMacOS)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: WorkbenchTopBar(),
                          ),
                        Positioned.fill(
                          top: titleBarHeight,
                          bottom: 48,
                          child: WorkbenchTaskListCard(
                            taskList: taskList,
                            selectedTask: selectedTask,
                            thumbnailForTask: thumbnailForTask,
                            onReorder: (oldIndex, newIndex) {
                              ref
                                  .read(mediaTaskListProvider.notifier)
                                  .reorderTasks(
                                    oldIndex: oldIndex,
                                    newIndex: newIndex,
                                  );
                            },
                            onOpenTask: (task) {
                              unawaited(showTaskConfigurationDialog(task));
                            },
                            onStart: startOrResumeTask,
                            onPause: pauseTask,
                            onRemove: deleteTask,
                            onRetry: retryTask,
                            onContextMenu: (task, position) {
                              unawaited(showTaskContextMenu(task, position));
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: WorkbenchBottomBar(
                            taskList: taskList,
                            hasRunningTask: hasRunningTask,
                            queueActionInFlight: queueActionInFlight,
                            onAddTask: pickAndAddTasks,
                            onOpenSettings: () {
                              showWorkbenchDialog(
                                title: '设置',
                                message: '设置窗口内容待接入',
                              );
                            },
                            onClearTasks: confirmClearTasks,
                            onPrimaryQueuePressed: () {
                              unawaited(
                                handlePrimaryQueueAction(hasRunningTask),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (workbenchImportDragging) const WorkbenchDropOverlay(),
          ],
        ),
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
        selectedEncoderBackend = config.encoderBackend;
        selectedResolutionPreset = config.resolutionPreset;
        selectedCompressionMode = config.compressionMode;
        selectedSmartPreset =
            config.smartPreset ??
            smartPresetForQualityIndex(config.compressionCrf);
        saveToSourceDirectory = config.outputDirectory.trim().isEmpty;
        exportDirectoryController.text = saveToSourceDirectory
            ? defaultExportPath
            : config.outputDirectory;
        outputFileNameController.text = config.outputFileName;
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

    final nextIndex = initialQualityIndexForTask(selectedTask);
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
    final message = outputPath == null || outputPath.isEmpty
        ? '任务已完成，但没有记录输出路径。'
        : '输出路径：\n$outputPath';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('压缩完成'),
          content: SelectableText(message),
          actions: [
            if (outputPath != null && outputPath.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(revealPathInFinder(outputPath));
                },
                child: const Text('在 Finder 中打开'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  ImageProvider? thumbnailForTask(MediaTask task) {
    final thumbnailPath = thumbnailPathByKey[thumbnailKeyForTask(task)];
    if (thumbnailPath == null || !File(thumbnailPath).existsSync()) {
      return null;
    }

    return FileImage(File(thumbnailPath));
  }

  void syncTaskThumbnailsAfterBuild(List<MediaTask> tasks) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final task in tasks) {
        unawaited(generateTaskThumbnail(task));
      }
    });
  }

  Future<void> generateTaskThumbnail(MediaTask task) async {
    final key = thumbnailKeyForTask(task);
    if (thumbnailPathByKey.containsKey(key) ||
        thumbnailGenerationKeys.contains(key) ||
        thumbnailFailureKeys.contains(key)) {
      return;
    }

    thumbnailGenerationKeys.add(key);
    try {
      final runtime = await ref.read(ffmpegRuntimeProvider.future);
      final ffmpeg = runtime.ffmpeg;
      if (ffmpeg == null) {
        return;
      }

      final directory = Directory(
        path.join(Directory.systemTemp.path, 'machining', 'thumbnails'),
      );
      await directory.create(recursive: true);

      final outputPath = path.join(
        directory.path,
        thumbnailFileNameForTask(task),
      );
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        await ref
            .read(videoThumbnailGeneratorProvider)
            .generate(
              VideoThumbnailRequest(
                ffmpegPath: ffmpeg.path,
                task: task,
                outputPath: outputPath,
              ),
            );
        if (!await outputFile.exists()) {
          thumbnailFailureKeys.add(key);
          return;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        thumbnailPathByKey[key] = outputPath;
      });
    } on Object {
      thumbnailFailureKeys.add(key);
    } finally {
      thumbnailGenerationKeys.remove(key);
    }
  }

  String thumbnailKeyForTask(MediaTask task) {
    final fingerprint = task.sourceFileFingerprint;
    return [
      task.id,
      task.inputPath,
      fingerprint?.fileSize ?? 0,
      fingerprint?.lastModifiedAt ?? 0,
    ].join('|');
  }

  String thumbnailFileNameForTask(MediaTask task) {
    final fingerprint = task.sourceFileFingerprint;
    final name = [
      task.id,
      fingerprint?.fileSize ?? 0,
      fingerprint?.lastModifiedAt ?? 0,
    ].join('_');
    return '$name.jpg';
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

  Future<void> showTaskConfigurationDialog(MediaTask task) async {
    setState(() {
      selectedTaskId = task.id;
      selectedOutputFormat = task.config.outputFormat;
      selectedVideoCodec = task.config.videoCodec;
      selectedEncoderBackend = task.config.encoderBackend;
      selectedResolutionPreset = task.config.resolutionPreset;
      selectedCompressionMode = task.config.compressionMode;
      selectedSmartPreset =
          task.config.smartPreset ??
          smartPresetForQualityIndex(task.config.compressionCrf);
      saveToSourceDirectory = task.config.outputDirectory.trim().isEmpty;
      exportDirectoryDragging = false;
      exportDirectoryController.text = saveToSourceDirectory
          ? defaultExportPath
          : task.config.outputDirectory;
      outputFileNameController.text = task.config.outputFileName;
      selectedQualityIndex = initialQualityIndexForTask(task);
      syncedConfigTaskId = task.id;
      syncedQualityTaskKey = '${task.id}:${task.analysisUpdatedAt}';
      previewFrameResult = null;
      selectedPreviewFrameIndex = 0;
    });

    var draftQualityIndex = selectedQualityIndex;
    var draftOutputFormat = selectedOutputFormat;
    var draftVideoCodec = selectedVideoCodec;
    var draftEncoderBackend = selectedEncoderBackend;
    var draftResolutionPreset = selectedResolutionPreset;
    var draftCompressionMode = selectedCompressionMode;
    var draftSmartPreset = selectedSmartPreset;
    var draftTargetSizeBytes =
        task.config.targetSizeBytes ??
        targetSizeBytesForQualityOption(
          task,
          WorkbenchConstants.qualityOptions[draftQualityIndex],
        );

    Future<void> saveDraftAndClose(BuildContext dialogContext) async {
      final qualityOption =
          WorkbenchConstants.qualityOptions[draftQualityIndex];
      final isTargetSize = draftCompressionMode == CompressionMode.targetSize;
      if (isTargetSize &&
          (draftTargetSizeBytes == null || draftTargetSizeBytes! <= 0)) {
        showWorkbenchSnackBar('请输入有效目标大小');
        return;
      }

      final targetSizeRatio = targetSizeRatioForBytes(
        task: task,
        targetSizeBytes: draftTargetSizeBytes,
        fallbackRatio: qualityOption.targetRatio,
      );
      try {
        await updateSelectedTaskConfig(
          outputFormat: draftOutputFormat,
          videoCodec: draftVideoCodec,
          encoderBackend: draftEncoderBackend,
          resolutionPreset: draftResolutionPreset,
          compressionCrf: qualityOption.crf,
          compressionMode: isTargetSize
              ? CompressionMode.targetSize
              : CompressionMode.smart,
          smartPreset: isTargetSize ? null : draftSmartPreset,
          targetSizeBytes: isTargetSize ? draftTargetSizeBytes : null,
          targetSizeRatio: isTargetSize ? targetSizeRatio : null,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          selectedQualityIndex = draftQualityIndex;
          selectedOutputFormat = draftOutputFormat;
          selectedVideoCodec = draftVideoCodec;
          selectedEncoderBackend = draftEncoderBackend;
          selectedResolutionPreset = draftResolutionPreset;
          selectedCompressionMode = isTargetSize
              ? CompressionMode.targetSize
              : CompressionMode.smart;
          selectedSmartPreset = draftSmartPreset;
        });

        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
      } on Object catch (error) {
        showWorkbenchSnackBar(error.toString());
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, refreshDialog) {
            void updateDialogState(VoidCallback action) {
              refreshDialog(action);
            }

            return WorkbenchTaskConfigurationDialog(
              task: task,
              thumbnail: thumbnailForTask(task),
              selectedQualityIndex: draftQualityIndex,
              selectedOutputFormat: draftOutputFormat,
              selectedVideoCodec: draftVideoCodec,
              selectedEncoderBackend: draftEncoderBackend,
              selectedResolutionPreset: draftResolutionPreset,
              selectedCompressionMode: draftCompressionMode,
              selectedSmartPreset: draftSmartPreset,
              selectedTargetSizeBytes: draftTargetSizeBytes,
              availableEncoderBackends: availableEncoderBackends(
                videoCodec: draftVideoCodec,
                selectedBackend: draftEncoderBackend,
              ),
              onClose: () => Navigator.of(dialogContext).pop(),
              onOpenSource: () {
                unawaited(revealPathInFinder(task.inputPath));
              },
              onSave: () {
                unawaited(saveDraftAndClose(dialogContext));
              },
              onCompressionModeChanged: (value) {
                updateDialogState(() {
                  draftCompressionMode = value == CompressionMode.targetSize
                      ? CompressionMode.targetSize
                      : CompressionMode.smart;
                  draftTargetSizeBytes ??= targetSizeBytesForQualityOption(
                    task,
                    WorkbenchConstants.qualityOptions[draftQualityIndex],
                  );
                });
              },
              onSmartPresetChanged: (value) {
                updateDialogState(() {
                  draftSmartPreset = value;
                });
              },
              onTargetSizeBytesChanged: (value) {
                updateDialogState(() {
                  draftTargetSizeBytes = value;
                });
              },
              onQualityChanged: (index) {
                if (index == draftQualityIndex) {
                  return;
                }
                updateDialogState(() {
                  draftQualityIndex = index;
                });
              },
              onOutputFormatChanged: (value) {
                updateDialogState(() {
                  draftOutputFormat = value;
                });
              },
              onVideoCodecChanged: (value) {
                final nextEncoderBackend =
                    isBackendCompatibleWithCodec(draftEncoderBackend, value)
                    ? draftEncoderBackend
                    : EncoderBackend.auto;
                updateDialogState(() {
                  draftVideoCodec = value;
                  draftEncoderBackend = nextEncoderBackend;
                });
              },
              onEncoderBackendChanged: (value) {
                updateDialogState(() {
                  draftEncoderBackend = value;
                });
              },
              onResolutionPresetChanged: (value) {
                updateDialogState(() {
                  draftResolutionPreset = value;
                });
              },
            );
          },
        );
      },
    );
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
      final files = await openVideoFiles();
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
          previewFrameResult = null;
          selectedPreviewFrameIndex = 0;
        });
      }
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    }
  }

  Future<void> handleWorkbenchDrop(DropDoneDetails details) async {
    if (mounted) {
      setState(() {
        workbenchImportDragging = false;
      });
    }

    if (details.files.isEmpty) {
      return;
    }

    final createdTasks = <MediaTask>[];
    final failures = <DroppedImportFailure>[];
    final notifier = ref.read(mediaTaskListProvider.notifier);

    for (final item in details.files) {
      final inputPath = item.path.trim();
      if (inputPath.isEmpty) {
        failures.add(
          const DroppedImportFailure(path: '未知文件', reason: '文件路径为空'),
        );
        continue;
      }

      final entityType = FileSystemEntity.typeSync(inputPath);
      if (entityType != FileSystemEntityType.file) {
        failures.add(
          DroppedImportFailure(path: inputPath, reason: '只能导入视频文件，不能导入文件夹'),
        );
        continue;
      }

      try {
        final task = await notifier.createDraftFromPath(inputPath);
        createdTasks.add(task);
      } on Object catch (error) {
        failures.add(
          DroppedImportFailure(
            path: inputPath,
            reason: formatImportFailureReason(error),
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    if (createdTasks.isNotEmpty) {
      setState(() {
        selectedTaskId = createdTasks.first.id;
        syncedConfigTaskId = null;
        syncedQualityTaskKey = null;
        previewFrameResult = null;
        selectedPreviewFrameIndex = 0;
      });
    }

    showDroppedImportSnackBar(
      successCount: createdTasks.length,
      failures: failures,
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

    final logText = failures
        .map((failure) {
          final fileName = path.basename(failure.path);
          return '$fileName\n${failure.path}\n原因：${failure.reason}';
        })
        .join('\n\n');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入失败日志'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 360),
            child: SingleChildScrollView(child: SelectableText(logText)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  String formatImportFailureReason(Object error) {
    const stateErrorPrefix = 'Bad state: ';
    final message = error.toString();
    if (message.startsWith(stateErrorPrefix)) {
      return message.substring(stateErrorPrefix.length);
    }

    return message;
  }

  Future<List<XFile>> openVideoFiles() async {
    try {
      return await openFiles(
        acceptedTypeGroups: [WorkbenchConstants.videoTypeGroup],
      );
    } on ArgumentError {
      return openFiles();
    } on UnimplementedError {
      return openFiles();
    }
  }

  Future<void> confirmClearTasks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空列表'),
          content: const Text('确定要清空列表吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(mediaTaskListProvider.notifier).clearTasks();
    setState(() {
      selectedTaskId = null;
      syncedConfigTaskId = null;
      syncedQualityTaskKey = null;
      previewFrameResult = null;
      selectedPreviewFrameIndex = 0;
    });
  }

  Future<void> deleteTask(MediaTask task) async {
    await ref.read(mediaTaskListProvider.notifier).deleteTaskById(task.id);
    if (selectedTaskId == task.id) {
      setState(() {
        selectedTaskId = null;
        syncedConfigTaskId = null;
        syncedQualityTaskKey = null;
        previewFrameResult = null;
        selectedPreviewFrameIndex = 0;
      });
    }
  }

  Future<void> showTaskContextMenu(
    MediaTask task,
    Offset globalPosition,
  ) async {
    final selectedAction = await showMenu<TaskContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(
          value: TaskContextMenuAction.revealInFinder,
          child: Text('在 Finder 中打开'),
        ),
        PopupMenuItem(
          value: TaskContextMenuAction.rename,
          child: Text('任务重命名'),
        ),
        PopupMenuItem(value: TaskContextMenuAction.delete, child: Text('删除任务')),
      ],
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case TaskContextMenuAction.revealInFinder:
        await revealTaskInFinder(task);
      case TaskContextMenuAction.rename:
        await renameTask(task);
      case TaskContextMenuAction.delete:
        await deleteTask(task);
    }
  }

  Future<void> revealTaskInFinder(MediaTask task) async {
    final targetPath = task.outputPath?.trim().isNotEmpty == true
        ? task.outputPath!.trim()
        : task.inputPath;
    await revealPathInFinder(targetPath);
  }

  Future<void> revealPathInFinder(String targetPath) async {
    if (!Platform.isMacOS) {
      showWorkbenchSnackBar('当前系统暂不支持 Finder');
      return;
    }

    try {
      final result = await Process.run('open', ['-R', targetPath]);
      if (result.exitCode != 0) {
        showWorkbenchSnackBar('打开 Finder 失败: ${result.stderr}');
      }
    } on Object catch (error) {
      showWorkbenchSnackBar('打开 Finder 失败: $error');
    }
  }

  Future<void> renameTask(MediaTask task) async {
    final controller = TextEditingController(text: task.fileName);
    try {
      final nextName = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('任务重命名'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: '任务名称',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('保存'),
              ),
            ],
          );
        },
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
    } finally {
      controller.dispose();
    }
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
      builder: (context) {
        return AlertDialog(
          title: const Text('确认继续压缩'),
          content: Text('$message\n\n继续后会使用更激进的压缩策略。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续压缩'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> resetSelectedTaskConfiguration() async {
    final task = currentSelectedTask();
    if (task == null) {
      showWorkbenchSnackBar('请先选择一个任务');
      return;
    }

    final nextQualityIndex = initialQualityIndexForTask(task);
    final initialConfig = task.config.copyWith(
      outputFormat: WorkbenchFormatters.inferInitialOutputFormat(task),
      videoCodec: WorkbenchFormatters.inferInitialVideoCodec(task),
      resolutionPreset: ResolutionPreset.original,
      outputDirectory: '',
      compressionCrf: WorkbenchConstants.qualityOptions[nextQualityIndex].crf,
      compressionMode: CompressionMode.smart,
      smartPreset: smartPresetForQualityIndex(nextQualityIndex),
      targetSizeBytes: null,
      targetSizeRatio: null,
      outputFileName: '',
    );

    setState(() {
      selectedQualityIndex = nextQualityIndex;
      selectedOutputFormat = initialConfig.outputFormat;
      selectedVideoCodec = initialConfig.videoCodec;
      selectedEncoderBackend = initialConfig.encoderBackend;
      selectedResolutionPreset = initialConfig.resolutionPreset;
      selectedCompressionMode = initialConfig.compressionMode;
      selectedSmartPreset =
          initialConfig.smartPreset ?? SmartCompressionPreset.balanced;
      saveToSourceDirectory = true;
      exportDirectoryDragging = false;
      exportDirectoryController.text = defaultExportPath;
      outputFileNameController.clear();
      syncedConfigTaskId = task.id;
      syncedQualityTaskKey = '${task.id}:${task.analysisUpdatedAt}';
      previewFrameResult = null;
      selectedPreviewFrameIndex = 0;
    });

    final updatedTask = task.copyWith(config: initialConfig);
    await ref.read(mediaTaskListProvider.notifier).saveTask(updatedTask);
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
    setState(() {
      previewFrameResult = null;
      selectedPreviewFrameIndex = 0;
    });
  }

  void showWorkbenchSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  Future<void> showWorkbenchDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> generatePreviewFrames() async {
    final task = currentSelectedTask();
    if (task == null) {
      showWorkbenchSnackBar('请先选择一个任务');
      return;
    }

    if (task.analysisResult?.durationMs == null) {
      showWorkbenchSnackBar('媒体分析完成后才能生成预览');
      return;
    }

    final runtime = await ref.read(ffmpegRuntimeProvider.future);
    if (runtime.ffmpeg == null) {
      showWorkbenchSnackBar('FFmpeg 不可用，无法生成预览');
      return;
    }

    setState(() {
      previewGenerating = true;
    });

    try {
      final result = await ref
          .read(previewFrameGeneratorProvider)
          .generate(
            PreviewFrameRequest(
              ffmpegPath: runtime.ffmpeg!.path,
              task: task,
              allowExtremeCompression:
                  isSourceAlreadyCompressed(task) &&
                  selectedQualityOption.isLowestVolume,
              encoderCapabilities: runtime.encoderCapabilities,
            ),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        previewFrameResult = result;
        selectedPreviewFrameIndex = 0;
        previewCompareRatio = 0.5;
      });
    } on Object catch (error) {
      showWorkbenchSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          previewGenerating = false;
        });
      }
    }
  }

  WorkbenchFileInfoData buildFileInfoData(MediaTask task) {
    final analysis = task.analysisResult;
    final recommendation = ref
        .read(compressionAdvisorProvider)
        .recommend(
          task,
          allowExtremeCompression:
              isSourceAlreadyCompressed(task) &&
              selectedQualityOption.isLowestVolume,
        );
    final targetResolution =
        selectedResolutionPreset == ResolutionPreset.original
        ? WorkbenchFormatters.formatResolution(analysis)
        : selectedResolutionPreset.label;
    final targetDuration = WorkbenchFormatters.formatDuration(
      analysis?.durationMs,
    );
    final targetBitrate =
        recommendation.targetTotalBitrate ??
        calculateQualityTargetBitrate(task, analysis?.preferredBitrate);

    return WorkbenchFileInfoData(
      sourceRows: [
        '编码: ${WorkbenchFormatters.formatCodec(analysis?.videoCodec)}',
        '视频大小: ${WorkbenchFormatters.formatBytes(task.sourceFileFingerprint?.fileSize)}',
        '码率: ${WorkbenchFormatters.formatBitrate(analysis?.preferredBitrate)}',
        '分辨率: ${WorkbenchFormatters.formatResolution(analysis)}',
        '视频格式: ${WorkbenchFormatters.formatContainer(analysis?.containerFormat)}',
        '视频时长: ${WorkbenchFormatters.formatDuration(analysis?.durationMs)}',
        if (task.analysisErrorMessage != null)
          '分析提示: ${task.analysisErrorMessage}',
      ],
      outputRows: [
        '编码: ${WorkbenchFormatters.formatTargetCodec(selectedVideoCodec, analysis)}',
        '压缩模式: ${formatCompressionMode(task)}',
        '码率: ${WorkbenchFormatters.formatBitrate(targetBitrate)}',
        '分辨率: $targetResolution',
        '视频格式: ${selectedOutputFormat.label}',
        '视频时长: $targetDuration',
      ],
    );
  }

  List<EncoderBackend> availableEncoderBackends({
    VideoCodec? videoCodec,
    EncoderBackend? selectedBackend,
  }) {
    final resolvedVideoCodec = videoCodec ?? selectedVideoCodec;
    final resolvedSelectedBackend = selectedBackend ?? selectedEncoderBackend;
    final softwareBackend = resolvedVideoCodec == VideoCodec.hevc
        ? EncoderBackend.libx265
        : EncoderBackend.libx264;

    late final List<EncoderBackend> backends;
    if (Platform.isMacOS) {
      backends = [
        EncoderBackend.auto,
        EncoderBackend.videotoolbox,
        softwareBackend,
      ];
    } else if (Platform.isWindows) {
      backends = [
        EncoderBackend.auto,
        EncoderBackend.nvenc,
        EncoderBackend.qsv,
        EncoderBackend.amf,
        softwareBackend,
      ];
    } else {
      backends = [EncoderBackend.auto, softwareBackend];
    }

    if (!backends.contains(resolvedSelectedBackend)) {
      return [...backends, resolvedSelectedBackend];
    }

    return backends;
  }

  bool isBackendCompatibleWithCodec(EncoderBackend backend, VideoCodec codec) {
    return switch (backend) {
      EncoderBackend.libx264 => codec == VideoCodec.h264,
      EncoderBackend.libx265 => codec == VideoCodec.hevc,
      _ => true,
    };
  }

  Future<void> pickExportDirectory() async {
    final directoryPath = await getDirectoryPath(confirmButtonText: '选择导出文件夹');
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      return;
    }

    setExportDirectory(directoryPath);
  }

  void setExportDirectory(String directoryPath) {
    final normalizedPath = path.normalize(directoryPath);
    exportDirectoryController.text = normalizedPath;
    setState(() {
      saveToSourceDirectory = false;
    });
    unawaited(updateSelectedTaskConfig(outputDirectory: normalizedPath));
  }

  String? firstDroppedDirectoryPath(List<DropItem> items) {
    for (final item in items) {
      if (item is DropItemDirectory) {
        return item.path;
      }

      final entityType = FileSystemEntity.typeSync(item.path);
      if (entityType == FileSystemEntityType.directory) {
        return item.path;
      }
    }

    return null;
  }

  String get defaultExportPath {
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return Directory.current.path;
    }

    return path.join(home, 'Desktop');
  }

  QualityOption get selectedQualityOption =>
      WorkbenchConstants.qualityOptions[selectedQualityIndex];

  int initialQualityIndexForTask(MediaTask task) {
    if (task.config.compressionMode == CompressionMode.targetSize) {
      return qualityIndexForTargetSize(
        task: task,
        targetSizeBytes: task.config.targetSizeBytes,
        targetSizeRatio: task.config.targetSizeRatio,
      );
    }

    final smartPreset = task.config.smartPreset;
    if (smartPreset != null) {
      return qualityIndexForSmartPreset(smartPreset);
    }

    final configuredIndex = qualityIndexForCrf(task.config.compressionCrf);
    if (isSourceAlreadyCompressed(task) && configuredIndex == 2) {
      return WorkbenchConstants.qualityOptions.length - 1;
    }

    return configuredIndex;
  }

  int qualityIndexForCrf(int crf) {
    for (
      var index = 0;
      index < WorkbenchConstants.qualityOptions.length;
      index += 1
    ) {
      if (WorkbenchConstants.qualityOptions[index].crf == crf) {
        return index;
      }
    }

    return 2;
  }

  int qualityIndexForTargetSize({
    required MediaTask task,
    required int? targetSizeBytes,
    required double? targetSizeRatio,
  }) {
    final sourceSize = task.sourceFileFingerprint?.fileSize;
    if (sourceSize != null &&
        sourceSize > 0 &&
        targetSizeBytes != null &&
        targetSizeBytes > 0) {
      return qualityIndexForTargetSizeRatio(targetSizeBytes / sourceSize);
    }

    return qualityIndexForTargetSizeRatio(targetSizeRatio);
  }

  int qualityIndexForTargetSizeRatio(double? targetSizeRatio) {
    if (targetSizeRatio == null || targetSizeRatio <= 0) {
      return 4;
    }

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (
      var index = 0;
      index < WorkbenchConstants.qualityOptions.length;
      index += 1
    ) {
      final option = WorkbenchConstants.qualityOptions[index];
      final distance = (option.targetRatio - targetSizeRatio).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }

    return nearestIndex;
  }

  int qualityIndexForSmartPreset(SmartCompressionPreset preset) {
    return switch (preset) {
      SmartCompressionPreset.balanced => 4,
      SmartCompressionPreset.chat => 6,
      SmartCompressionPreset.clear => 3,
      SmartCompressionPreset.compact => 8,
    };
  }

  SmartCompressionPreset smartPresetForQualityIndex(int qualityIndexOrCrf) {
    if (qualityIndexOrCrf == 6 || qualityIndexOrCrf == 30) {
      return SmartCompressionPreset.chat;
    }
    if (qualityIndexOrCrf == 3 || qualityIndexOrCrf == 27) {
      return SmartCompressionPreset.clear;
    }
    if (qualityIndexOrCrf == 8 || qualityIndexOrCrf == 32) {
      return SmartCompressionPreset.compact;
    }

    return SmartCompressionPreset.balanced;
  }

  int? targetSizeBytesForQualityOption(MediaTask task, QualityOption option) {
    final sourceSize = task.sourceFileFingerprint?.fileSize;
    if (sourceSize == null || sourceSize <= 0) {
      return null;
    }

    return (sourceSize * option.targetRatio).round();
  }

  double? targetSizeRatioForBytes({
    required MediaTask task,
    required int? targetSizeBytes,
    required double fallbackRatio,
  }) {
    final sourceSize = task.sourceFileFingerprint?.fileSize;
    if (sourceSize == null || sourceSize <= 0) {
      return fallbackRatio;
    }

    if (targetSizeBytes == null || targetSizeBytes <= 0) {
      return fallbackRatio;
    }

    return targetSizeBytes / sourceSize;
  }

  bool isSourceAlreadyCompressed(MediaTask task) {
    return WorkbenchFormatters.isSourceAlreadyCompressed(task);
  }

  int? calculateQualityTargetBitrate(MediaTask task, int? sourceBitrate) {
    if (sourceBitrate == null || sourceBitrate <= 0) {
      return null;
    }

    final targetRatio =
        task.config.compressionMode == CompressionMode.targetSize
        ? task.config.targetSizeRatio ?? selectedQualityOption.targetRatio
        : selectedQualityOption.targetRatio;

    return (sourceBitrate * targetRatio).round();
  }

  String formatCompressionMode(MediaTask task) {
    if (task.config.compressionMode == CompressionMode.targetSize) {
      final targetSizeBytes =
          task.config.targetSizeBytes ??
          targetSizeBytesForQualityOption(task, selectedQualityOption);
      if (targetSizeBytes != null) {
        return '目标体积 ${WorkbenchFormatters.formatBytes(targetSizeBytes)}';
      }

      return '目标体积';
    }

    final smartPreset = task.config.smartPreset ?? selectedSmartPreset;
    if (isSourceAlreadyCompressed(task) &&
        smartPreset == SmartCompressionPreset.compact) {
      return '低码率极限压缩';
    }

    return '${smartPreset.label} / ${selectedQualityOption.label}';
  }
}
