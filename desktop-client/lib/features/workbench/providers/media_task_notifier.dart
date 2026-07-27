import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';

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
  MediaAnalysisQueue? _analysisQueue;

  MediaAnalysisQueue get _queue {
    if (_analysisQueue != null) {
      return _analysisQueue!;
    }
    final queue = ref.read(mediaAnalysisQueueProvider);
    queue.onEntryStateChanged = (entry) {
      unawaited(refreshAnalysisTaskState(entry.taskId));
    };
    _analysisQueue = queue;
    return _analysisQueue!;
  }

  @override
  Future<List<MediaTask>> build() async {
    ref.onDispose(() {
      executionRefreshTimer?.cancel();
      if (_analysisQueue case final queue?) {
        queue.onEntryStateChanged = null;
      }
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
      _enqueueAnalyses(result.taskIdsNeedingAnalysis);
    }

    await pruneEmptyTaskFolders();
    unawaited(syncEngineQueueStatus());
    return result.tasks;
  }

  Future<MediaTask> createDraftFromPath(
    String inputPath, {
    bool analyzeInBackground = true,
  }) async {
    final task = await _createImportedDraft(inputPath);
    final repository = ref.read(mediaTaskRepositoryProvider);
    final folderRepository = ref.read(taskFolderRepositoryProvider);
    await PlaceWorkbenchTopLevelItemUseCase(
      mediaTaskRepository: repository,
      taskFolderRepository: folderRepository,
    ).call(WorkbenchInsertedItem.task(task.id));

    state = AsyncData(await repository.loadAllTasks());
    unawaited(syncEngineQueueStatus());
    if (analyzeInBackground) {
      _enqueueAnalyses([task.id]);
    }
    return task;
  }

  Future<List<MediaTask>> createDraftsFromPaths(List<String> inputPaths) async {
    final createdTasks = await ImportMediaTasksUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      mediaKindResolver: ref.read(mediaKindResolverProvider),
      fingerprintReader: ref.read(sourceFileFingerprintReaderProvider),
      settingsRepository: ref.read(appSettingsRepositoryProvider),
      now: DateTime.now,
    ).call(inputPaths, skipUnsupported: true, persist: false);
    if (createdTasks.isEmpty) {
      return createdTasks;
    }
    final organized = await OrganizeImportedMediaBatchAtomicallyUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
      persistence: ref.read(importedMediaBatchPersistenceProvider),
    ).call(createdTasks);
    state = AsyncData(organized.allTasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
    _enqueueAnalyses(organized.orderedImportedTaskIds);
    return organized.createdTasks;
  }

  Future<MediaTask> _createImportedDraft(String inputPath) {
    return ImportMediaTaskUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      mediaKindResolver: ref.read(mediaKindResolverProvider),
      fingerprintReader: ref.read(sourceFileFingerprintReaderProvider),
      settingsRepository: ref.read(appSettingsRepositoryProvider),
      now: DateTime.now,
    ).call(inputPath);
  }

  Future<ImportMediaFolderResult> importFolderFromPath(
    String folderPath,
  ) async {
    final settings = await ref
        .read(appSettingsRepositoryProvider)
        .loadSettings();
    final result = await ImportMediaFolderUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
      mediaKindResolver: ref.read(mediaKindResolverProvider),
      fingerprintReader: ref.read(sourceFileFingerprintReaderProvider),
      settingsRepository: ref.read(appSettingsRepositoryProvider),
      folderScanner: ref.read(mediaFolderScannerProvider),
      now: DateTime.now,
      batchPersistence: ref.read(importedMediaBatchPersistenceProvider),
    ).call(folderPath: folderPath, scanDepth: settings.folderImportScanDepth);

    state = AsyncData(
      await ref.read(mediaTaskRepositoryProvider).loadAllTasks(),
    );
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
    if (result.createdTasks.isNotEmpty) {
      _enqueueAnalyses(result.createdTasks.map((task) => task.id));
    }
    return result;
  }

  Future<void> createTaskFoldersForImportedBatch(List<MediaTask> tasks) async {
    if (tasks.isEmpty) {
      return;
    }

    final result = await OrganizeImportedMediaBatchUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(taskIds: tasks.map((task) => task.id).toList());
    state = AsyncData(result.tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
  }

  Future<void> createTaskFolderFromTaskIds(List<String> taskIds) async {
    final result = await CreateTaskFolderFromTasksUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(taskIds: taskIds);

    state = AsyncData(result.tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
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
    unawaited(syncEngineQueueStatus());
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
    unawaited(syncEngineQueueStatus());
  }

  Future<void> removeTaskFromFolder(String taskId) async {
    final tasks = await RemoveTaskFromFolderUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(taskId);
    await pruneEmptyTaskFolders();
    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    await _applyEngineQueueOrder(tasks);
    unawaited(syncEngineQueueStatus());
  }

  Future<void> deleteTaskFolder(String folderId) async {
    final tasks = await DeleteTaskFolderUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call(folderId);
    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
  }

  Future<void> renameTaskFolder({
    required String folderId,
    required String name,
  }) async {
    await RenameTaskFolderUseCase(
      repository: ref.read(taskFolderRepositoryProvider),
    ).call(folderId: folderId, name: name);
    ref.invalidate(taskFolderListProvider);
  }

  Future<void> applyTaskFolderConfig({
    required String folderId,
    required MediaTaskConfig config,
    required TaskPurpose purpose,
  }) async {
    final result = await ApplyTaskFolderConfigUseCase(
      mediaTaskRepository: ref.read(mediaTaskRepositoryProvider),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
      appSettingsRepository: ref.read(appSettingsRepositoryProvider),
    ).call(folderId: folderId, config: config, purpose: purpose);
    state = AsyncData(result.tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
  }

  Future<void> retryTerminalTasksInFolder(String folderId) async {
    final result = await RetryTaskFolderTerminalTasksUseCase(
      repository: ref.read(mediaTaskRepositoryProvider),
      sourceFileChecker: ref.read(sourceFileCheckerProvider),
      fingerprintReader: ref.read(sourceFileFingerprintReaderProvider),
    ).call(folderId);
    state = AsyncData(result.tasks);
    unawaited(syncEngineQueueStatus());
    if (result.taskIdsNeedingAnalysis.isNotEmpty) {
      _enqueueAnalyses(result.taskIdsNeedingAnalysis);
    }
  }

  Future<void> saveTask(
    MediaTask task, {
    bool recoverFromConfigurationFailure = false,
  }) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final tasks = state.requireValue;
    final recoveryAction = task.failure?.recoveryAction;
    final savedTask =
        recoverFromConfigurationFailure &&
            task.status == TaskStatus.executionFailed &&
            (recoveryAction == TaskRecoveryAction.editConfiguration ||
                recoveryAction == TaskRecoveryAction.chooseOutputDirectory)
        ? task.markPendingForRetry()
        : task;

    await repository.saveTask(savedTask);
    state = AsyncData(replaceMediaTask(tasks, savedTask));
    unawaited(syncEngineQueueStatus());
  }

  Future<MediaTask> saveEngineTaskConfiguration({
    required String taskId,
    required String analysisId,
    required int analysisRevision,
    required EngineConfigurationSelection selection,
  }) async {
    final resolvedTask =
        await SaveEngineTaskConfigurationUseCase(
          repository: ref.read(mediaTaskRepositoryProvider),
          analysisProjectionRepository: ref.read(
            engineAnalysisProjectionRepositoryProvider,
          ),
        ).call(
          taskId: taskId,
          analysisId: analysisId,
          analysisRevision: analysisRevision,
          selection: selection,
        );
    if (resolvedTask == null) {
      throw StateError('任务已不存在，配置未保存。');
    }

    // The use case returns the repository's latest task when its generation
    // changed while resolving. Reflect that latest task in the list before
    // rejecting the stale selection so the in-memory projection cannot lag
    // behind the persisted task.
    if (state.hasValue) {
      state = AsyncData(replaceMediaTask(state.requireValue, resolvedTask));
    }

    final reference = resolvedTask.config.engineConfiguration;
    if (reference == null ||
        reference.analysisId != analysisId ||
        reference.analysisRevision != analysisRevision ||
        reference.candidateId != selection.candidateId) {
      throw StateError('任务或分析结果已发生变化，配置未保存。');
    }

    return resolvedTask;
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
      analysisProjectionRepository: ref.read(
        engineAnalysisProjectionRepositoryProvider,
      ),
      mediaKindResolver: resolver,
      sourceFileChecker: sourceFileChecker,
      fingerprintReader: fingerprintReader,
    ).call(taskId: taskId, newInputPath: newInputPath);

    state = AsyncData(replaceMediaTask(tasks, updatedTask));
    unawaited(syncEngineQueueStatus());
    _enqueueAnalyses([updatedTask.id]);
  }

  Future<void> deleteTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    await ref.read(mediaTaskExecutionCoordinatorProvider).cancelTask(taskId);
    await DeleteMediaTaskUseCase(
      repository: repository,
      analysisProjectionRepository: ref.read(
        engineAnalysisProjectionRepositoryProvider,
      ),
    ).call(taskId);
    await pruneEmptyTaskFolders();

    state = AsyncData(await repository.loadAllTasks());
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
  }

  Future<void> retryTaskById(String taskId) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final sourceFileChecker = ref.read(sourceFileCheckerProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final tasks = state.requireValue;
    final result = await RetryMediaTaskUseCase(
      repository: repository,
      settingsRepository: ref.read(appSettingsRepositoryProvider),
      analysisProjectionRepository: ref.read(
        engineAnalysisProjectionRepositoryProvider,
      ),
      sourceFileChecker: sourceFileChecker,
      fingerprintReader: fingerprintReader,
    ).call(taskId);

    state = AsyncData(replaceMediaTask(tasks, result.task));
    unawaited(syncEngineQueueStatus());
    if (result.shouldAnalyze) {
      _enqueueAnalyses([taskId]);
    }
  }

  Future<void> clearTasks() async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    await ref.read(mediaTaskExecutionCoordinatorProvider).cancelAll();
    final tasks = await ClearMediaTasksUseCase(
      repository: repository,
      analysisProjectionRepository: ref.read(
        engineAnalysisProjectionRepositoryProvider,
      ),
      taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    ).call();

    state = AsyncData(tasks);
    ref.invalidate(taskFolderListProvider);
    unawaited(syncEngineQueueStatus());
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

  Future<EngineQueueStartResult> startExecutionQueue() async {
    final result = await StartExecutionQueueUseCase(
      executionCoordinator: ref.read(mediaTaskExecutionCoordinatorProvider),
    ).call();

    await refreshTasksFromRepository();
    if (result.outcome == EngineQueueStartOutcome.started ||
        result.outcome == EngineQueueStartOutcome.resumed ||
        result.outcome == EngineQueueStartOutcome.alreadyRunning) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<EngineQueueStartResult> startOrResumeTaskById(String taskId) async {
    final result = await StartOrResumeMediaTaskUseCase(
      executionCoordinator: ref.read(mediaTaskExecutionCoordinatorProvider),
    ).call(taskId);

    await refreshTasksFromRepository();
    if (result.outcome == EngineQueueStartOutcome.started ||
        result.outcome == EngineQueueStartOutcome.resumed ||
        result.outcome == EngineQueueStartOutcome.alreadyRunning) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<EngineQueueStartResult> startNextTaskInFolder(String folderId) async {
    final result = await StartNextTaskInFolderUseCase(
      executionCoordinator: ref.read(mediaTaskExecutionCoordinatorProvider),
    ).call(folderId);

    await refreshTasksFromRepository();
    if (result.outcome == EngineQueueStartOutcome.started ||
        result.outcome == EngineQueueStartOutcome.resumed ||
        result.outcome == EngineQueueStartOutcome.alreadyRunning) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<EngineQueueStartResult> pauseTaskById(String taskId) async {
    final result = await ref
        .read(mediaTaskExecutionCoordinatorProvider)
        .pauseTask(taskId);

    await refreshTasksFromRepository();
    if (result.outcome == EngineQueueStartOutcome.paused) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<EngineQueueStartResult> pauseRunningTaskInFolder(
    String folderId,
  ) async {
    final result = await ref
        .read(mediaTaskExecutionCoordinatorProvider)
        .pauseFolder(folderId);

    await refreshTasksFromRepository();
    if (result.outcome == EngineQueueStartOutcome.paused) {
      startExecutionRefreshPolling();
    }

    return result;
  }

  Future<EngineQueueStartResult> pauseAllRunningTasks() async {
    final result = await ref
        .read(mediaTaskExecutionCoordinatorProvider)
        .pauseActive();

    await refreshTasksFromRepository();
    return result;
  }

  Future<void> refreshTasksFromRepository() async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    state = AsyncData(await repository.loadAllTasks());
  }

  void startExecutionRefreshPolling() {
    executionRefreshTimer?.cancel();
    executionRefreshTimer = Timer.periodic(executionRefreshInterval, (timer) {
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
      unawaited(syncEngineQueueStatus());
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
    await _applyEngineQueueOrder(tasks);
    unawaited(syncEngineQueueStatus());
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
    await _applyEngineQueueOrder(tasks);
    unawaited(syncEngineQueueStatus());
  }

  Future<void> _applyEngineQueueOrder(List<MediaTask> tasks) async {
    final gateway = await ref.read(engineGatewayProvider.future);
    await ApplyEngineQueueOrderUseCase(
      gateway: gateway,
      projectionRepository: ref.read(
        engineAnalysisProjectionRepositoryProvider,
      ),
      orderRevisionStore: ref.read(workbenchOrderRevisionStoreProvider),
    ).call(
      tasks: tasks,
      folders: await ref.read(taskFolderRepositoryProvider).loadAllFolders(),
    );
  }

  Future<void> analyzeTasksInBackground(List<String> taskIds) async {
    // 所有分析现已统一路由到全局 MediaAnalysisQueue，
    // 此处保留方法签名以兼容外部调用者（如 WorkbenchImportHandler）。
    _enqueueAnalyses(taskIds);
  }

  Future<void> analyzeTaskById(String taskId) async {
    // 所有分析现已统一路由到全局 MediaAnalysisQueue。
    _enqueueAnalyses([taskId]);
  }

  void _enqueueAnalyses(Iterable<String> taskIds) {
    final ids = taskIds.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    unawaited(_submitAnalysisBatchAndTrack(ids));
  }

  Future<void> _submitAnalysisBatchAndTrack(List<String> taskIds) async {
    late final List<String> accepted;
    try {
      accepted = await SubmitEngineAnalysisBatchUseCase(
        repository: ref.read(mediaTaskRepositoryProvider),
        projectionRepository: ref.read(
          engineAnalysisProjectionRepositoryProvider,
        ),
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
      ).call(taskIds);
    } on StateError catch (error) {
      if (!error.toString().contains('不支持原子批量分析提交')) {
        await _recordAnalysisBatchFailure(taskIds, error);
        return;
      }
      // Compatibility-only gateways can still use the established per-task
      // request path. The production LocalFEngineGateway always supports the
      // atomic batch command.
      accepted = taskIds;
    } on Object catch (error) {
      // A transport failure has an unknown commit result. Never resubmit the
      // children individually: doing so could duplicate work that FEngine
      // already accepted before the connection was interrupted.
      await _recordAnalysisBatchFailure(taskIds, error);
      return;
    }
    if (!ref.mounted) {
      return;
    }
    _queue.enqueueAll(accepted);
    unawaited(_refreshWhenAnalysisQueueIsIdle());
  }

  Future<void> _recordAnalysisBatchFailure(
    List<String> taskIds,
    Object error,
  ) async {
    if (!ref.mounted) {
      return;
    }
    final repository = ref.read(mediaTaskRepositoryProvider);
    final occurredAt = DateTime.now().millisecondsSinceEpoch;
    for (final taskId in taskIds) {
      final task = await repository.loadTaskById(taskId);
      if (!ref.mounted) {
        return;
      }
      if (task == null ||
          (task.status != TaskStatus.awaitAnalysis &&
              task.status != TaskStatus.analysisQueued)) {
        continue;
      }
      await repository.saveTask(
        task.markAnalysisFailed(
          TaskFailure(
            stage: TaskFailureStage.analysis,
            code: TaskFailureCode.analysisRuntimeUnavailable,
            userMessage: '分析批次未能确认进入媒体引擎，请重试。',
            technicalSummary: error.toString(),
            occurredAt: occurredAt,
            retryable: true,
          ),
        ),
      );
    }
    if (ref.mounted && state.hasValue) {
      await refreshTasksFromRepository();
    }
  }

  Future<void> _refreshWhenAnalysisQueueIsIdle() async {
    await _queue.waitForCompletion();
    if (!ref.mounted || !state.hasValue) {
      return;
    }
    await refreshTasksFromRepository();
  }

  /// 分析完成后刷新任务列表中的单个任务状态。
  /// 由 MediaAnalysisQueue.onEntryStateChanged 回调触发，
  /// 使用 loadTaskById 精确更新，避免全量 loadAllTasks。
  Future<void> refreshAnalysisTaskState(String taskId) async {
    if (!state.hasValue) {
      return;
    }
    final repository = ref.read(mediaTaskRepositoryProvider);
    final updatedTask = await repository.loadTaskById(taskId);
    if (updatedTask != null) {
      state = AsyncData(replaceMediaTask(state.requireValue, updatedTask));
    }
    unawaited(syncEngineQueueStatus());
  }

  Future<void> syncEngineQueueStatus() async {
    await ref.read(engineLifecycleCoordinatorProvider.future);
  }
}
