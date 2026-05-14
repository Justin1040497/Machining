import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:machining/application/services/ffmpeg_task_queue_runner.dart';
import 'package:machining/application/services/preview_frame_generator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/features/workbench/providers/media_task_notifier.dart';
import 'package:machining/features/workbench/widgets/workbench_task_list_item.dart';
import 'package:machining/infrastructure/providers/ffmpeg_provider.dart';
import 'package:path/path.dart' as path;

enum TaskContextMenuAction { revealInFinder, rename, delete }

class DroppedImportFailure {
  const DroppedImportFailure({required this.path, required this.reason});

  final String path;
  final String reason;
}

class WorkbenchPage extends ConsumerStatefulWidget {
  const WorkbenchPage({super.key});

  @override
  ConsumerState createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends ConsumerState<WorkbenchPage> {
  static const double minWorkbenchWidth = 750;
  static const double minWorkbenchHeight = 640;
  static const videoTypeGroup = XTypeGroup(
    label: '视频文件',
    extensions: ['mp4', 'mov', 'mkv', 'm4v', 'avi', 'webm'],
    uniformTypeIdentifiers: [
      'public.movie',
      'public.video',
      'public.mpeg-4',
      'com.apple.quicktime-movie',
      'org.matroska.mkv',
    ],
  );

  static const qualityOptions = [
    QualityOption(label: '高质量', crf: 24, targetRatio: 0.90),
    QualityOption(label: '清晰', crf: 26, targetRatio: 0.80),
    QualityOption(label: '均衡', crf: 28, targetRatio: 0.72),
    QualityOption(label: '小体积', crf: 30, targetRatio: 0.62),
    QualityOption(label: '最低体积', crf: 32, targetRatio: 0.50),
  ];

  int selectedQualityIndex = 2;
  OutputFormat selectedOutputFormat = OutputFormat.mp4;
  VideoCodec selectedVideoCodec = VideoCodec.h264;
  EncoderBackend selectedEncoderBackend = EncoderBackend.auto;
  ResolutionPreset selectedResolutionPreset = ResolutionPreset.p1080;
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

                final hasRunningTask = tasks.any(
                  (task) => task.status == TaskStatus.running,
                );

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: minWorkbenchWidth,
                    minHeight: minWorkbenchHeight,
                    maxWidth: constraints.maxWidth < minWorkbenchWidth
                        ? minWorkbenchWidth
                        : constraints.maxWidth,
                    maxHeight: constraints.maxHeight < minWorkbenchHeight
                        ? minWorkbenchHeight
                        : constraints.maxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          bottom: 48,
                          child: buildTaskListCard(taskList, selectedTask),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: buildMainBottomBar(
                            taskList: taskList,
                            hasRunningTask: hasRunningTask,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (workbenchImportDragging) buildWorkbenchDropOverlay(),
          ],
        ),
      ),
    );
  }

  Widget buildWorkbenchDropOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    color: Color(0xFF6290FF),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '移动到窗口松手即添加',
                    style: TextStyle(
                      color: Color(0xFF252525),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget buildTaskListCard(
    AsyncValue<List<MediaTask>> taskList,
    MediaTask? selectedTask,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(27, 31, 27, 0),
      child: taskList.when(
        loading: buildTaskListLoading,
        error: (error, stackTrace) => buildTaskListError(error),
        data: (tasks) => buildTaskList(tasks, selectedTask),
      ),
    );
  }

  Widget buildTaskList(List<MediaTask> tasks, MediaTask? selectedTask) {
    if (tasks.isEmpty) {
      return buildTaskListEmpty();
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(mediaTaskListProvider.notifier)
            .reorderTasks(oldIndex: oldIndex, newIndex: newIndex);
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
        final task = tasks[index];

        return Padding(
          key: ValueKey(task.id),
          padding: EdgeInsets.only(bottom: index == tasks.length - 1 ? 0 : 13),
          child: WorkbenchTaskListItem(
            task: task,
            selected: selectedTask?.id == task.id,
            reorderIndex: index,
            onTap: () {
              setState(() {
                selectedTaskId = task.id;
                syncedConfigTaskId = null;
                syncedQualityTaskKey = null;
                previewFrameResult = null;
                selectedPreviewFrameIndex = 0;
              });
            },
            onStart: () => startOrResumeTask(task),
            onPause: () => pauseTask(task),
            onRemove: () => deleteTask(task),
            onRetry: () => retryTask(task),
            onConfigure: () => showTaskConfigurationDialog(task),
            onSecondaryTapDown: (details) {
              unawaited(showTaskContextMenu(task, details.globalPosition));
            },
          ),
        );
      },
    );
  }

  Widget buildTaskListLoading() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget buildTaskListError(Object error) {
    return Center(
      child: Text(
        '任务列表读取失败\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
      ),
    );
  }

  Widget buildTaskListEmpty() {
    return const Center(
      child: Text(
        '暂无任务\n点击左下角 + 添加视频',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12, height: 1.5),
      ),
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

  Future<void> showTaskConfigurationDialog(MediaTask task) async {
    setState(() {
      selectedTaskId = task.id;
      selectedOutputFormat = task.config.outputFormat;
      selectedVideoCodec = task.config.videoCodec;
      selectedEncoderBackend = task.config.encoderBackend;
      selectedResolutionPreset = task.config.resolutionPreset;
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFF6F6F6),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 46,
            vertical: 36,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Column(
                      children: [
                        Card(
                          color: Colors.white,
                          child: SizedBox(
                            height: 96,
                            child: buildQualitySliderPanel(),
                          ),
                        ),
                        Card(
                          color: Colors.white,
                          child: buildVideoConfigPanel(),
                        ),
                        Card(
                          color: Colors.white,
                          child: SizedBox(
                            height: 220,
                            child: buildFileInfoPanel(task),
                          ),
                        ),
                        Card(
                          color: Colors.white,
                          child: SizedBox(
                            height: 180,
                            child: buildExportPathPanel(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildMainBottomBar({
    required AsyncValue<List<MediaTask>> taskList,
    required bool hasRunningTask,
  }) {
    final hasTasks = taskList.hasValue && taskList.requireValue.isNotEmpty;

    return SizedBox(
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.expand(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  buildDockIconButton(
                    tooltip: '添加任务',
                    icon: Icons.add_rounded,
                    onPressed: pickAndAddTasks,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  buildDockIconButton(
                    tooltip: '设置',
                    icon: Icons.settings,
                    onPressed: () {
                      showWorkbenchDialog(title: '设置', message: '设置窗口内容待接入');
                    },
                  ),
                  Spacer(),
                  buildDockIconButton(
                    tooltip: '清空列表',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFFF5B61),
                    onPressed: hasTasks ? confirmClearTasks : null,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 62 / 2 - 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildPrimaryQueueButton(
                  hasTasks: hasTasks,
                  hasRunningTask: hasRunningTask,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDockIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 22,
    Color color = Colors.black,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget buildPrimaryQueueButton({
    required bool hasTasks,
    required bool hasRunningTask,
  }) {
    return Tooltip(
      message: hasRunningTask ? '暂停所有任务' : '开始执行',
      child: SizedBox(
        width: 68,
        height: 68,
        child: FilledButton(
          onPressed: hasTasks && !queueActionInFlight
              ? () => unawaited(handlePrimaryQueueAction(hasRunningTask))
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6290FF),
            disabledBackgroundColor: const Color(0xFFB9CBFF),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Icon(
            hasRunningTask ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 34,
          ),
        ),
      ),
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
      return await openFiles(acceptedTypeGroups: [videoTypeGroup]);
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
      outputFormat: inferInitialOutputFormat(task),
      videoCodec: inferInitialVideoCodec(task),
      resolutionPreset: ResolutionPreset.original,
      outputDirectory: '',
      compressionCrf: qualityOptions[nextQualityIndex].crf,
      outputFileName: '',
    );

    setState(() {
      selectedQualityIndex = nextQualityIndex;
      selectedOutputFormat = initialConfig.outputFormat;
      selectedVideoCodec = initialConfig.videoCodec;
      selectedEncoderBackend = initialConfig.encoderBackend;
      selectedResolutionPreset = initialConfig.resolutionPreset;
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

  Widget buildSidebarActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Icon(icon),
        ),
      ),
    );
  }

  Widget buildTopBarIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: 20, color: const Color(0xFF111111)),
        ),
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

  Widget buildPreviewPanel(MediaTask? selectedTask) {
    final result = previewFrameResult;
    final hasFrames =
        result != null &&
        result.taskId == selectedTask?.id &&
        result.frames.isNotEmpty;

    if (!hasFrames) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Text(
              '点击生成预览',
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
            ),
          ),
          if (previewGenerating) buildPreviewLoadingOverlay(),
        ],
      );
    }

    final frame = result
        .frames[selectedPreviewFrameIndex.clamp(0, result.frames.length - 1)];

    return Stack(
      fit: StackFit.expand,
      children: [
        buildPreviewComparison(frame),
        Positioned(left: 22, top: 18, child: buildPreviewBadge('原始')),
        Positioned(right: 22, top: 18, child: buildPreviewBadge('压缩预览帧')),
        if (previewGenerating) buildPreviewLoadingOverlay(),
      ],
    );
  }

  Widget buildPreviewComparison(PreviewFramePair frame) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final splitX = (previewCompareRatio * width).clamp(0.0, width);

        void updateSplit(Offset localPosition) {
          final nextRatio = (localPosition.dx / width).clamp(0.02, 0.98);
          setState(() {
            previewCompareRatio = nextRatio;
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateSplit(details.localPosition),
          onHorizontalDragUpdate: (details) {
            updateSplit(details.localPosition);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRect(
                  clipper: PreviewComparisonClipper(left: 0, right: splitX),
                  child: Image.file(
                    File(frame.originalFramePath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRect(
                  clipper: PreviewComparisonClipper(left: splitX, right: width),
                  child: Image.file(
                    File(frame.previewFramePath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned(
                left: splitX - 2,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: Colors.white),
              ),
              Positioned(
                left: splitX - 18,
                top: (height / 2) - 18,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      size: 22,
                      color: Color(0xFF6290FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildPreviewBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDDEAF2F7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget buildPreviewLoadingOverlay() {
    return Container(
      color: const Color(0x66FFFFFF),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget buildPreviewToolbar() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                height: constraints.maxHeight,
                width: constraints.maxHeight,
                child: OutlinedButton(
                  onPressed: resetSelectedTaskConfiguration,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFE3E3E3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.refresh_rounded),
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: buildPreviewFrameIndicator(),
                ),
              ),
              buildToolbarActionButton(
                label: '生成预览',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFFFF8200),
                onPressed: previewGenerating ? null : generatePreviewFrames,
              ),
              const SizedBox(width: 18),
              buildToolbarActionButton(
                label: '开始执行',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF6290FF),
                onPressed: startExecutionQueue,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildPreviewFrameIndicator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameCount = previewFrameResult?.frames.length ?? 5;
        final itemCount = frameCount <= 0 ? 5 : frameCount;
        const itemGap = 28.0;
        final totalGap = itemGap * (itemCount - 1);
        final itemWidth = ((constraints.maxWidth - totalGap) / itemCount).clamp(
          28.0,
          90.0,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(itemCount, (index) {
            final active = index == selectedPreviewFrameIndex;

            return Padding(
              padding: EdgeInsets.only(
                right: index == itemCount - 1 ? 0 : itemGap,
              ),
              child: GestureDetector(
                onTap: previewFrameResult == null
                    ? null
                    : () {
                        setState(() {
                          selectedPreviewFrameIndex = index;
                        });
                      },
                child: Container(
                  width: itemWidth,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6290FF)
                        : const Color(0xFFDCDCDC),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget buildToolbarActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 24),
          ],
        ),
      ),
    );
  }

  Widget buildQualitySliderPanel() {
    final option = selectedQualityOption;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '视频质量',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${option.label} / CRF ${option.crf}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 30, child: buildQualitySlider()),
        ],
      ),
    );
  }

  Widget buildQualitySlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 28.0;
        const trackHeight = 16.0;
        final trackWidth = constraints.maxWidth;
        final stepCount = qualityOptions.length - 1;
        final qualityValue = selectedQualityIndex / stepCount;
        final thumbCenter = qualityValue * trackWidth;
        final thumbLeft = (thumbCenter - thumbSize / 2).clamp(
          0.0,
          trackWidth - thumbSize,
        );

        void updateValue(Offset localPosition) {
          final ratio = (localPosition.dx / trackWidth).clamp(0.0, 1.0);
          final index = (ratio * stepCount).round().clamp(0, stepCount);
          if (index == selectedQualityIndex) {
            return;
          }
          setState(() {
            selectedQualityIndex = index;
          });
          unawaited(
            updateSelectedTaskConfig(compressionCrf: qualityOptions[index].crf),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateValue(details.localPosition),
          onHorizontalDragUpdate: (details) {
            updateValue(details.localPosition);
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: trackHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(qualityOptions.length, (index) {
                    final active = index <= selectedQualityIndex;
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : const Color(0xFFCFCFCF),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
              FractionallySizedBox(
                widthFactor: qualityValue,
                child: Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6290FF),
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6290FF),
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildVideoConfigPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          buildConfigDropdown<OutputFormat>(
            label: '视频格式',
            trailingText: selectedOutputFormat.label,
            value: selectedOutputFormat,
            values: OutputFormat.values,
            itemLabel: (value) => value.label,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                selectedOutputFormat = value;
              });
              unawaited(updateSelectedTaskConfig(outputFormat: value));
            },
          ),
          const SizedBox(height: 14),
          buildConfigDropdown<VideoCodec>(
            label: '视频编码',
            trailingText: selectedVideoCodec == VideoCodec.hevc
                ? 'HEVC'
                : selectedVideoCodec.label,
            value: selectedVideoCodec,
            values: const [VideoCodec.h264, VideoCodec.hevc],
            itemLabel: (value) => value.label,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final nextEncoderBackend =
                  isBackendCompatibleWithCodec(selectedEncoderBackend, value)
                  ? selectedEncoderBackend
                  : EncoderBackend.auto;
              setState(() {
                selectedVideoCodec = value;
                selectedEncoderBackend = nextEncoderBackend;
              });
              unawaited(
                updateSelectedTaskConfig(
                  videoCodec: value,
                  encoderBackend: nextEncoderBackend,
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          buildConfigDropdown<EncoderBackend>(
            label: '编码器',
            trailingText: selectedEncoderBackend.label,
            value: selectedEncoderBackend,
            values: availableEncoderBackends(),
            itemLabel: (value) => value.label,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                selectedEncoderBackend = value;
              });
              unawaited(updateSelectedTaskConfig(encoderBackend: value));
            },
          ),
          const SizedBox(height: 14),
          buildConfigDropdown<ResolutionPreset>(
            label: '分辨率',
            trailingText: selectedResolutionPreset.label,
            value: selectedResolutionPreset,
            values: const [
              ResolutionPreset.original,
              ResolutionPreset.p2160,
              ResolutionPreset.p1080,
              ResolutionPreset.p720,
              ResolutionPreset.p480,
            ],
            itemLabel: (value) => value.label,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                selectedResolutionPreset = value;
              });
              unawaited(updateSelectedTaskConfig(resolutionPreset: value));
            },
          ),
        ],
      ),
    );
  }

  List<EncoderBackend> availableEncoderBackends() {
    final softwareBackend = selectedVideoCodec == VideoCodec.hevc
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

    if (!backends.contains(selectedEncoderBackend)) {
      return [...backends, selectedEncoderBackend];
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

  Widget buildConfigDropdown<T>({
    required String label,
    required String trailingText,
    required T value,
    required List<T> values,
    required String Function(T value) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111111),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              trailingText,
              style: const TextStyle(fontSize: 13, color: Color(0xFF111111)),
            ),
          ],
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<T>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          items: values.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(fontSize: 13, color: Color(0xFF111111)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF9A9A9A),
            size: 20,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: Color(0xFF6290FF)),
            ),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  Widget buildFileInfoPanel(MediaTask task) {
    final analysis = task.analysisResult;
    final recommendation = ref
        .watch(compressionAdvisorProvider)
        .recommend(
          task,
          allowExtremeCompression:
              isSourceAlreadyCompressed(task) &&
              selectedQualityOption.isLowestVolume,
        );
    final targetResolution =
        selectedResolutionPreset == ResolutionPreset.original
        ? formatResolution(analysis)
        : selectedResolutionPreset.label;
    final targetDuration = formatDuration(analysis?.durationMs);
    final targetBitrate =
        recommendation.targetTotalBitrate ??
        calculateQualityTargetBitrate(analysis?.preferredBitrate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: buildFileInfoColumn(
              title: '源文件信息',
              rows: [
                '编码: ${formatCodec(analysis?.videoCodec)}',
                '视频大小: ${formatBytes(task.sourceFileFingerprint?.fileSize)}',
                '码率: ${formatBitrate(analysis?.preferredBitrate)}',
                '分辨率: ${formatResolution(analysis)}',
                '视频格式: ${formatContainer(analysis?.containerFormat)}',
                '视频时长: ${formatDuration(analysis?.durationMs)}',
                if (task.analysisErrorMessage != null)
                  '分析提示: ${task.analysisErrorMessage}',
              ],
            ),
          ),
          Container(
            width: 1,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFFE5E5E5),
          ),
          Expanded(
            child: buildFileInfoColumn(
              title: '输出文件信息',
              rows: [
                '编码: ${formatTargetCodec(selectedVideoCodec, analysis)}',
                '压缩模式: ${formatCompressionMode(task)}',
                '码率: ${formatBitrate(targetBitrate)}',
                '分辨率: $targetResolution',
                '视频格式: ${selectedOutputFormat.label}',
                '视频时长: $targetDuration',
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyFileInfoPanel() {
    return const Center(
      child: Text(
        '请选择一个视频任务',
        style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
      ),
    );
  }

  Widget buildFileInfoColumn({
    required String title,
    required List<String> rows,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map((text) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8D8D8D),
                  fontSize: 11,
                  height: 1,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildExportPathPanel() {
    final statusText = saveToSourceDirectory ? '当前是原文件旁' : '当前是自定义地址';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '导出地址',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                statusText,
                style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: Checkbox(
                  value: saveToSourceDirectory,
                  onChanged: (value) {
                    final checked = value ?? false;
                    setState(() {
                      saveToSourceDirectory = checked;
                    });
                    unawaited(
                      updateSelectedTaskConfig(
                        outputDirectory: checked
                            ? ''
                            : exportDirectoryController.text.trim(),
                      ),
                    );
                  },
                  side: const BorderSide(color: Color(0xFFDCDCDC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                '保存到原文件旁',
                style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          buildExportDirectoryField(),
          const SizedBox(height: 12),
          buildOutputFileNameField(),
        ],
      ),
    );
  }

  Widget buildExportDirectoryField() {
    final enabled = !saveToSourceDirectory;

    return DropTarget(
      enable: enabled,
      onDragEntered: (_) {
        setState(() {
          exportDirectoryDragging = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          exportDirectoryDragging = false;
        });
      },
      onDragDone: (details) {
        setState(() {
          exportDirectoryDragging = false;
        });
        final droppedPath = firstDroppedDirectoryPath(details.files);
        if (droppedPath == null) {
          showWorkbenchSnackBar('请拖入文件夹作为导出地址');
          return;
        }
        setExportDirectory(droppedPath);
      },
      child: buildExportTextField(
        controller: exportDirectoryController,
        enabled: enabled,
        hintText: defaultExportPath,
        trailingIcon: Icons.chevron_right_rounded,
        highlighted: exportDirectoryDragging,
        onChanged: (value) {
          unawaited(updateSelectedTaskConfig(outputDirectory: value.trim()));
        },
        onTrailingTap: enabled ? pickExportDirectory : null,
      ),
    );
  }

  Widget buildOutputFileNameField() {
    return buildExportTextField(
      controller: outputFileNameController,
      enabled: true,
      hintText: '输出文件名（如果为空，系统会自己生成）',
      onChanged: (value) {
        unawaited(updateSelectedTaskConfig(outputFileName: value.trim()));
      },
      onTrailingTap: () {},
    );
  }

  Widget buildExportTextField({
    required TextEditingController controller,
    required bool enabled,
    required String hintText,
    IconData? trailingIcon,
    bool highlighted = false,
    ValueChanged<String>? onChanged,
    VoidCallback? onTrailingTap,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF6290FF)
              : const Color(0xFFE3E3E3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              maxLines: 1,
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF111111)
                    : const Color(0xFFCFCFCF),
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Color(0xFFCFCFCF)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.only(left: 14, right: 8),
              ),
            ),
          ),
          if (trailingIcon != null)
            IconButton(
              tooltip: enabled ? '选择文件夹' : null,
              onPressed: onTrailingTap,
              padding: EdgeInsets.zero,
              icon: Icon(
                trailingIcon,
                color: enabled
                    ? const Color(0xFF9A9A9A)
                    : const Color(0xFFCFCFCF),
                size: 20,
              ),
            ),
        ],
      ),
    );
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

  String formatCodec(String? codec) {
    if (codec == null || codec.isEmpty) {
      return '-';
    }

    final normalized = codec.toLowerCase();
    if (normalized == 'h264' || normalized == 'avc1') {
      return 'H264';
    }
    if (normalized == 'hevc' || normalized == 'h265') {
      return 'HEVC';
    }
    return codec.toUpperCase();
  }

  String formatResolution(MediaAnalysisResult? analysis) {
    final width = analysis?.videoWidth;
    final height = analysis?.videoHeight;
    if (width == null || height == null) {
      return '-';
    }
    return '$width × $height';
  }

  String formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return '-';
    }

    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String formatBitrate(int? bitrate) {
    if (bitrate == null || bitrate <= 0) {
      return '-';
    }

    return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
  }

  String formatContainer(String? containerFormat) {
    if (containerFormat == null || containerFormat.isEmpty) {
      return '-';
    }

    return containerFormat.split(',').first.toUpperCase();
  }

  String formatTargetCodec(VideoCodec codec, MediaAnalysisResult? analysis) {
    if (codec == VideoCodec.source) {
      return formatCodec(analysis?.videoCodec);
    }

    return codec == VideoCodec.hevc ? 'HEVC' : codec.label;
  }

  QualityOption get selectedQualityOption =>
      qualityOptions[selectedQualityIndex];

  int initialQualityIndexForTask(MediaTask task) {
    final configuredIndex = qualityIndexForCrf(task.config.compressionCrf);
    if (isSourceAlreadyCompressed(task) && configuredIndex == 2) {
      return qualityOptions.length - 1;
    }

    return configuredIndex;
  }

  int qualityIndexForCrf(int crf) {
    for (var index = 0; index < qualityOptions.length; index += 1) {
      if (qualityOptions[index].crf == crf) {
        return index;
      }
    }

    return 2;
  }

  OutputFormat inferInitialOutputFormat(MediaTask task) {
    final extension = path.extension(task.fileName).toLowerCase();
    switch (extension) {
      case '.mov':
        return OutputFormat.mov;
      case '.mkv':
        return OutputFormat.mkv;
      case '.mp4':
      case '.m4v':
        return OutputFormat.mp4;
    }

    final containerFormat = task.analysisResult?.containerFormat?.toLowerCase();
    if (containerFormat == null || containerFormat.isEmpty) {
      return OutputFormat.mp4;
    }
    if (containerFormat.contains('matroska') ||
        containerFormat.contains('mkv')) {
      return OutputFormat.mkv;
    }
    if (containerFormat.contains('mov') && !containerFormat.contains('mp4')) {
      return OutputFormat.mov;
    }

    return OutputFormat.mp4;
  }

  VideoCodec inferInitialVideoCodec(MediaTask task) {
    final codec = task.analysisResult?.videoCodec?.toLowerCase();
    if (codec == 'hevc' || codec == 'h265') {
      return VideoCodec.hevc;
    }

    return VideoCodec.h264;
  }

  bool isSourceAlreadyCompressed(MediaTask task) {
    final analysis = task.analysisResult;
    final bitrate = analysis?.preferredBitrate;
    final threshold = lowBitrateThreshold(analysis);
    if (bitrate == null || threshold == null) {
      return false;
    }

    return bitrate < threshold;
  }

  int? lowBitrateThreshold(MediaAnalysisResult? analysis) {
    final height = analysis?.videoHeight;
    if (height == null || height <= 0) {
      return null;
    }

    if (height >= 1080) {
      return 1500000;
    }
    if (height >= 720) {
      return 800000;
    }
    return 500000;
  }

  int? calculateQualityTargetBitrate(int? sourceBitrate) {
    if (sourceBitrate == null || sourceBitrate <= 0) {
      return null;
    }

    return (sourceBitrate * selectedQualityOption.targetRatio).round();
  }

  String formatCompressionMode(MediaTask task) {
    if (isSourceAlreadyCompressed(task) &&
        selectedQualityOption.isLowestVolume) {
      return '低码率极限压缩';
    }

    return '${selectedQualityOption.label} CRF ${selectedQualityOption.crf}';
  }

  String formatBytes(int? bytes) {
    if (bytes == null) {
      return '-';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    if (unitIndex == 0) {
      return '${value.round()}${units[unitIndex]}';
    }

    final text = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text${units[unitIndex]}';
  }
}

class QualityOption {
  final String label;
  final int crf;
  final double targetRatio;

  const QualityOption({
    required this.label,
    required this.crf,
    required this.targetRatio,
  });

  bool get isLowestVolume => label == '最低体积';
}

class PreviewComparisonClipper extends CustomClipper<Rect> {
  final double left;
  final double right;

  const PreviewComparisonClipper({required this.left, required this.right});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      left.clamp(0.0, size.width),
      0,
      right.clamp(0.0, size.width),
      size.height,
    );
  }

  @override
  bool shouldReclip(PreviewComparisonClipper oldClipper) {
    return oldClipper.left != left || oldClipper.right != right;
  }
}
