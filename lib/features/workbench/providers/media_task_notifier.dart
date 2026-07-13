import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:path/path.dart' as path;

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
  Timer? _analysisRefreshTimer;

  MediaAnalysisQueue get _queue {
    if (_analysisQueue != null) {
      return _analysisQueue!;
    }
    _analysisQueue = ref.read(mediaAnalysisQueueProvider);
    return _analysisQueue!;
  }

  @override
  Future<List<MediaTask>> build() async {
    ref.onDispose(() {
      executionRefreshTimer?.cancel();
      _analysisRefreshTimer?.cancel();
    });

    final repository = ref.watch(mediaTaskRepositoryProvider);
    final sourceFileChecker = ref.watch(sourceFileCheckerProvider);
    final fingerprintReader = ref.watch(sourceFileFingerprintReaderProvider);

    final result = await ReconcileMediaTasksUseCase(
      repository: repository,
      sourceFileChecker: sourceFileChecker,
      fingerprintReader: fingerprintReader,
    ).call();

    // 订阅全局分析队列的状态变化，用于刷新 UI
    _analysisRefreshTimer?.cancel();
    var lastPending = 0;
    var lastAnalyzing = 0;
    _analysisRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        final snapshot = _queue.snapshot;
        final changed = snapshot.pending != lastPending ||
            snapshot.analyzing != lastAnalyzing;
        lastPending = snapshot.pending;
        lastAnalyzing = snapshot.analyzing;
        // 当分析状态稳定（无正在分析的任务但之前有）时，
        // 批量刷新任务列表
        if (changed && snapshot.analyzing == 0) {
          unawaited(refreshTasksFromRepository());
        }
      },
    );

    if (result.taskIdsNeedingAnalysis.isNotEmpty) {
      _queue.enqueueAll(result.taskIdsNeedingAnalysis);
    }

    await pruneEmptyTaskFolders();
    unawaited(syncFfmpegQueueStatus());
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
    unawaited(syncFfmpegQueueStatus());
    if (analyzeInBackground) {
      _queue.enqueue(task.id);
    }
    return task;
  }

  Future<List<MediaTask>> createDraftsFromPaths(List<String> inputPaths) async {
    final repository = ref.read(mediaTaskRepositoryProvider);
    final mediaKindResolver = ref.read(mediaKindResolverProvider);
    final fingerprintReader = ref.read(sourceFileFingerprintReaderProvider);
    final settingsRepository = ref.read(appSettingsRepositoryProvider);

    // 批量导入：一次性读取设置和现有任务，避免每个文件都重复读取
    final settings = await settingsRepository.loadSettings();
    final existingTasks = await repository.loadAllTasks();
    var currentSortOrder = nextMediaTaskSortOrder(existingTasks);
    final createdTasks = <MediaTask>[];
    final now = DateTime.now();

    for (final inputPath in inputPaths) {
      if (inputPath.trim().isEmpty) {
        continue;
      }

      final mediaKind = mediaKindResolver.resolve(inputPath);
      try {
        ensureSupportedImportedMediaKind(mediaKind);
      } on Object {
        continue; // 跳过不支持的媒体类型
      }

      final fingerprint = await fingerprintReader.read(inputPath);
      final fileName = path.basename(inputPath);
      final version = processingVersionForTask(
        tasks: existingTasks,
        inputPath: inputPath,
        mediaKind: mediaKind,
        purpose: TaskPurpose.compression,
      );
      final initialConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: fileName,
        mediaKind: mediaKind,
        settings: settings,
        now: now,
        version: version,
      );

      final task =
          MediaTask.draft(
                inputPath: inputPath,
                fileName: fileName,
                mediaKind: mediaKind,
                sortOrder: currentSortOrder,
                config: initialConfig,
              )
              .withSourceFileFingerprint(fingerprint)
              .copyWith(status: TaskStatus.analyzing);

      createdTasks.add(task);
      existingTasks.add(task);
      currentSortOrder++;
    }

    // 单事务批量写入所有任务
    if (createdTasks.isNotEmpty) {
      await repository.insertTasks(createdTasks);
    }

    await createTaskFoldersForImportedBatch(createdTasks);
    if (createdTasks.isNotEmpty) {
      _queue.enqueueAll(createdTasks.map((task) => task.id).toList());
    }

    return createdTasks;
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
    ).call(folderPath: folderPath, scanDepth: settings.folderImportScanDepth);

    state = AsyncData(
      await ref.read(mediaTaskRepositoryProvider).loadAllTasks(),
    );
    ref.invalidate(taskFolderListProvider);
    unawaited(syncFfmpegQueueStatus());
    if (result.createdTasks.isNotEmpty) {
      _queue.enqueueAll(
        result.createdTasks.map((task) => task.id).toList(),
      );
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
    unawaited(syncFfmpegQueueStatus());
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
      _queue.enqueueAll(result.taskIdsNeedingAnalysis);
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
    _queue.enqueue(updatedTask.id);
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
      _queue.enqueue(taskId);
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
    executionRefreshTimer = Timer.periodic(executionRefreshInterval, (
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
    // 所有分析现已统一路由到全局 MediaAnalysisQueue，
    // 此处保留方法签名以兼容外部调用者（如 WorkbenchImportHandler）。
    _queue.enqueueAll(taskIds);
  }

  Future<void> analyzeTaskById(String taskId) async {
    // 所有分析现已统一路由到全局 MediaAnalysisQueue。
    _queue.enqueue(taskId);
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
    unawaited(syncFfmpegQueueStatus());
  }

  Future<void> syncFfmpegQueueStatus() async {
    await ref.read(ffmpegTaskQueueRunnerProvider).refreshStatus();
  }
}
