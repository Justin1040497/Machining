import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/application/services/ffmpeg_task_queue_runner.dart';
import 'package:machining/infrastructure/providers/drift_provider.dart';
import 'package:machining/infrastructure/providers/ffmpeg_provider.dart';
import 'package:path/path.dart' as path;

/// 工作台任务列表状态
final mediaTaskListProvider =
    AsyncNotifierProvider<MediaTaskListNotifier, List<MediaTask>>(
      MediaTaskListNotifier.new,
    );

class MediaTaskListNotifier extends AsyncNotifier<List<MediaTask>> {
  Timer? executionRefreshTimer;

  @override
  Future<List<MediaTask>> build() async {
    ref.onDispose(() {
      executionRefreshTimer?.cancel();
    });

    final repository = ref.watch(mediaTaskRepositoryProvider);
    final sourceFileChecker = ref.watch(sourceFileCheckerProvider);
    final fingerprintReader = ref.watch(sourceFileFingerprintReaderProvider);
    final tasks = await repository.loadAllTasks();
    final checkedTasks = <MediaTask>[];
    final needAnalysisTaskIds = <String>[];
    var hasChanged = false;

    for (final task in tasks) {
      final exists = await sourceFileChecker.exists(task.inputPath);

      if (!exists) {
        if (task.status == TaskStatus.missingSource) {
          checkedTasks.add(task);
        } else {
          checkedTasks.add(task.markMissingSource());
          hasChanged = true;
        }
        continue;
      }

      if (exists && task.status == TaskStatus.missingSource) {
        final fingerprint = await fingerprintReader.read(task.inputPath);
        final updatedTask = task
            .markPendingForRetry()
            .withSourceFileFingerprint(fingerprint)
            .copyWith(status: TaskStatus.analyzing);
        checkedTasks.add(updatedTask);
        needAnalysisTaskIds.add(updatedTask.id);
        hasChanged = true;
        continue;
      }

      final fingerprint = await fingerprintReader.read(task.inputPath);
      if (!fingerprint.isSameAs(task.sourceFileFingerprint)) {
        final updatedTask = task
            .withSourceFileFingerprint(fingerprint)
            .clearAnalysis()
            .copyWith(status: TaskStatus.analyzing);
        checkedTasks.add(updatedTask);
        needAnalysisTaskIds.add(updatedTask.id);
        hasChanged = true;
        continue;
      }

      if (task.analysisResult == null) {
        final updatedTask = task.status == TaskStatus.pending
            ? task.copyWith(status: TaskStatus.analyzing)
            : task;
        checkedTasks.add(updatedTask);
        needAnalysisTaskIds.add(updatedTask.id);
        hasChanged = hasChanged || updatedTask.status != task.status;
        continue;
      }

      checkedTasks.add(task);
    }

    if (hasChanged) {
      await repository.replaceAllTasks(checkedTasks);
    }

    if (needAnalysisTaskIds.isNotEmpty) {
      unawaited(analyzeTasksInBackground(needAnalysisTaskIds));
    }

    unawaited(syncFfmpegQueueStatus());
    return checkedTasks;
  }

  Future<MediaTask> createDraftFromPath(String inputPath) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final resolver = ref.read(mediaKindResolverProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final mediaKind = resolver.resolve(inputPath);
    ensureSupportedMediaKind(mediaKind);
    final fingerprint = await fingerprintReader.read(inputPath);

    final task =
        MediaTask.draft(
              inputPath: inputPath,
              fileName: path.basename(inputPath),
              mediaKind: mediaKind,
              sortOrder: nextSortOrder(tasks),
            )
            .withSourceFileFingerprint(fingerprint)
            .copyWith(status: TaskStatus.analyzing);

    await repository.saveTask(task);
    state = AsyncData([...tasks, task]);
    unawaited(syncFfmpegQueueStatus());
    unawaited(analyzeTaskById(task.id));
    return task;
  }

  Future<List<MediaTask>> createDraftsFromPaths(List<String> inputPaths) async {
    final createdTasks = <MediaTask>[];

    for (final inputPath in inputPaths) {
      if (inputPath.trim().isEmpty) {
        continue;
      }

      final task = await createDraftFromPath(inputPath);
      createdTasks.add(task);
    }

    return createdTasks;
  }

  Future<void> saveTask(MediaTask task) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final tasks = state.requireValue;

    await repository.saveTask(task);
    state = AsyncData(replaceTask(tasks, task));
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> replaceMissingSource({
    required String taskId,
    required String newInputPath,
  }) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final resolver = ref.read(mediaKindResolverProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final task = findTaskById(tasks, taskId);
    final mediaKind = resolver.resolve(newInputPath);
    ensureSupportedMediaKind(mediaKind);
    if (!await ref.read(sourceFileCheckerProvider).exists(newInputPath)) {
      throw StateError('源文件不存在: $newInputPath');
    }

    final fingerprint = await fingerprintReader.read(newInputPath);

    final updatedTask = task
        .replaceInputFile(
          newInputPath: newInputPath,
          newFileName: path.basename(newInputPath),
          newMediaKind: mediaKind,
        )
        .withSourceFileFingerprint(fingerprint);

    await repository.saveTask(updatedTask);
    state = AsyncData(replaceTask(tasks, updatedTask));
    unawaited(syncFfmpegQueueStatus());
    unawaited(analyzeTaskById(updatedTask.id));
  }

  Future<void> deleteTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final tasks = state.requireValue;
    final task = findTaskById(tasks, taskId);

    if (task.status == TaskStatus.running || task.status == TaskStatus.paused) {
      await queueRunner.cancelTask(taskId);
    }
    await repository.deleteTaskById(taskId);
    state = AsyncData(tasks.where((task) => task.id != taskId).toList());
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> retryTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final sourceFileChecker = ref.read(sourceFileCheckerProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final task = findTaskById(tasks, taskId);

    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      state = AsyncData(replaceTask(tasks, updatedTask));
      unawaited(syncFfmpegQueueStatus());
      return;
    }

    final fingerprint = await fingerprintReader.read(task.inputPath);
    final analyzingTask = task
        .markPendingForRetry()
        .clearError()
        .withSourceFileFingerprint(fingerprint)
        .clearAnalysis()
        .copyWith(status: TaskStatus.analyzing);

    await repository.saveTask(analyzingTask);
    state = AsyncData(replaceTask(tasks, analyzingTask));
    unawaited(syncFfmpegQueueStatus());
    unawaited(analyzeTaskById(taskId));
  }

  Future<void> clearTasks() async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);

    await queueRunner.cancelAllExecutions();
    await repository.replaceAllTasks([]);
    state = const AsyncData([]);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<FfmpegQueueStartResult> startExecutionQueue({
    bool allowExtremeCompression = false,
  }) async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await queueRunner.start(
      allowExtremeCompression: allowExtremeCompression,
    );

    await refreshTasksFromRepository();
    if (result.outcome == FfmpegQueueStartOutcome.started ||
        result.outcome == FfmpegQueueStartOutcome.resumed ||
        result.outcome == FfmpegQueueStartOutcome.alreadyRunning) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<FfmpegQueueStartResult> startOrResumeTaskById(
    String taskId, {
    bool allowExtremeCompression = false,
  }) async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await queueRunner.startOrResumeTask(
      taskId,
      allowExtremeCompression: allowExtremeCompression,
    );

    await refreshTasksFromRepository();
    if (result.outcome == FfmpegQueueStartOutcome.started ||
        result.outcome == FfmpegQueueStartOutcome.resumed ||
        result.outcome == FfmpegQueueStartOutcome.alreadyRunning) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<FfmpegQueueStartResult> pauseTaskById(String taskId) async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await queueRunner.pauseTask(taskId);

    await refreshTasksFromRepository();
    if (result.outcome == FfmpegQueueStartOutcome.paused) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<void> refreshTasksFromRepository() async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    state = AsyncData(await repository.loadAllTasks());
  }

  void startExecutionRefreshPolling() {
    executionRefreshTimer?.cancel();
    executionRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      unawaited(refreshExecutionState(timer));
    });
  }

  Future<void> refreshExecutionState(Timer timer) async {
    if (!state.hasValue) {
      return;
    }

    await refreshTasksFromRepository();
    final tasks = state.requireValue;
    final hasActiveTask = tasks.any(
      (task) =>
          task.status == TaskStatus.running || task.status == TaskStatus.paused,
    );
    if (!hasActiveTask) {
      timer.cancel();
      executionRefreshTimer = null;
      unawaited(syncFfmpegQueueStatus());
    }
  }

  Future<void> reorderTasks({
    required int oldIndex,
    required int newIndex,
  }) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final tasks = [...state.requireValue];

    if (oldIndex < 0 || oldIndex >= tasks.length) {
      return;
    }

    if (tasks[oldIndex].status == TaskStatus.running) {
      return;
    }

    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    targetIndex = targetIndex.clamp(0, tasks.length - 1);
    if (oldIndex == targetIndex) {
      return;
    }

    final movedTask = tasks.removeAt(oldIndex);
    tasks.insert(targetIndex, movedTask);

    final reorderedTasks = <MediaTask>[];
    for (var index = 0; index < tasks.length; index += 1) {
      reorderedTasks.add(tasks[index].copyWith(sortOrder: index));
    }

    state = AsyncData(reorderedTasks);
    await repository.replaceAllTasks(reorderedTasks);
    unawaited(syncFfmpegQueueStatus());
  }

  int nextSortOrder(List<MediaTask> tasks) {
    if (tasks.isEmpty) {
      return 0;
    }

    return tasks
            .map((task) => task.sortOrder)
            .reduce((value, element) => value > element ? value : element) +
        1;
  }

  MediaTask findTaskById(List<MediaTask> tasks, String taskId) {
    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    throw StateError('找不到任务: $taskId');
  }

  List<MediaTask> replaceTask(List<MediaTask> tasks, MediaTask updatedTask) {
    return tasks.map((task) {
      if (task.id == updatedTask.id) {
        return updatedTask;
      }

      return task;
    }).toList();
  }

  void ensureSupportedMediaKind(MediaKind mediaKind) {
    if (mediaKind != MediaKind.video) {
      throw StateError('当前版本暂时只支持视频文件');
    }
  }

  Future<void> analyzeTasksInBackground(List<String> taskIds) async {
    for (final taskId in taskIds) {
      await analyzeTaskById(taskId);
    }
  }

  Future<void> analyzeTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final analyzer = ref.read(mediaAnalyzerProvider);
    final sourceFileChecker = ref.read(sourceFileCheckerProvider);
    var runtime = await ref.read(ffmpegRuntimeProvider.future);
    if (!runtime.canAnalyze || runtime.ffprobe == null) {
      runtime = await ref.refresh(ffmpegRuntimeProvider.future);
    }

    if (!runtime.canAnalyze || runtime.ffprobe == null) {
      await markAnalysisUnavailable(taskId, 'FFprobe 不可用，无法分析媒体信息');
      return;
    }

    if (!state.hasValue) {
      return;
    }

    var tasks = state.requireValue;
    var task = findTaskById(tasks, taskId);
    if (task.analysisResult == null && task.status == TaskStatus.pending) {
      task = task.copyWith(status: TaskStatus.analyzing);
      await repository.saveTask(task);
      state = AsyncData(replaceTask(tasks, task));
      tasks = state.requireValue;
    }

    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      state = AsyncData(replaceTask(tasks, updatedTask));
      unawaited(syncFfmpegQueueStatus());
      return;
    }

    try {
      final result = await analyzer.analyze(
        ffprobePath: runtime.ffprobe!.path,
        inputPath: task.inputPath,
      );
      final latestTask = findTaskById(state.requireValue, taskId);
      final updatedTask = latestTask
          .withAnalysisResult(result)
          .copyWith(
            status: latestTask.status == TaskStatus.analyzing
                ? TaskStatus.pending
                : latestTask.status,
          );
      await repository.saveTask(updatedTask);
      state = AsyncData(replaceTask(state.requireValue, updatedTask));
      unawaited(syncFfmpegQueueStatus());
    } on Object catch (error) {
      final latestTask = findTaskById(state.requireValue, taskId);
      final updatedTask = latestTask
          .withAnalysisError(error.toString())
          .markFailed('媒体分析失败: $error');
      await repository.saveTask(updatedTask);
      state = AsyncData(replaceTask(state.requireValue, updatedTask));
      unawaited(syncFfmpegQueueStatus());
    }
  }

  Future<void> markAnalysisUnavailable(String taskId, String message) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    if (!state.hasValue) {
      return;
    }

    final task = findTaskById(state.requireValue, taskId);
    final updatedTask = task.withAnalysisError(message).markFailed(message);
    await repository.saveTask(updatedTask);
    state = AsyncData(replaceTask(state.requireValue, updatedTask));
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> syncFfmpegQueueStatus() async {
    await ref.read(ffmpegTaskQueueRunnerProvider).refreshStatus();
  }
}
