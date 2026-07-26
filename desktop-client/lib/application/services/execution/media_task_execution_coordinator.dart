import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart'
    show FfmpegQueueStartOutcome, FfmpegQueueStartResult;
import 'package:framelean/application/use_cases/media_tasks/submit_engine_execution_use_case.dart';
import 'package:framelean/domain/library.dart';

/// Routes every product execution request through the FEngine boundary.
///
/// The legacy Dart FFmpeg runner remains available to the migration work, but
/// it is deliberately not a dependency of this coordinator. This keeps queue
/// selection and process execution out of the Client while FLL execution is
/// being completed.
class MediaTaskExecutionCoordinator {
  const MediaTaskExecutionCoordinator({
    required this.repository,
    required this.taskFolderRepository,
    required this.submitEngineExecution,
    this.analysisProjectionRepository,
    this.readEngineGateway,
  });

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository? analysisProjectionRepository;
  final TaskFolderRepository taskFolderRepository;
  final EngineExecutionSubmitter submitEngineExecution;
  final Future<EngineLifecycleGateway> Function()? readEngineGateway;

  Future<FfmpegQueueStartResult> startSingleTask(
    String taskId, {
    // Kept at the call boundary until the workbench UI drops the legacy
    // compression-confirmation option. It has no effect on Engine requests.
    bool allowExtremeCompression = false,
  }) async {
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }
    final projectionRepository = analysisProjectionRepository;
    final gatewayReader = readEngineGateway;
    if (projectionRepository == null || gatewayReader == null) {
      return _mapEngineResult(
        await submitEngineExecution(
          taskId,
          priority: EngineWorkPriority.foreground,
        ),
      );
    }
    final projection = await projectionRepository.loadByTaskId(taskId);
    final existingExecutionId = projection?.executionId;
    if (existingExecutionId != null) {
      if (task.status == TaskStatus.paused) {
        return _controlResult(
          task,
          await (await gatewayReader()).controlExecution(
            existingExecutionId,
            EngineExecutionControlAction.resume,
          ),
        );
      }
      if (task.status == TaskStatus.executionQueued) {
        return _controlResult(
          task,
          await (await gatewayReader()).preemptAndStart(existingExecutionId),
        );
      }
      if (task.status == TaskStatus.running ||
          task.status == TaskStatus.preempting ||
          task.status == TaskStatus.resuming) {
        return FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.alreadyRunning,
          task: task,
          message: '任务已经在 FEngine 执行 lane 中',
        );
      }
    }

    final submitted = await submitEngineExecution(
      taskId,
      priority: EngineWorkPriority.foreground,
    );
    final submission = submitted.submission;
    if (submitted.outcome == EngineExecutionDispatchOutcome.submitted &&
        submission != null &&
        submission.state == EngineExecutionState.queued) {
      return _controlResult(
        submitted.task ?? task,
        await (await gatewayReader()).preemptAndStart(submission.executionId),
      );
    }
    return _mapEngineResult(submitted);
  }

  Future<FfmpegQueueStartResult> pauseTask(String taskId) {
    return _controlTask(taskId, EngineExecutionControlAction.pause);
  }

  Future<FfmpegQueueStartResult> cancelTask(String taskId) {
    return _controlTask(taskId, EngineExecutionControlAction.cancel);
  }

  Future<FfmpegQueueStartResult> pauseFolder(String folderId) async {
    final snapshot =
        (await (await _requireGateway()).getEngineSnapshot()).value;
    final activeId = snapshot.executionLane.active?.executionId;
    if (activeId == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.noPendingTask,
        message: 'FEngine 当前没有运行中的任务',
      );
    }
    for (final task in await repository.loadAllTasks()) {
      if (task.folderId != folderId) {
        continue;
      }
      final projection = await _requireProjectionRepository().loadByTaskId(
        task.id,
      );
      if (projection?.executionId == activeId) {
        return pauseTask(task.id);
      }
    }
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.noPendingTask,
      message: '该任务夹没有运行中的 FEngine 任务',
    );
  }

  Future<FfmpegQueueStartResult> pauseActive() async {
    final snapshot =
        (await (await _requireGateway()).getEngineSnapshot()).value;
    final activeId = snapshot.executionLane.active?.executionId;
    if (activeId == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.noPendingTask,
        message: 'FEngine 当前没有运行中的任务',
      );
    }
    return _controlExecutionId(activeId, EngineExecutionControlAction.pause);
  }

  Future<void> cancelAll() async {
    final gateway = await _requireGateway();
    final lane = (await gateway.getEngineSnapshot()).value.executionLane;
    final executionIds = <String>{
      if (lane.active case final active?) active.executionId,
      ...lane.normalWaiting.map((entry) => entry.executionId),
      ...lane.resumeStack.map((entry) => entry.executionId),
      ...lane.userPaused.map((entry) => entry.executionId),
    };
    for (final executionId in executionIds) {
      await gateway.controlExecution(
        executionId,
        EngineExecutionControlAction.cancel,
      );
    }
  }

  Future<FfmpegQueueStartResult> _controlTask(
    String taskId,
    EngineExecutionControlAction action,
  ) async {
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }
    final projection = await _requireProjectionRepository().loadByTaskId(
      taskId,
    );
    final executionId = projection?.executionId;
    if (executionId == null) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: task,
        message: '任务没有可控制的 FEngine execution_id',
      );
    }
    return _controlResult(
      task,
      await (await _requireGateway()).controlExecution(executionId, action),
    );
  }

  Future<FfmpegQueueStartResult> _controlExecutionId(
    String executionId,
    EngineExecutionControlAction action,
  ) async {
    MediaTask? task;
    for (final candidate in await repository.loadAllTasks()) {
      final projection = await _requireProjectionRepository().loadByTaskId(
        candidate.id,
      );
      if (projection?.executionId == executionId) {
        task = candidate;
        break;
      }
    }
    return _controlResult(
      task,
      await (await _requireGateway()).controlExecution(executionId, action),
    );
  }

  EngineAnalysisProjectionRepository _requireProjectionRepository() {
    return analysisProjectionRepository ??
        (throw StateError('FEngine projection repository is not configured'));
  }

  Future<EngineLifecycleGateway> _requireGateway() {
    final reader = readEngineGateway;
    if (reader == null) {
      return Future<EngineLifecycleGateway>.error(
        StateError('FEngine lifecycle gateway is not configured'),
      );
    }
    return reader();
  }

  Future<FfmpegQueueStartResult> startWorkbenchQueue({
    bool allowExtremeCompression = false,
  }) async {
    return _aggregateResults(
      await _submitEngineTasks(await _orderedWorkbenchTasks()),
    );
  }

  Future<FfmpegQueueStartResult> startFolderQueue(
    String folderId, {
    bool allowExtremeCompression = false,
  }) async {
    final tasks = await repository.loadAllTasks();
    final folderTasks =
        tasks.where((task) => task.folderId == folderId).toList()
          ..sort(_compareFolderTasks);
    return _aggregateResults(await _submitEngineTasks(folderTasks));
  }

  Future<List<EngineExecutionDispatchResult>> _submitEngineTasks(
    Iterable<MediaTask> tasks,
  ) async {
    final orderedTasks = tasks.toList(growable: false);
    final submitter = submitEngineExecution;
    if (submitter is EngineExecutionBatchSubmitter) {
      return (submitter as EngineExecutionBatchSubmitter).submitBatch(
        orderedTasks.map((task) => task.id),
        priority: EngineWorkPriority.normal,
      );
    }
    final results = <EngineExecutionDispatchResult>[];
    for (final task in orderedTasks) {
      try {
        // Submit every item, including tasks that have no Engine reference or
        // are still awaiting analysis. The submitter returns a typed reason so
        // batch requests cannot silently discard work.
        results.add(
          await submitEngineExecution(
            task.id,
            priority: EngineWorkPriority.normal,
          ),
        );
      } on Object catch (error) {
        // A single malformed request must not prevent later queue items from
        // reaching FEngine. The production submitter already maps expected
        // failures; this guard isolates unexpected adapter errors as well.
        results.add(
          EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.failed,
            task: task,
            message: '提交到 FEngine 时发生异常：$error',
          ),
        );
      }
    }
    return results;
  }

  Future<List<MediaTask>> _orderedWorkbenchTasks() async {
    final tasks = await repository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final tasksByFolder = <String, List<MediaTask>>{};
    for (final task in tasks) {
      final folderId = task.folderId;
      if (folderId == null) {
        continue;
      }
      tasksByFolder.putIfAbsent(folderId, () => []).add(task);
    }
    for (final folderTasks in tasksByFolder.values) {
      folderTasks.sort(_compareFolderTasks);
    }

    final items = <_ExecutionOrderItem>[
      for (final folder in folders)
        _ExecutionOrderItem.folder(
          sortOrder: folder.sortOrder,
          createdAt: folder.createdAt,
          tasks: tasksByFolder[folder.id] ?? const [],
        ),
      for (final task in tasks.where((task) => task.folderId == null))
        _ExecutionOrderItem.task(task),
    ]..sort(_compareOrderItems);

    return [for (final item in items) ...item.tasks];
  }

  FfmpegQueueStartResult _aggregateResults(
    List<EngineExecutionDispatchResult> results,
  ) {
    if (results.isEmpty) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.noPendingTask,
        message: '当前范围没有可提交到 FEngine 的任务',
      );
    }

    final submitted = results.where(_isSubmitted).toList();
    final failed = results
        .where(
          (result) => result.outcome == EngineExecutionDispatchOutcome.failed,
        )
        .toList();
    final notReady = results
        .where(
          (result) =>
              result.outcome == EngineExecutionDispatchOutcome.notReady ||
              result.outcome == EngineExecutionDispatchOutcome.stale,
        )
        .toList();
    final notConfigured = results
        .where(
          (result) =>
              result.outcome ==
              EngineExecutionDispatchOutcome.notEngineConfigured,
        )
        .toList();
    final notFound = results
        .where(
          (result) => result.outcome == EngineExecutionDispatchOutcome.notFound,
        )
        .toList();

    final representative = _firstTask(results);
    if (submitted.isNotEmpty) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.queued,
        task: _firstTask(submitted) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (failed.isNotEmpty) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.executionFailed,
        task: _firstTask(failed) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (notReady.isNotEmpty) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notReady,
        task: _firstTask(notReady) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (notConfigured.isNotEmpty) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: _firstTask(notConfigured) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (notFound.isNotEmpty) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        task: _firstTask(notFound) ?? representative,
        message: _batchSummary(results),
      );
    }
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
      task: representative,
      message: _batchSummary(results),
    );
  }

  String _batchSummary(List<EngineExecutionDispatchResult> results) {
    final submittedCount = results.where(_isSubmitted).length;
    final failedCount = results
        .where(
          (result) => result.outcome == EngineExecutionDispatchOutcome.failed,
        )
        .length;
    final notReadyCount = results
        .where(
          (result) =>
              result.outcome == EngineExecutionDispatchOutcome.notReady ||
              result.outcome == EngineExecutionDispatchOutcome.stale,
        )
        .length;
    final notConfiguredCount = results
        .where(
          (result) =>
              result.outcome ==
              EngineExecutionDispatchOutcome.notEngineConfigured,
        )
        .length;
    final notFoundCount = results
        .where(
          (result) => result.outcome == EngineExecutionDispatchOutcome.notFound,
        )
        .length;
    final parts = <String>[
      if (submittedCount > 0) '$submittedCount 个任务已提交到 FEngine',
      if (failedCount > 0) '$failedCount 个任务提交失败',
      if (notReadyCount > 0) '$notReadyCount 个任务尚未完成分析或已失效',
      if (notConfiguredCount > 0) '$notConfiguredCount 个任务缺少 FEngine 配置',
      if (notFoundCount > 0) '$notFoundCount 个任务已不存在',
    ];
    final details = results
        .where((result) => !_isSubmitted(result))
        .map(
          (result) =>
              '${result.task?.id ?? 'unknown'}：${result.message ?? _outcomeLabel(result.outcome)}',
        )
        .toList();
    return [...parts, ...details].join('；');
  }
}

bool _isSubmitted(EngineExecutionDispatchResult result) {
  return result.outcome == EngineExecutionDispatchOutcome.submitted ||
      result.outcome == EngineExecutionDispatchOutcome.alreadySubmitting;
}

MediaTask? _firstTask(Iterable<EngineExecutionDispatchResult> results) {
  for (final result in results) {
    final task = result.task;
    if (task != null) {
      return task;
    }
  }
  return null;
}

String _outcomeLabel(EngineExecutionDispatchOutcome outcome) {
  return switch (outcome) {
    EngineExecutionDispatchOutcome.submitted => '已提交到 FEngine',
    EngineExecutionDispatchOutcome.notFound => '找不到任务',
    EngineExecutionDispatchOutcome.notReady => '任务尚未准备好',
    EngineExecutionDispatchOutcome.notEngineConfigured => '任务没有 FEngine 配置',
    EngineExecutionDispatchOutcome.alreadySubmitting => '任务正在提交到引擎',
    EngineExecutionDispatchOutcome.stale => '任务或分析结果已发生变化',
    EngineExecutionDispatchOutcome.failed => '提交失败',
  };
}

int _compareFolderTasks(MediaTask first, MediaTask second) {
  final order = (first.folderSortOrder ?? first.sortOrder).compareTo(
    second.folderSortOrder ?? second.sortOrder,
  );
  return order == 0 ? first.createdAt.compareTo(second.createdAt) : order;
}

int _compareOrderItems(_ExecutionOrderItem first, _ExecutionOrderItem second) {
  final order = first.sortOrder.compareTo(second.sortOrder);
  return order == 0 ? first.createdAt.compareTo(second.createdAt) : order;
}

final class _ExecutionOrderItem {
  const _ExecutionOrderItem._({
    required this.sortOrder,
    required this.createdAt,
    required this.tasks,
  });

  factory _ExecutionOrderItem.task(MediaTask task) {
    return _ExecutionOrderItem._(
      sortOrder: task.sortOrder,
      createdAt: task.createdAt,
      tasks: [task],
    );
  }

  factory _ExecutionOrderItem.folder({
    required int sortOrder,
    required int createdAt,
    required List<MediaTask> tasks,
  }) {
    return _ExecutionOrderItem._(
      sortOrder: sortOrder,
      createdAt: createdAt,
      tasks: tasks,
    );
  }

  final int sortOrder;
  final int createdAt;
  final List<MediaTask> tasks;
}

FfmpegQueueStartResult _mapEngineResult(EngineExecutionDispatchResult result) {
  return switch (result.outcome) {
    EngineExecutionDispatchOutcome.submitted ||
    EngineExecutionDispatchOutcome.alreadySubmitting => FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.queued,
      task: result.task,
      message: result.message ?? '任务已提交到 FEngine',
    ),
    EngineExecutionDispatchOutcome.notFound => FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notFound,
      message: result.message,
    ),
    EngineExecutionDispatchOutcome.notReady ||
    EngineExecutionDispatchOutcome.stale => FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
      task: result.task,
      message: result.message,
    ),
    EngineExecutionDispatchOutcome.failed => FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.executionFailed,
      task: result.task,
      message: result.message,
    ),
    EngineExecutionDispatchOutcome.notEngineConfigured =>
      FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: result.task,
        message: result.message,
      ),
  };
}

FfmpegQueueStartResult _controlResult(
  MediaTask? task,
  EngineOperationResult<EngineExecutionState> result,
) {
  final outcome = switch (result.value) {
    EngineExecutionState.running ||
    EngineExecutionState.resuming => FfmpegQueueStartOutcome.started,
    EngineExecutionState.pauseRequested ||
    EngineExecutionState.paused => FfmpegQueueStartOutcome.paused,
    EngineExecutionState.cancelRequested ||
    EngineExecutionState.cancelled => FfmpegQueueStartOutcome.cancelled,
    EngineExecutionState.completed => FfmpegQueueStartOutcome.completed,
    EngineExecutionState.failed => FfmpegQueueStartOutcome.executionFailed,
    EngineExecutionState.queued ||
    EngineExecutionState.preempting ||
    EngineExecutionState.preempted => FfmpegQueueStartOutcome.queued,
  };
  return FfmpegQueueStartResult(
    outcome: outcome,
    task: task,
    message: 'FEngine execution 状态：${result.value.name}',
  );
}
