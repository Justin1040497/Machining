import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/use_cases/media_tasks/clear_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/analyze_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/delete_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/import_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_all_media_task_executions_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_media_task_execution_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/reconcile_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/reorder_workbench_items_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/replace_missing_source_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/retry_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_execution_queue_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_or_resume_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/task_folder_use_cases.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/providers/input_runtime_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';

/// 工作台任务列表状态
final mediaTaskListProvider =
    AsyncNotifierProvider<MediaTaskListNotifier, List<MediaTask>>(
      MediaTaskListNotifier.new,
    );

final taskFolderListProvider = FutureProvider<List<TaskFolder>>((ref) {
  return ref.watch(taskFolderRepositoryProvider).loadAllFolders();
});

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

    await pruneEmptyTaskFolders();
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

  Future<void> createTaskFoldersForImportedBatch(List<MediaTask> tasks) async {
    if (tasks.length < 2) {
      return;
    }

    final byKind = <String, List<MediaTask>>{};
    for (final task in tasks) {
      byKind.putIfAbsent(task.mediaKind.name, () => []).add(task);
    }

    for (final groupedTasks in byKind.values) {
      if (groupedTasks.length < 2) {
        continue;
      }
      await createTaskFolderFromTaskIds(
        groupedTasks.map((task) => task.id).toList(),
      );
    }
  }

  Future<void> createTaskFolderFromTaskIds(List<String> taskIds) async {
    final result = await CreateTaskFolderFromTasksUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(taskIds: taskIds);

    state = AsyncData(result.tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<List<TaskFolder>> createTaskFoldersFromTaskIds(
    List<String> taskIds,
  ) async {
    final result = await CreateTaskFoldersFromTasksUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(taskIds: taskIds);

    state = AsyncData(result.tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
    return result.folders;
  }

  Future<void> moveTaskToFolder({
    required String taskId,
    required String folderId,
  }) async {
    final tasks = await MoveTaskToFolderUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
    ).call(taskId: taskId, folderId: folderId);
    state = AsyncData(tasks);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> removeTaskFromFolder(String taskId) async {
    final tasks = await RemoveTaskFromFolderUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(taskId);
    await pruneEmptyTaskFolders();
    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> deleteTaskFolder(String folderId) async {
    final tasks = await DeleteTaskFolderUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(folderId);
    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> applyTaskFolderConfig({
    required String folderId,
    required MediaTaskConfig config,
  }) async {
    final result = await ApplyTaskFolderConfigUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(folderId: folderId, config: config);
    state = AsyncData(result.tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> retryTerminalTasksInFolder(String folderId) async {
    final result = await RetryTaskFolderTerminalTasksUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      sourceFileChecker: ref.read(sourceFileCheckerProvider),
      fingerprintReader: ref.read(sourceFileFingerprintReaderProvider),
    ).call(folderId);
    state = AsyncData(result.tasks);
    unawaited(syncFfmpegQueueStatus());
    if (result.taskIdsNeedingAnalysis.isNotEmpty) {
      unawaited(analyzeTasksInBackground(result.taskIdsNeedingAnalysis));
    }
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
    await DeleteMediaTaskUseCase(
      repository: repository,
      queueRunner: queueRunner,
    ).call(taskId);
    await pruneEmptyTaskFolders();

    state = AsyncData(await repository.loadAllTasks());
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> retryTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final sourceFileChecker = ref.read(sourceFileCheckerProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final result = await RetryMediaTaskUseCase(
      repository: repository,
      settingsRepository: ref.read(appSettingsRepositoryProvider),
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
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
      queueRunner: queueRunner,
    ).call();

    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> pruneEmptyTaskFolders() async {
    final deletedFolderIds = await PruneEmptyTaskFoldersUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call();
    if (deletedFolderIds.isNotEmpty) {
      ref.invalidate(taskFolderListProvider);
    }
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

  Future<FfmpegQueueStartResult> startNextTaskInFolder(
    String folderId, {
    bool allowExtremeCompression = false,
  }) async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await StartNextTaskInFolderUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      queueRunner: queueRunner,
    ).call(folderId, allowExtremeCompression: allowExtremeCompression);

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

  Future<FfmpegQueueStartResult> pauseRunningTaskInFolder(
    String folderId,
  ) async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await PauseRunningTaskInFolderUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      queueRunner: queueRunner,
    ).call(folderId);

    await refreshTasksFromRepository();
    if (result.outcome == FfmpegQueueStartOutcome.paused) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<FfmpegQueueStartResult> pauseAllRunningTasks() async {
    final queueRunner = ref.read(ffmpegTaskQueueRunnerProvider);
    final result = await PauseAllMediaTaskExecutionsUseCase(
      queueRunner: queueRunner,
    ).call();

    await refreshTasksFromRepository();
    return result;
  }

  Future<void> refreshTasksFromRepository() async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    state = AsyncData(await repository.loadAllTasks());
  }

  void startExecutionRefreshPolling() {
    executionRefreshTimer?.cancel();
    executionRefreshTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) {
      unawaited(refreshExecutionState(timer));
    });
  }

  Future<void> refreshExecutionState(Timer timer) async {
    if (!state.hasValue) {
      return;
    }

    final repository = ref.read(mediaTaskRepositoryProvider);
    final freshTasks = await repository.loadAllTasks();
    final currentTasks = state.requireValue;

    if (!_taskListHasChanged(currentTasks, freshTasks)) {
      return;
    }

    state = AsyncData(freshTasks);

    final hasActiveTask = freshTasks.any(
      (task) =>
          task.status == TaskStatus.running || task.status == TaskStatus.paused,
    );
    if (!hasActiveTask) {
      timer.cancel();
      executionRefreshTimer = null;
      unawaited(syncFfmpegQueueStatus());
    }
  }

  bool _taskListHasChanged(
    List<MediaTask> oldTasks,
    List<MediaTask> freshTasks,
  ) {
    if (oldTasks.length != freshTasks.length) {
      return true;
    }

    for (var i = 0; i < oldTasks.length; i++) {
      final old = oldTasks[i];
      final fresh = freshTasks[i];
      if (old.id != fresh.id ||
          old.status != fresh.status ||
          old.progress != fresh.progress) {
        return true;
      }
    }

    return false;
  }

  Future<void> reorderTasks({
    required int oldIndex,
    required int newIndex,
  }) async {
    final tasks = await ReorderWorkbenchTopLevelItemsUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(oldIndex: oldIndex, newIndex: newIndex);
    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> reorderFolderTasks({
    required String folderId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final tasks = await ReorderFolderTasksUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
    ).call(folderId: folderId, oldIndex: oldIndex, newIndex: newIndex);
    state = AsyncData(tasks);
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
