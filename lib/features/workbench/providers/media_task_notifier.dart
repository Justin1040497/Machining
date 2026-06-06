import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/use_cases/media_tasks/clear_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/analyze_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/delete_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/import_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_media_task_execution_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/reconcile_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/reorder_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/replace_missing_source_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/retry_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_execution_queue_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_or_resume_media_task_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/infrastructure/providers/execution_provider.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';

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

    final result = await ReconcileMediaTasksUseCase(
      repository: repository,
      sourceFileChecker: sourceFileChecker,
      fingerprintReader: fingerprintReader,
    ).call();

    if (result.taskIdsNeedingAnalysis.isNotEmpty) {
      unawaited(analyzeTasksInBackground(result.taskIdsNeedingAnalysis));
    }

    unawaited(syncFfmpegQueueStatus());
    return result.tasks;
  }

  Future<MediaTask> createDraftFromPath(String inputPath) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final resolver = ref.read(mediaKindResolverProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final settingsRepository = ref.read(appSettingsRepositoryProvider);
    final tasks = state.requireValue;
    final task = await ImportMediaTaskUseCase(
      repository: repository,
      mediaKindResolver: resolver,
      fingerprintReader: fingerprintReader,
      settingsRepository: settingsRepository,
      now: DateTime.now,
    ).call(inputPath);

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
    state = AsyncData(replaceMediaTask(tasks, task));
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> replaceMissingSource({
    required String taskId,
    required String newInputPath,
  }) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final resolver = ref.read(mediaKindResolverProvider);
    final sourceFileChecker = ref.read(sourceFileCheckerProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final updatedTask = await ReplaceMissingSourceUseCase(
      repository: repository,
      mediaKindResolver: resolver,
      sourceFileChecker: sourceFileChecker,
      fingerprintReader: fingerprintReader,
    ).call(taskId: taskId, newInputPath: newInputPath);

    state = AsyncData(replaceMediaTask(tasks, updatedTask));
    unawaited(syncFfmpegQueueStatus());
    unawaited(analyzeTaskById(updatedTask.id));
  }

  Future<void> deleteTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final tasks = await DeleteMediaTaskUseCase(
      repository: repository,
      queueRunner: queueRunner,
    ).call(taskId);

    state = AsyncData(tasks);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> retryTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final sourceFileChecker = ref.read(sourceFileCheckerProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final result = await RetryMediaTaskUseCase(
      repository: repository,
      sourceFileChecker: sourceFileChecker,
      fingerprintReader: fingerprintReader,
    ).call(taskId);

    state = AsyncData(replaceMediaTask(tasks, result.task));
    unawaited(syncFfmpegQueueStatus());
    if (result.shouldAnalyze) {
      unawaited(analyzeTaskById(taskId));
    }
  }

  Future<void> clearTasks() async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final tasks = await ClearMediaTasksUseCase(
      repository: repository,
      queueRunner: queueRunner,
    ).call();

    state = AsyncData(tasks);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> applySettingsToExistingTasks(AppSettings settings) async {
    if (!state.hasValue) {
      return;
    }

    final repository = ref.read(mediaTaskRepositoryProvider);
    final tasks = state.requireValue;

    for (final task in tasks) {
      if (task.status != TaskStatus.pending &&
          task.status != TaskStatus.failed &&
          task.status != TaskStatus.cancelled) {
        continue;
      }

      final newConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: task.fileName,
        mediaKind: task.mediaKind,
        settings: settings,
        now: DateTime.now(),
      );
      final updatedTask = task.copyWith(config: newConfig);
      await repository.saveTask(updatedTask);
    }

    await refreshTasksFromRepository();
    unawaited(syncFfmpegQueueStatus());
  }

  Future<FfmpegQueueStartResult> startExecutionQueue({
    bool allowExtremeCompression = false,
  }) async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await StartExecutionQueueUseCase(
      queueRunner: queueRunner,
    ).call(allowExtremeCompression: allowExtremeCompression);

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
    final result = await StartOrResumeMediaTaskUseCase(
      queueRunner: queueRunner,
    ).call(taskId, allowExtremeCompression: allowExtremeCompression);

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
    final result = await PauseMediaTaskExecutionUseCase(
      queueRunner: queueRunner,
    ).call(taskId);

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
    final reorderedTasks = await ReorderMediaTasksUseCase(
      repository: repository,
    ).call(oldIndex: oldIndex, newIndex: newIndex);

    state = AsyncData(reorderedTasks);
    unawaited(syncFfmpegQueueStatus());
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
    final mediaInputPreparer = ref.read(mediaInputPreparerProvider);

    final updatedTask = await AnalyzeMediaTaskUseCase(
      repository: repository,
      analyzer: analyzer,
      sourceFileChecker: sourceFileChecker,
      readRuntime: () => ref.read(ffmpegRuntimeProvider.future),
      refreshRuntime: () => ref.refresh(ffmpegRuntimeProvider.future),
      mediaInputPreparer: mediaInputPreparer,
    ).call(taskId);

    if (updatedTask != null && state.hasValue) {
      state = AsyncData(replaceMediaTask(state.requireValue, updatedTask));
    }
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> syncFfmpegQueueStatus() async {
    await ref.read(ffmpegTaskQueueRunnerProvider).refreshStatus();
  }
}
