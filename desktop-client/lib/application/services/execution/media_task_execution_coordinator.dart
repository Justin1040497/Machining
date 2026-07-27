import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/execution/execution_queue_result.dart';
import 'package:framelean/application/use_cases/media_tasks/submit_engine_execution_use_case.dart';
import 'package:framelean/domain/library.dart';

/// Routes every product execution request through the FEngine boundary.
///
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

  Future<EngineQueueStartResult> startSingleTask(String taskId) async {
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return const EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.notFound,
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
        return EngineQueueStartResult(
          outcome: EngineQueueStartOutcome.alreadyRunning,
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

  Future<EngineQueueStartResult> pauseTask(String taskId) {
    return _controlTask(taskId, EngineExecutionControlAction.pause);
  }

  Future<EngineQueueStartResult> cancelTask(String taskId) {
    return _controlTask(taskId, EngineExecutionControlAction.cancel);
  }

  Future<EngineQueueStartResult> pauseFolder(String folderId) async {
    final snapshot =
        (await (await _requireGateway()).getEngineSnapshot()).value;
    final activeId = snapshot.executionLane.active?.executionId;
    if (activeId == null) {
      return const EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.noPendingTask,
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
    return const EngineQueueStartResult(
      outcome: EngineQueueStartOutcome.noPendingTask,
      message: '该任务夹没有运行中的 FEngine 任务',
    );
  }

  Future<EngineQueueStartResult> pauseActive() async {
    final snapshot =
        (await (await _requireGateway()).getEngineSnapshot()).value;
    final activeId = snapshot.executionLane.active?.executionId;
    if (activeId == null) {
      return const EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.noPendingTask,
        message: 'FEngine 当前没有运行中的任务',
      );
    }
    return _controlExecutionId(activeId, EngineExecutionControlAction.pause);
  }

  Future<EngineQueueStartResult> pauseAll() => pauseActive();

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

  Future<EngineQueueStartResult> _controlTask(
    String taskId,
    EngineExecutionControlAction action,
  ) async {
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return const EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }
    final projection = await _requireProjectionRepository().loadByTaskId(
      taskId,
    );
    final executionId = projection?.executionId;
    if (executionId == null) {
      return EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.invalidTaskState,
        task: task,
        message: '任务没有可控制的 FEngine execution_id',
      );
    }
    return _controlResult(
      task,
      await (await _requireGateway()).controlExecution(executionId, action),
    );
  }

  Future<EngineQueueStartResult> _controlExecutionId(
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

  Future<EngineQueueStartResult> startWorkbenchQueue() async {
    return _aggregateResults(
      await _submitEngineTasks(await _orderedWorkbenchTasks()),
    );
  }

  Future<EngineQueueStartResult> startFolderQueue(String folderId) async {
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

  EngineQueueStartResult _aggregateResults(
    List<EngineExecutionDispatchResult> results,
  ) {
    if (results.isEmpty) {
      return const EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.noPendingTask,
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
      return EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.queued,
        task: _firstTask(submitted) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (failed.isNotEmpty) {
      return EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.executionFailed,
        task: _firstTask(failed) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (notReady.isNotEmpty) {
      return EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.notReady,
        task: _firstTask(notReady) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (notConfigured.isNotEmpty) {
      return EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.invalidTaskState,
        task: _firstTask(notConfigured) ?? representative,
        message: _batchSummary(results),
      );
    }
    if (notFound.isNotEmpty) {
      return EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.notFound,
        task: _firstTask(notFound) ?? representative,
        message: _batchSummary(results),
      );
    }
    return EngineQueueStartResult(
      outcome: EngineQueueStartOutcome.notReady,
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

EngineQueueStartResult _mapEngineResult(EngineExecutionDispatchResult result) {
  return switch (result.outcome) {
    EngineExecutionDispatchOutcome.submitted ||
    EngineExecutionDispatchOutcome.alreadySubmitting => EngineQueueStartResult(
      outcome: EngineQueueStartOutcome.queued,
      task: result.task,
      message: result.message ?? '任务已提交到 FEngine',
    ),
    EngineExecutionDispatchOutcome.notFound => EngineQueueStartResult(
      outcome: EngineQueueStartOutcome.notFound,
      message: result.message,
    ),
    EngineExecutionDispatchOutcome.notReady ||
    EngineExecutionDispatchOutcome.stale => EngineQueueStartResult(
      outcome: EngineQueueStartOutcome.notReady,
      task: result.task,
      message: result.message,
    ),
    EngineExecutionDispatchOutcome.failed => EngineQueueStartResult(
      outcome: EngineQueueStartOutcome.executionFailed,
      task: result.task,
      message: result.message,
    ),
    EngineExecutionDispatchOutcome.notEngineConfigured =>
      EngineQueueStartResult(
        outcome: EngineQueueStartOutcome.invalidTaskState,
        task: result.task,
        message: result.message,
      ),
  };
}

EngineQueueStartResult _controlResult(
  MediaTask? task,
  EngineOperationResult<EngineExecutionState> result,
) {
  final outcome = switch (result.value) {
    EngineExecutionState.running ||
    EngineExecutionState.resuming => EngineQueueStartOutcome.started,
    EngineExecutionState.pauseRequested ||
    EngineExecutionState.paused => EngineQueueStartOutcome.paused,
    EngineExecutionState.cancelRequested ||
    EngineExecutionState.cancelled => EngineQueueStartOutcome.cancelled,
    EngineExecutionState.completed => EngineQueueStartOutcome.completed,
    EngineExecutionState.failed => EngineQueueStartOutcome.executionFailed,
    EngineExecutionState.queued ||
    EngineExecutionState.preempting ||
    EngineExecutionState.preempted => EngineQueueStartOutcome.queued,
  };
  return EngineQueueStartResult(
    outcome: outcome,
    task: task,
    message: 'FEngine execution 状态：${result.value.name}',
  );
}
