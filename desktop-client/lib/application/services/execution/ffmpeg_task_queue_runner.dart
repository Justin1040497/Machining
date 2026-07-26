import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/execution_slot_coordinator.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/execution/execution_resource_guard.dart';
import 'package:framelean/application/services/execution/media_work_scheduler.dart';
import 'package:framelean/application/services/execution/output_failure.dart';
import 'package:framelean/application/services/execution/output_preflight_service.dart';
import 'package:framelean/application/services/execution/task_execution_notification_summary.dart';
import 'package:framelean/application/services/execution/task_process_lifecycle.dart';
import 'package:framelean/application/services/execution/task_result_finalizer.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/engine/task_folder_queue_projection.dart';
import 'package:framelean/application/constants.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as path;

export 'package:framelean/application/services/execution/task_process_lifecycle.dart'
    show TaskExecution, TaskExecutionState;

enum FfmpegQueueStatus { idle, ready, running }

enum FfmpegQueueStartOutcome {
  started,
  resumed,
  paused,
  cancelled,
  notFound,
  invalidTaskState,
  notReady,
  alreadyRunning,
  noPendingTask,
  missingSource,
  ffmpegUnavailable,
  compressionConfirmationRequired,
  commandBuildFailed,
  processStartFailed,
  queued,
  throttled,
  completed,
  executionFailed,
}

enum ExecutionScopeType { none, workbench, folder }

class ExecutionScope {
  const ExecutionScope._(this.type, this.folderId);

  const ExecutionScope.none() : this._(ExecutionScopeType.none, null);

  const ExecutionScope.workbench() : this._(ExecutionScopeType.workbench, null);

  const ExecutionScope.folder(String folderId)
    : this._(ExecutionScopeType.folder, folderId);

  final ExecutionScopeType type;
  final String? folderId;

  bool get isContinuous => type != ExecutionScopeType.none;
}

class FfmpegQueueStartResult {
  final FfmpegQueueStartOutcome outcome;
  final MediaTask? task;
  final String? message;

  const FfmpegQueueStartResult({
    required this.outcome,
    this.task,
    this.message,
  });
}

abstract class FfmpegTaskQueueRunner {
  FfmpegQueueStatus get queueStatus;

  String? get foregroundTaskId;

  Set<String> get runningTaskIds;

  int get activeExecutionCount;

  int get effectiveMaxConcurrentExecutions;

  ExecutionScope get executionScope;

  Future<FfmpegQueueStatus> refreshStatus();

  Future<FfmpegQueueStartResult> startWorkbenchQueue({
    bool allowExtremeCompression = false,
  });

  Future<FfmpegQueueStartResult> startFolderQueue(
    String folderId, {
    bool allowExtremeCompression = false,
  });

  Future<FfmpegQueueStartResult> startSingleTask(
    String taskId, {
    bool allowExtremeCompression = false,
  });

  Future<FfmpegQueueStartResult> pauseTask(String taskId);

  Future<FfmpegQueueStartResult> pauseFolderQueue(String folderId);

  Future<FfmpegQueueStartResult> pauseAllRunningTasks();

  Future<FfmpegQueueStartResult> cancelTask(String taskId);

  Future<void> cancelAllExecutions();

  void requestQueueRefill();

  Future<void> dispose();
}

class DefaultFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  final MediaTaskRepository repository;
  final TaskFolderRepository taskFolderRepository;
  final SourceFileChecker sourceFileChecker;
  final Future<AppSettings> Function() readSettings;
  final Future<ResolvedFfmpegRuntime> Function() readRuntime;
  final FfmpegCommandBuilder commandBuilder;
  final ExecutionResourceGuard resourceGuard;
  final MediaWorkScheduler? workScheduler;
  final MediaInputPreparer mediaInputPreparer;
  final OutputPreflightService outputPreflightService;
  final FfmpegProcessStarter processStarter;
  final FfmpegProcessController processController;
  final FfmpegProcessObserver processObserver;
  final bool continuousExecutionEnabled;
  final Future<DateTime> Function() now;
  final Future<String> Function(MediaTask task, FfmpegCommandPlan plan)
  createLogFilePath;
  final Future<void> Function(
    MediaTask task, [
    TaskExecutionNotificationSummary? summary,
  ])?
  onTaskCompleted;
  final Future<void> Function(
    MediaTask task, [
    TaskExecutionNotificationSummary? summary,
  ])?
  onTaskFailed;

  final Map<String, TaskExecution> _executions = {};
  FfmpegQueueStatus _queueStatus = FfmpegQueueStatus.idle;
  ExecutionScope _executionScope = const ExecutionScope.none();
  final Queue<String> _preemptedTaskIds = Queue<String>();
  final Set<String> _suppressedTaskIds = {};
  Future<void> _commandTail = Future<void>.value();
  late final ExecutionSlotCoordinator _slotCoordinator;
  late final TaskProcessLifecycle _processLifecycle;
  late final TaskResultFinalizer _resultFinalizer;
  bool _disposed = false;
  bool _allowExtremeCompressionForScope = false;
  int _nextRunSequenceValue = 0;
  int _effectiveMaxConcurrentExecutions = defaultMaxConcurrentExecutions;

  /// 每个任务上次进度持久化的时间戳（毫秒），用于数据库写入节流。
  final Map<String, int> _lastProgressPersistMs = {};

  DefaultFfmpegTaskQueueRunner({
    required this.repository,
    required this.taskFolderRepository,
    required this.sourceFileChecker,
    required this.readSettings,
    required this.readRuntime,
    required this.commandBuilder,
    required this.resourceGuard,
    this.workScheduler,
    this.mediaInputPreparer = const NoopMediaInputPreparer(),
    this.outputPreflightService = const NoopOutputPreflightService(),
    required this.processStarter,
    required this.processController,
    required this.processObserver,
    required this.createLogFilePath,
    this.onTaskCompleted,
    this.onTaskFailed,
    this.continuousExecutionEnabled = true,
    Future<DateTime> Function()? now,
  }) : now = now ?? (() async => DateTime.now()) {
    _processLifecycle = TaskProcessLifecycle(processController);
    _resultFinalizer = TaskResultFinalizer(
      repository: repository,
      outputPreflightService: outputPreflightService,
      now: this.now,
    );
    _slotCoordinator = ExecutionSlotCoordinator(
      scheduler: workScheduler,
      canRefill: () =>
          !_disposed &&
          continuousExecutionEnabled &&
          (_executionScope.isContinuous || _preemptedTaskIds.isNotEmpty),
      refill: () => _serializeCommand(_continueAfterTask),
    );
  }

  @override
  FfmpegQueueStatus get queueStatus => _queueStatus;

  @override
  String? get foregroundTaskId =>
      runningTaskIds.isEmpty ? null : runningTaskIds.first;

  @override
  Set<String> get runningTaskIds => {
    for (final execution in _executions.values)
      if (execution.state == TaskExecutionState.running) execution.taskId,
  };

  @override
  int get activeExecutionCount => runningTaskIds.length;

  @override
  int get effectiveMaxConcurrentExecutions => _effectiveMaxConcurrentExecutions;

  @override
  ExecutionScope get executionScope => _executionScope;

  @override
  Future<FfmpegQueueStatus> refreshStatus() async {
    final tasks = await repository.loadAllTasks();
    _queueStatus = resolveQueueStatus(tasks);
    return _queueStatus;
  }

  @override
  void requestQueueRefill() {
    _slotCoordinator.requestRefill();
  }

  @override
  Future<FfmpegQueueStartResult> startWorkbenchQueue({
    bool allowExtremeCompression = false,
  }) {
    return _serializeCommand(() async {
      _executionScope = const ExecutionScope.workbench();
      _allowExtremeCompressionForScope = allowExtremeCompression;
      _preemptedTaskIds.clear();
      _suppressedTaskIds.clear();
      return _startContinuousQueue(
        allowExtremeCompression: allowExtremeCompression,
      );
    });
  }

  Future<FfmpegQueueStartResult> start({bool allowExtremeCompression = false}) {
    return startWorkbenchQueue(
      allowExtremeCompression: allowExtremeCompression,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startFolderQueue(
    String folderId, {
    bool allowExtremeCompression = false,
  }) {
    return _serializeCommand(() async {
      _executionScope = ExecutionScope.folder(folderId);
      _allowExtremeCompressionForScope = allowExtremeCompression;
      _preemptedTaskIds.clear();
      _suppressedTaskIds.clear();
      return _startContinuousQueue(
        allowExtremeCompression: allowExtremeCompression,
      );
    });
  }

  @override
  Future<FfmpegQueueStartResult> startSingleTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) {
    return _serializeCommand(
      () => _startSingleTask(
        taskId,
        allowExtremeCompression: allowExtremeCompression,
      ),
    );
  }

  Future<FfmpegQueueStartResult> startOrResumeTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) {
    return startSingleTask(
      taskId,
      allowExtremeCompression: allowExtremeCompression,
    );
  }

  Future<FfmpegQueueStartResult> _startSingleTask(
    String taskId, {
    required bool allowExtremeCompression,
  }) async {
    final tasks = await repository.loadAllTasks();
    final task = findTaskById(tasks, taskId);
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }
    if (task.isAwaitingAnalysis || task.status == TaskStatus.analyzing) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notReady,
        task: task,
        message: '媒体信息尚未分析完成，请稍候',
      );
    }
    if (!isStartableTask(task)) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: task,
        message: '当前任务状态不允许开始',
      );
    }

    final execution = _executions[taskId];
    if (execution?.state == TaskExecutionState.running) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.alreadyRunning,
        task: task,
        message: '任务已经在执行',
      );
    }

    _suppressedTaskIds.remove(taskId);
    _preemptedTaskIds.remove(taskId);
    if (await _hasCapacityFor(task, excludedTaskId: taskId)) {
      return execution == null
          ? startTask(task, allowExtremeCompression: allowExtremeCompression)
          : resumeExecution(task, execution);
    }

    final victim = _oldestRunningExecution(excludedTaskId: taskId);
    if (victim == null) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.throttled,
        task: task,
        message: '当前设备资源不足，无法为该任务腾出执行位',
      );
    }

    final pausedVictim = await _pauseExecution(victim.taskId);
    if (pausedVictim == null) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.throttled,
        task: task,
        message: '最早运行的任务无法暂停，插队未执行',
      );
    }
    _preemptedTaskIds.addLast(victim.taskId);

    if (!await _hasCapacityFor(task, excludedTaskId: taskId)) {
      _preemptedTaskIds.remove(victim.taskId);
      await resumeExecution(pausedVictim, victim);
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.throttled,
        task: task,
        message: '暂停一个任务后资源仍不足，插队未执行',
      );
    }

    final result = execution == null
        ? await startTask(
            task,
            allowExtremeCompression: allowExtremeCompression,
          )
        : await resumeExecution(task, execution);
    if (!_didStart(result)) {
      _preemptedTaskIds.remove(victim.taskId);
      final latestVictim = findTaskById(
        await repository.loadAllTasks(),
        victim.taskId,
      );
      if (latestVictim != null && latestVictim.status == TaskStatus.paused) {
        await resumeExecution(latestVictim, victim);
      }
      return result;
    }

    return FfmpegQueueStartResult(
      outcome: result.outcome,
      task: result.task,
      message:
          '${result.task?.fileName ?? '任务'} 已插队，'
          '${pausedVictim.fileName} 将在执行位空闲后优先恢复',
    );
  }

  bool _didStart(FfmpegQueueStartResult result) {
    return result.outcome == FfmpegQueueStartOutcome.started ||
        result.outcome == FfmpegQueueStartOutcome.resumed ||
        result.outcome == FfmpegQueueStartOutcome.alreadyRunning;
  }

  TaskExecution? _oldestRunningExecution({String? excludedTaskId}) {
    final running =
        _executions.values
            .where(
              (execution) =>
                  execution.taskId != excludedTaskId &&
                  execution.state == TaskExecutionState.running,
            )
            .toList()
          ..sort((a, b) => a.runSequence.compareTo(b.runSequence));
    return running.isEmpty ? null : running.first;
  }

  @override
  Future<FfmpegQueueStartResult> pauseTask(String taskId) {
    return _serializeCommand(() => _pauseTask(taskId));
  }

  Future<FfmpegQueueStartResult> _pauseTask(String taskId) async {
    final execution = _executions[taskId];
    if (execution == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        message: '任务没有可暂停的 FFmpeg 进程',
      );
    }
    if (execution.state == TaskExecutionState.paused) {
      final task = findTaskById(await repository.loadAllTasks(), taskId);
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.paused,
        task: task,
        message: '任务已经处于暂停状态',
      );
    }

    final pausedTask = await _pauseExecution(taskId);
    _preemptedTaskIds.remove(taskId);
    _suppressedTaskIds.add(taskId);
    await _continueAfterTask(excludedTaskId: taskId);
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
      task: pausedTask,
      message: '任务已挂起',
    );
  }

  Future<MediaTask?> _pauseExecution(String taskId) async {
    final execution = _executions[taskId];
    if (execution == null || execution.state != TaskExecutionState.running) {
      return null;
    }
    await _processLifecycle.pause(execution);

    // 暂停时释放活跃编码租约，让其他任务可以使用编码槽位。
    // 暂停进程记录保留，恢复时需要重新申请租约。
    await _releaseSchedulerLease(execution);

    final task = findTaskById(await repository.loadAllTasks(), taskId);
    final pausedTask = task?.markPaused();
    if (pausedTask != null) {
      await repository.saveTask(pausedTask);
    }
    return pausedTask;
  }

  @override
  Future<FfmpegQueueStartResult> pauseFolderQueue(String folderId) {
    return _serializeCommand(() => _pauseFolderQueue(folderId));
  }

  Future<FfmpegQueueStartResult> _pauseFolderQueue(String folderId) async {
    final tasks = await repository.loadAllTasks();
    final folderTaskIds = {
      for (final task in tasks)
        if (task.folderId == folderId) task.id,
    };
    if (_executionScope.type == ExecutionScopeType.folder &&
        _executionScope.folderId == folderId) {
      _executionScope = const ExecutionScope.none();
      _allowExtremeCompressionForScope = false;
    }

    MediaTask? lastPausedTask;
    for (final taskId in folderTaskIds) {
      final paused = await _pauseExecution(taskId);
      if (paused == null) {
        continue;
      }
      _preemptedTaskIds.remove(taskId);
      _suppressedTaskIds.add(taskId);
      lastPausedTask = paused;
    }
    await _continueAfterTask();
    return lastPausedTask == null
        ? const FfmpegQueueStartResult(
            outcome: FfmpegQueueStartOutcome.invalidTaskState,
            message: '任务夹内没有正在执行的任务',
          )
        : FfmpegQueueStartResult(
            outcome: FfmpegQueueStartOutcome.paused,
            task: lastPausedTask,
            message: '任务夹内运行任务已暂停',
          );
  }

  @override
  Future<FfmpegQueueStartResult> pauseAllRunningTasks() {
    return _serializeCommand(_pauseAllRunningTasks);
  }

  Future<FfmpegQueueStartResult> _pauseAllRunningTasks() async {
    _executionScope = const ExecutionScope.none();
    _allowExtremeCompressionForScope = false;
    _preemptedTaskIds.clear();
    _suppressedTaskIds.clear();

    MediaTask? lastPausedTask;
    for (final execution in _executions.values) {
      if (execution.state != TaskExecutionState.running) {
        continue;
      }
      lastPausedTask =
          await _pauseExecution(execution.taskId) ?? lastPausedTask;
    }

    await refreshStatus();
    if (lastPausedTask == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        message: '没有正在执行的任务',
      );
    }
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
      task: lastPausedTask,
      message: '所有正在执行的任务已暂停',
    );
  }

  Future<T> _serializeCommand<T>(Future<T> Function() command) {
    final completer = Completer<T>();
    _commandTail = _commandTail.then((_) async {
      try {
        completer.complete(await command());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<FfmpegQueueStartResult> cancelTask(String taskId) {
    return _serializeCommand(() => _cancelTask(taskId));
  }

  Future<FfmpegQueueStartResult> _cancelTask(String taskId) async {
    final tasks = await repository.loadAllTasks();
    final task = findTaskById(tasks, taskId);
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }

    final execution = _executions.remove(taskId);
    _cleanupTaskTracking(taskId);
    execution?.state = TaskExecutionState.finishing;
    if (execution != null) {
      await _releaseSchedulerLease(execution);
      await _processLifecycle.terminate(execution);
      execution.outputMonitor?.cancel();
      await outputPreflightService.discardPlan(execution.plan);
      await cleanupPlanFiles(execution.plan);
      await mediaInputPreparer.cleanup(execution.preparedInput);
    }

    await appendExecutionLogFooter(
      execution?.logFile,
      success: false,
      message: '任务已取消',
    );

    final cancelledTask = task.markCancelled();
    await repository.saveTask(cancelledTask);
    await _continueAfterTask();
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.cancelled,
      task: cancelledTask,
      message: '任务已取消',
    );
  }

  @override
  Future<void> cancelAllExecutions() {
    return _serializeCommand(_cancelAllExecutions);
  }

  Future<void> _cancelAllExecutions() async {
    _executionScope = const ExecutionScope.none();
    _allowExtremeCompressionForScope = false;
    _preemptedTaskIds.clear();
    _suppressedTaskIds.clear();
    for (final execution in [..._executions.values]) {
      execution.state = TaskExecutionState.finishing;
      await _releaseSchedulerLease(execution);
      await _processLifecycle.terminate(execution);
      execution.outputMonitor?.cancel();
      await outputPreflightService.discardPlan(execution.plan);
      await cleanupPlanFiles(execution.plan);
      await mediaInputPreparer.cleanup(execution.preparedInput);
    }

    _executions.clear();
    _queueStatus = FfmpegQueueStatus.idle;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _slotCoordinator.dispose();
    await cancelAllExecutions();
  }

  Future<FfmpegQueueStartResult> _startContinuousQueue({
    required bool allowExtremeCompression,
  }) async {
    await refreshStatus();
    return fillAvailableSlots(allowExtremeCompression: allowExtremeCompression);
  }

  Future<FfmpegQueueStartResult> fillAvailableSlots({
    bool allowExtremeCompression = false,
    String? excludedTaskId,
  }) async {
    FfmpegQueueStartResult? firstResult;

    while (true) {
      final tasks = await repository.loadAllTasks();
      final folders = await taskFolderRepository.loadAllFolders();
      final runningTasks = _runningTasksFrom(tasks);
      final settings = await readSettings();
      final capacity = await resourceGuard.capacity(
        userMaxConcurrentExecutions: settings.maxConcurrentExecutions,
        runningTasks: runningTasks,
      );
      _effectiveMaxConcurrentExecutions =
          capacity.effectiveMaxConcurrentExecutions;
      if (runningTasks.length >= capacity.effectiveMaxConcurrentExecutions) {
        return firstResult ??
            FfmpegQueueStartResult(
              outcome: FfmpegQueueStartOutcome.throttled,
              message: capacity.reason ?? '当前没有空闲执行位',
            );
      }

      final priorityTask = _nextPreemptedTask(
        tasks,
        excludedTaskId: excludedTaskId,
      );
      if (priorityTask != null) {
        if (!await resourceGuard.canStartTask(
          task: priorityTask,
          runningTasks: runningTasks,
          userMaxConcurrentExecutions: settings.maxConcurrentExecutions,
        )) {
          return firstResult ??
              FfmpegQueueStartResult(
                outcome: FfmpegQueueStartOutcome.queued,
                task: priorityTask,
                message: '插队任务正在等待设备资源空闲',
              );
        }
      }

      final nextTask =
          priorityTask ??
          await _nextScopedStartableTaskAllowed(
            tasks: tasks,
            folders: folders,
            runningTasks: runningTasks,
            userMaxConcurrentExecutions: settings.maxConcurrentExecutions,
            excludedTaskId: excludedTaskId,
          );
      if (nextTask == null) {
        await refreshStatus();
        if (_hasScopedStartableCandidate(
          tasks,
          folders: folders,
          excludedTaskId: excludedTaskId,
        )) {
          return firstResult ??
              const FfmpegQueueStartResult(
                outcome: FfmpegQueueStartOutcome.throttled,
                message: '后续任务正在等待设备资源空闲',
              );
        }
        if (_hasScopedAwaitingAnalysisCandidate(
          tasks,
          folders: folders,
          excludedTaskId: excludedTaskId,
        )) {
          return firstResult ??
              const FfmpegQueueStartResult(
                outcome: FfmpegQueueStartOutcome.queued,
                message: '队列正在等待媒体分析完成',
              );
        }
        if (firstResult != null) {
          return firstResult;
        }
        if (_preemptedTaskIds.isEmpty) {
          _executionScope = const ExecutionScope.none();
          _allowExtremeCompressionForScope = false;
        }
        return const FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.noPendingTask,
          message: '没有找到可执行任务',
        );
      }

      _preemptedTaskIds.remove(nextTask.id);
      final execution = _executions[nextTask.id];
      final result = execution != null
          ? await resumeExecution(nextTask, execution)
          : await startTask(
              nextTask,
              allowExtremeCompression: allowExtremeCompression,
            );
      firstResult ??= result;
      if (result.outcome ==
              FfmpegQueueStartOutcome.compressionConfirmationRequired ||
          result.outcome == FfmpegQueueStartOutcome.commandBuildFailed ||
          result.outcome == FfmpegQueueStartOutcome.ffmpegUnavailable ||
          result.outcome == FfmpegQueueStartOutcome.processStartFailed ||
          result.outcome == FfmpegQueueStartOutcome.queued ||
          result.outcome == FfmpegQueueStartOutcome.throttled) {
        return firstResult;
      }
    }
  }

  List<MediaTask> _runningTasksFrom(
    List<MediaTask> tasks, {
    String? excludedTaskId,
  }) {
    final runningIds = runningTaskIds;
    if (excludedTaskId != null) {
      runningIds.remove(excludedTaskId);
    }
    return [
      for (final task in tasks)
        if (runningIds.contains(task.id)) task,
    ];
  }

  MediaTask? _nextPreemptedTask(
    List<MediaTask> tasks, {
    String? excludedTaskId,
  }) {
    _preemptedTaskIds.removeWhere(
      (taskId) =>
          taskId == excludedTaskId ||
          !tasks.any((task) => task.id == taskId && isStartableTask(task)),
    );
    for (final taskId in _preemptedTaskIds) {
      final task = findTaskById(tasks, taskId);
      if (task != null && isStartableTask(task)) {
        return task;
      }
    }
    return null;
  }

  Future<MediaTask?> _nextScopedStartableTaskAllowed({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
    required List<MediaTask> runningTasks,
    required int userMaxConcurrentExecutions,
    String? excludedTaskId,
  }) async {
    for (final task in _tasksForCurrentScope(tasks, folders)) {
      if (task.id == excludedTaskId ||
          _preemptedTaskIds.contains(task.id) ||
          _suppressedTaskIds.contains(task.id) ||
          !isStartableTask(task)) {
        continue;
      }
      if (await resourceGuard.canStartTask(
        task: task,
        runningTasks: runningTasks,
        userMaxConcurrentExecutions: userMaxConcurrentExecutions,
      )) {
        return task;
      }
    }
    return null;
  }

  bool _hasScopedStartableCandidate(
    List<MediaTask> tasks, {
    required List<TaskFolder> folders,
    String? excludedTaskId,
  }) {
    return _tasksForCurrentScope(tasks, folders).any(
      (task) =>
          task.id != excludedTaskId &&
          !_suppressedTaskIds.contains(task.id) &&
          isStartableTask(task),
    );
  }

  bool _hasScopedAwaitingAnalysisCandidate(
    List<MediaTask> tasks, {
    required List<TaskFolder> folders,
    String? excludedTaskId,
  }) {
    return _tasksForCurrentScope(tasks, folders).any(
      (task) =>
          task.id != excludedTaskId &&
          !_suppressedTaskIds.contains(task.id) &&
          (task.isAwaitingAnalysis || task.status == TaskStatus.analyzing),
    );
  }

  List<MediaTask> _tasksForCurrentScope(
    List<MediaTask> tasks,
    List<TaskFolder> folders,
  ) {
    return switch (_executionScope.type) {
      ExecutionScopeType.none => const [],
      ExecutionScopeType.workbench => expandedExecutionOrder(tasks, folders),
      ExecutionScopeType.folder =>
        tasks
            .where((task) => task.folderId == _executionScope.folderId)
            .toList()
          ..sort(_compareFolderTasksForExecution),
    };
  }

  Future<bool> _hasCapacityFor(MediaTask task, {String? excludedTaskId}) async {
    final tasks = await repository.loadAllTasks();
    final settings = await readSettings();
    return resourceGuard.canStartTask(
      task: task,
      runningTasks: _runningTasksFrom(tasks, excludedTaskId: excludedTaskId),
      userMaxConcurrentExecutions: settings.maxConcurrentExecutions,
    );
  }

  Future<FfmpegQueueStartResult> startTask(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) async {
    if (task.config.engineConfiguration != null) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: task,
        message: 'Engine 配置任务必须通过 FEngine 提交，不能回退到旧 FFmpeg 链。',
      );
    }
    if (!task.isAnalysisReady) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notReady,
        task: task,
        message: '媒体信息尚未分析完成，请稍候',
      );
    }
    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      await _continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.missingSource,
        task: updatedTask,
        message: '源文件不存在，等待用户重新指定文件',
      );
    }

    final runtime = await readRuntime();
    if (!runtime.canEncode || runtime.ffmpeg == null) {
      final failedTask = task.markFailed(
        await _taskFailure(
          stage: TaskFailureStage.processStart,
          technicalSummary: 'FFmpeg 不可用',
          fallbackCode: TaskFailureCode.processStartFailed,
          fallbackUserMessage: 'FFmpeg 不可用，请检查运行时设置。',
        ),
      );
      await repository.saveTask(failedTask);
      await publishTaskFailed(failedTask, failureSummary(failedTask));
      await _continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.ffmpegUnavailable,
        task: failedTask,
        message: 'FFmpeg 不可用',
      );
    }

    final scheduler = workScheduler;
    MediaWorkLease? lease;
    if (scheduler != null) {
      lease = scheduler.tryAcquire(
        MediaWorkRequest(
          id: 'encode:${task.id}',
          kind: MediaWorkKind.encode,
          priority: MediaWorkPriority.foreground,
        ),
      );
      if (lease == null) {
        return FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.queued,
          task: task,
          message: '正在等待设备资源空闲',
        );
      }
    }

    PreparedMediaInput? preparedInput;
    late FfmpegCommandPlan plan;
    var preflightTags = const <MediaTaskPolicyTag>{};
    var preparationStage = TaskFailureStage.inputPreparation;
    try {
      preparedInput = await mediaInputPreparer.prepare(
        task,
        purpose: MediaInputPreparationPurpose.execution,
      );
      final settings = await readSettings();
      preparedInput = PreparedMediaInput(
        task: _resolveExecutionOutputLocation(preparedInput.task, settings),
        proprietaryAudioDecodeResult:
            preparedInput.proprietaryAudioDecodeResult,
      );
      preparationStage = TaskFailureStage.commandPlanning;
      plan = commandBuilder.build(
        preparedInput.task,
        allowExtremeCompression: allowExtremeCompression,
        encoderCapabilities: runtime.encoderCapabilities,
      );
      preparationStage = TaskFailureStage.outputPreflight;
      final preflight = await outputPreflightService.prepare(
        task: preparedInput.task,
        plan: plan,
      );
      plan = preflight.plan;
      preflightTags = preflight.policyTags;
    } on CompressionConfirmationRequiredException catch (error) {
      await _releaseLeaseBestEffort(lease);
      final input = preparedInput;
      if (input != null) {
        await mediaInputPreparer.cleanup(input);
      }
      await refreshStatus();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.compressionConfirmationRequired,
        task: task,
        message: error.toString(),
      );
    } on Object catch (error) {
      await _releaseLeaseBestEffort(lease);
      final input = preparedInput;
      if (input != null) {
        await mediaInputPreparer.cleanup(input);
      }
      final failedTask = task.markFailed(
        await _taskFailure(
          stage: preparationStage,
          technicalSummary: error.toString(),
          fallbackCode: switch (preparationStage) {
            TaskFailureStage.inputPreparation =>
              TaskFailureCode.inputPreparationFailed,
            TaskFailureStage.commandPlanning =>
              TaskFailureCode.commandBuildFailed,
            TaskFailureStage.outputPreflight =>
              TaskFailureCode.outputDirectoryNotWritable,
            _ => TaskFailureCode.unknown,
          },
          fallbackUserMessage: switch (preparationStage) {
            TaskFailureStage.inputPreparation => '媒体输入准备失败。',
            TaskFailureStage.commandPlanning => '当前任务配置无法生成有效的处理命令。',
            TaskFailureStage.outputPreflight => '输出位置无法用于保存处理结果。',
            _ => '任务启动准备失败。',
          },
          retryable: preparationStage != TaskFailureStage.commandPlanning,
        ),
      );
      await repository.saveTask(failedTask);
      await publishTaskFailed(failedTask, failureSummary(failedTask));
      await _continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.commandBuildFailed,
        task: failedTask,
        message: error.toString(),
      );
    }
    final executionInput = preparedInput;

    final logFile = await File(
      await createLogFilePath(task, plan),
    ).create(recursive: true);

    late final TaskExecution execution;
    MediaTask? runningTask;
    MediaTask? processStartFailedTask;
    try {
      final startedAt = (await now()).millisecondsSinceEpoch;
      runningTask = task
          .withPolicyTags(preflightTags)
          .markRunning(outputPath: plan.outputPath, startedAt: startedAt);
      await repository.saveTask(runningTask);

      execution = await startExecutionStep(
        task: executionInput.task.copyWith(
          status: runningTask.status,
          outputPath: runningTask.outputPath,
          policyTags: runningTask.policyTags,
          startedAt: runningTask.startedAt,
        ),
        plan: plan,
        preparedInput: executionInput,
        stepIndex: 0,
        ffmpegPath: runtime.ffmpeg!.path,
        logFile: logFile,
      );
    } on Object catch (error) {
      await appendExecutionLogFooter(
        logFile,
        success: false,
        message: 'FFmpeg 启动失败: $error',
      );
      // 如果已经保存了 running 状态，尝试回滚为失败
      try {
        final latestTask = await repository.loadTaskById(task.id);
        if (latestTask != null && latestTask.status == TaskStatus.running) {
          final failedTask = latestTask.markFailed(
            await _taskFailure(
              stage: TaskFailureStage.processStart,
              technicalSummary: 'FFmpeg 启动失败: $error',
              fallbackCode: TaskFailureCode.processStartFailed,
              fallbackUserMessage: 'FFmpeg 进程启动失败。',
            ),
          );
          processStartFailedTask = failedTask;
          await repository.saveTask(failedTask);
          await publishTaskFailed(failedTask, failureSummary(failedTask));
        }
      } on Object {
        // Best-effort.
      }
      await outputPreflightService.discardPlan(plan);
      await mediaInputPreparer.cleanup(executionInput);
      // 启动失败时释放调度器租约（幂等）
      await _releaseLeaseBestEffort(lease);
      await _continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.processStartFailed,
        task: processStartFailedTask ?? task,
        message: error.toString(),
      );
    }

    _executions[runningTask.id] = execution;
    execution.schedulerLease = lease;
    _queueStatus = FfmpegQueueStatus.running;
    _startOutputMonitor(execution);
    observeExecution(execution);

    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.started,
      task: runningTask,
      message: 'FFmpeg 进程已启动并开始后台观测',
    );
  }

  Future<TaskExecution> startExecutionStep({
    required MediaTask task,
    required FfmpegCommandPlan plan,
    required PreparedMediaInput preparedInput,
    required int stepIndex,
    required String ffmpegPath,
    required File logFile,
    int? runSequence,
  }) async {
    final step = plan.steps[stepIndex];
    final currentTask =
        findTaskById(await repository.loadAllTasks(), task.id) ?? task;
    final taskForStep = currentTask
        .copyWith(outputPath: step.outputPath ?? currentTask.outputPath)
        .withPolicyTags(step.policyTagsOnStart);
    if (taskForStep.outputPath != currentTask.outputPath ||
        step.policyTagsOnStart.isNotEmpty) {
      await repository.saveTask(taskForStep);
    }
    final startedProcess = await processStarter.start(
      ffmpegPath: ffmpegPath,
      args: step.args,
      logFile: logFile,
    );
    final observationFuture = processObserver.observe(
      startedProcess: startedProcess,
      task: taskForStep,
      outputPath: step.workingOutputPath ?? step.outputPath,
      progressMode: step.progressMode,
      onProgress: (progress) async {
        // 使用 loadTaskById 替代 loadAllTasks，减少数据库 IO。
        final currentTask = await repository.loadTaskById(task.id);
        if (currentTask == null || currentTask.status != TaskStatus.running) {
          return;
        }

        // 数据库进度写入节流：每 1 秒最多持久化一次。
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastPersist = _lastProgressPersistMs[task.id];
        if (lastPersist != null && (nowMs - lastPersist) < 1000) {
          return;
        }
        _lastProgressPersistMs[task.id] = nowMs;

        final stepCount = plan.steps.length;
        final scaledProgress = ((stepIndex + progress) / stepCount)
            .clamp(0, 0.999)
            .toDouble();
        await repository.saveTask(currentTask.withProgress(scaledProgress));
      },
    );

    return TaskExecution(
      taskId: task.id,
      ffmpegPath: ffmpegPath,
      plan: plan,
      logFile: logFile,
      startedProcess: startedProcess,
      observationFuture: observationFuture,
      preparedInput: preparedInput,
      stepIndex: stepIndex,
      state: TaskExecutionState.running,
      runSequence: runSequence ?? _nextRunSequence(),
    );
  }

  int _nextRunSequence() => _nextRunSequenceValue++;

  void observeExecution(TaskExecution execution) {
    unawaited(
      execution.observationFuture
          .then((observation) async {
            // 关键：先在串行命令外释放调度器租约，避免死锁。
            // 如果租约释放在 _serializeCommand 内，当 finishObservedTask
            // 无法进入串行区时（因为 startTask 持有了串行锁并在等待资源），
            // 租约永远无法释放，形成死锁。
            await _releaseSchedulerLease(execution);

            // 租约已释放，安全进入串行命令进行数据库收尾和后续调度。
            await _serializeCommand(() async {
              await finishObservedTask(execution.taskId, observation);
              await _continueAfterTask();
            });
          })
          .catchError((Object error) async {
            await _releaseSchedulerLease(execution);

            await _serializeCommand(() async {
              await finishObservedTask(
                execution.taskId,
                FfmpegProcessObservation.failed('FFmpeg 输出监听失败: $error'),
              );
              await _continueAfterTask();
            });
          }),
    );
  }

  void _startOutputMonitor(TaskExecution execution) {
    execution.outputMonitor?.cancel();
    final workingPath =
        execution.plan.steps[execution.stepIndex].workingOutputPath;
    if (workingPath == null) {
      return;
    }

    var consecutiveMissingChecks = 0;
    execution.outputMonitor = Timer.periodic(reorderAnimation, (timer) {
      final currentExecution = _executions[execution.taskId];
      if (currentExecution != execution ||
          execution.state == TaskExecutionState.finishing) {
        timer.cancel();
        return;
      }
      if (execution.state != TaskExecutionState.running) {
        consecutiveMissingChecks = 0;
        return;
      }

      // 异步检查文件存在，避免主线程同步阻塞 I/O 操作。
      if (File(workingPath).existsSync()) {
        consecutiveMissingChecks = 0;
        return;
      }
      consecutiveMissingChecks += 1;
      if (consecutiveMissingChecks < 2) {
        return;
      }

      timer.cancel();
      unawaited(
        _processLifecycle.terminate(execution).then((_) async {
          // 输出文件缺失：先释放租约（在串行命令外），再进入串行命令收尾。
          await _releaseSchedulerLease(execution);
          await _serializeCommand(() async {
            await finishObservedTask(
              execution.taskId,
              const FfmpegProcessObservation.failed('运行中的临时输出文件被删除或移动，任务已停止。'),
            );
            await _continueAfterTask();
          });
        }),
      );
    });
  }

  Future<FfmpegQueueStartResult> resumeExecution(
    MediaTask task,
    TaskExecution execution,
  ) async {
    if (execution.state == TaskExecutionState.running) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.alreadyRunning,
        task: task,
        message: '任务已经在前台执行',
      );
    }

    if (execution.state == TaskExecutionState.finishing) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: task,
        message: '任务正在收尾，不能恢复',
      );
    }

    // 恢复前重新申请活跃编码租约。暂停时已释放租约，
    // 恢复需要重新申请。无可用资源时进入等待状态。
    if (execution.schedulerLease == null) {
      final scheduler = workScheduler;
      if (scheduler != null) {
        final lease = scheduler.tryAcquire(
          MediaWorkRequest(
            id: 'encode:${task.id}',
            kind: MediaWorkKind.encode,
            priority: MediaWorkPriority.foreground,
          ),
        );
        if (lease == null) {
          // 无可用资源，任务保持 paused 状态，等待下次调度。
          return FfmpegQueueStartResult(
            outcome: FfmpegQueueStartOutcome.queued,
            task: task,
            message: '正在等待设备资源空闲后恢复',
          );
        }
        execution.schedulerLease = lease;
      }
    }

    await _processLifecycle.resume(execution);
    execution.runSequence = _nextRunSequence();
    final resumedTask = task.markResumed();
    await repository.saveTask(resumedTask);
    _queueStatus = FfmpegQueueStatus.running;

    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.resumed,
      task: resumedTask,
      message: '任务已恢复执行',
    );
  }

  Future<void> finishObservedTask(
    String taskId,
    FfmpegProcessObservation observation,
  ) async {
    final execution = _executions[taskId];
    if (execution == null) {
      return;
    }

    final task = findTaskById(await repository.loadAllTasks(), taskId);
    if (task == null || task.status == TaskStatus.cancelled) {
      _executions.remove(taskId);
      _cleanupTaskTracking(taskId);
      execution.outputMonitor?.cancel();
      await _releaseSchedulerLease(execution);
      await outputPreflightService.discardPlan(execution.plan);
      await mediaInputPreparer.cleanup(execution.preparedInput);
      return;
    }

    final currentStep = execution.plan.steps[execution.stepIndex];
    var completeCurrentPlan = false;
    if (observation.status == FfmpegProcessObservationStatus.completed &&
        currentStep.completionPolicy !=
            FfmpegStepCompletionPolicy.alwaysContinue) {
      final outputIsSmaller = await isStepOutputSmallerThanSource(
        task,
        currentStep,
      );
      if (outputIsSmaller == true) {
        completeCurrentPlan = true;
      } else {
        final ineffectiveOutputPath =
            currentStep.workingOutputPath ?? currentStep.outputPath;
        final ineffectiveOutputSize = ineffectiveOutputPath == null
            ? null
            : await _getFileSize(ineffectiveOutputPath);
        await deleteStepOutput(currentStep);
        final mediaLabel = switch (task.mediaKind) {
          MediaKind.video => '视频',
          MediaKind.image => '图片',
          MediaKind.audio => '音频',
        };
        final message = outputIsSmaller == null
            ? '$mediaLabel压缩结果无法验证，未保留本次输出。'
            : '$mediaLabel未有效压缩：输出文件不小于源文件，已清理本次无效输出。';

        if (currentStep.completionPolicy ==
                FfmpegStepCompletionPolicy.completeIfOutputSmallerThanSource &&
            execution.stepIndex < execution.plan.steps.length - 1) {
          // Continue to the fallback step below.
        } else {
          execution.state = TaskExecutionState.finishing;
          execution.outputMonitor?.cancel();
          _executions.remove(taskId);
          await _releaseSchedulerLease(execution);

          await appendExecutionLogFooter(
            execution.logFile,
            success: false,
            message: message,
          );

          final failedTask = task
              .withPolicyTags(const {MediaTaskPolicyTag.ineffectiveCompression})
              .markFailed(
                await _taskFailure(
                  stage: TaskFailureStage.outputValidation,
                  technicalSummary: message,
                  fallbackCode: TaskFailureCode.ineffectiveCompression,
                  fallbackUserMessage: message,
                  retryable: false,
                  mediaKind: task.mediaKind,
                ),
              )
              .copyWith(clearOutputPath: true);
          await repository.saveTask(failedTask);
          await publishTaskFailed(
            failedTask,
            failureSummary(failedTask, outputFileSize: ineffectiveOutputSize),
          );
          await cleanupPlanFiles(execution.plan);
          await outputPreflightService.discardPlan(execution.plan);
          await mediaInputPreparer.cleanup(execution.preparedInput);
          return;
        }
      }
    }

    if (observation.status == FfmpegProcessObservationStatus.completed &&
        !completeCurrentPlan &&
        execution.stepIndex < execution.plan.steps.length - 1) {
      final nextStepIndex = execution.stepIndex + 1;
      try {
        execution.outputMonitor?.cancel();
        final nextExecution = await startExecutionStep(
          task: task,
          plan: execution.plan,
          preparedInput: execution.preparedInput,
          stepIndex: nextStepIndex,
          ffmpegPath: execution.ffmpegPath,
          logFile: execution.logFile,
          runSequence: execution.runSequence,
        );
        execution.startedProcess = nextExecution.startedProcess;
        execution.observationFuture = nextExecution.observationFuture;
        execution.stepIndex = nextStepIndex;
        execution.state = TaskExecutionState.running;
        _startOutputMonitor(execution);
        observeExecution(execution);
      } on Object catch (error) {
        execution.state = TaskExecutionState.finishing;
        execution.outputMonitor?.cancel();
        _executions.remove(taskId);
        await _releaseSchedulerLease(execution);
        await outputPreflightService.discardPlan(execution.plan);
        await cleanupPlanFiles(execution.plan);
        await mediaInputPreparer.cleanup(execution.preparedInput);

        await appendExecutionLogFooter(
          execution.logFile,
          success: false,
          message: 'FFmpeg 启动失败: $error',
        );

        final failedTask = task.markFailed(
          await _taskFailure(
            stage: TaskFailureStage.processStart,
            technicalSummary: 'FFmpeg 启动失败: $error',
            fallbackCode: TaskFailureCode.processStartFailed,
            fallbackUserMessage: 'FFmpeg 进程启动失败。',
          ),
        );
        await repository.saveTask(failedTask);
        await publishTaskFailed(failedTask, failureSummary(failedTask));
      }
      return;
    }

    // 硬件编码器会话失效自动重试。
    // 场景：用户暂停任务（SIGSTOP）后系统睡眠，唤醒恢复（SIGCONT）时
    // VideoToolbox / NVENC / QSV / AMF 的硬件编码会话已被系统回收，
    // ffmpeg 报 "Generic error in an external library" 后退出。
    // 此时从头重启该 step 即可恢复，无需让任务直接失败。
    if (observation.status == FfmpegProcessObservationStatus.failed &&
        _isHardwareEncoderSessionFailure(observation) &&
        execution.hardwareRetryCount < maxHardwareEncoderRetries) {
      await _retryHardwareEncoderStep(execution, task, currentStep);
      return;
    }

    execution.state = TaskExecutionState.finishing;
    execution.outputMonitor?.cancel();
    _executions.remove(taskId);
    await _releaseSchedulerLease(execution);

    if (observation.status == FfmpegProcessObservationStatus.completed) {
      late final CompletedTaskResult completedResult;
      try {
        completedResult = await _resultFinalizer.publishCompleted(
          task: task,
          step: currentStep,
        );
      } on TaskResultFinalizationException catch (error) {
        await outputPreflightService.discardPlan(execution.plan);
        final failedTask = await _resultFinalizer.markFailed(
          task,
          TaskFailure(
            stage: error.stage,
            code: error.code,
            userMessage: error.userMessage,
            technicalSummary: error.technicalSummary,
            occurredAt: (await now()).millisecondsSinceEpoch,
            retryable: true,
          ),
        );
        await publishTaskFailed(failedTask, failureSummary(failedTask));
        await cleanupPlanFiles(execution.plan);
        await mediaInputPreparer.cleanup(execution.preparedInput);
        return;
      }
      final durationMs = task.startedAt != null
          ? completedResult.completedAt - task.startedAt!
          : null;

      await appendExecutionLogFooter(
        execution.logFile,
        success: true,
        outputPath: completedResult.outputPath,
        outputSize: completedResult.outputSize,
        durationMs: durationMs,
      );

      await _resultFinalizer.persistCompleted(completedResult);
      await publishTaskCompleted(
        completedResult.task,
        TaskExecutionNotificationSummary(
          sourceFileSize: task.sourceFileFingerprint?.fileSize,
          outputFileSize: completedResult.outputSize,
          durationMs: durationMs,
          outputPath: completedResult.outputPath,
        ),
      );
    } else {
      await appendExecutionLogFooter(
        execution.logFile,
        success: false,
        message: observation.message ?? 'FFmpeg 执行失败',
      );

      final failedTask = await _resultFinalizer.markFailed(
        task,
        await _taskFailure(
          stage: TaskFailureStage.processing,
          technicalSummary: observation.message ?? 'FFmpeg 执行失败',
          fallbackCode: TaskFailureCode.processExitedAbnormally,
          fallbackUserMessage: 'FFmpeg 执行失败。',
          mediaKind: task.mediaKind,
        ),
      );
      await publishTaskFailed(failedTask, failureSummary(failedTask));
    }

    await outputPreflightService.discardPlan(execution.plan);
    await cleanupPlanFiles(execution.plan);
    await mediaInputPreparer.cleanup(execution.preparedInput);
  }

  /// 硬件编码器会话失效的最大自动重试次数。
  /// 1 次足够覆盖"暂停+睡眠"单次中断；多次连续失效通常意味着
  /// 硬件本身有问题，不应无限重试。
  static const int maxHardwareEncoderRetries = 1;

  /// 判断失败是否由硬件编码器会话失效引起。
  ///
  /// 特征：stderr 中同时出现硬件编码器名称（videotoolbox / nvenc / _qsv /
  /// _amf）与 "generic error in an external library"。这是 macOS 睡眠唤醒后
  /// VideoToolbox 会话失效、或 GPU 驱动抖动时的典型报错。软件编码器（libx264
  /// 等）的普通失败不会命中此条件，不会误触发重试。
  bool _isHardwareEncoderSessionFailure(FfmpegProcessObservation observation) {
    final message = observation.message ?? '';
    if (message.isEmpty) {
      return false;
    }
    final lower = message.toLowerCase();
    final hasHardwareEncoder =
        lower.contains('videotoolbox') ||
        lower.contains('nvenc') ||
        lower.contains('_qsv') ||
        lower.contains('_amf');
    final hasExternalLibraryError = lower.contains(
      'generic error in an external library',
    );
    return hasHardwareEncoder && hasExternalLibraryError;
  }

  /// 从头重启当前 step，用于硬件编码器会话失效后的自动恢复。
  Future<void> _retryHardwareEncoderStep(
    TaskExecution execution,
    MediaTask task,
    FfmpegCommandStep currentStep,
  ) async {
    execution.hardwareRetryCount += 1;

    // 清理上一轮失败留下的残缺输出，避免污染重试结果。
    await deleteStepOutput(currentStep);

    try {
      final retryExecution = await startExecutionStep(
        task: task,
        plan: execution.plan,
        preparedInput: execution.preparedInput,
        stepIndex: execution.stepIndex,
        ffmpegPath: execution.ffmpegPath,
        logFile: execution.logFile,
        runSequence: execution.runSequence,
      );
      execution.startedProcess = retryExecution.startedProcess;
      execution.observationFuture = retryExecution.observationFuture;
      execution.state = TaskExecutionState.running;
      _startOutputMonitor(execution);
      observeExecution(execution);
    } on Object catch (error) {
      // 重试启动本身就失败了，按普通失败处理。
      execution.state = TaskExecutionState.finishing;
      execution.outputMonitor?.cancel();
      _executions.remove(execution.taskId);
      await appendExecutionLogFooter(
        execution.logFile,
        success: false,
        message: '硬件编码器会话失效后重试启动失败: $error',
      );
      final failedTask = task.markFailed(
        await _taskFailure(
          stage: TaskFailureStage.processing,
          technicalSummary: '硬件编码器会话失效后重试启动失败: $error',
          fallbackCode: TaskFailureCode.hardwareSessionLost,
          fallbackUserMessage: '硬件编码会话中断，自动恢复未能成功。',
        ),
      );
      await repository.saveTask(failedTask);
      await publishTaskFailed(failedTask, failureSummary(failedTask));
      await outputPreflightService.discardPlan(execution.plan);
      await cleanupPlanFiles(execution.plan);
      await mediaInputPreparer.cleanup(execution.preparedInput);
      await _continueAfterTask();
    }
  }

  Future<void> publishTaskCompleted(
    MediaTask task, [
    TaskExecutionNotificationSummary? summary,
  ]) async {
    final callback = onTaskCompleted;
    if (callback == null) {
      return;
    }
    try {
      await callback(task, summary);
    } on Object {
      // Notification persistence must not change a completed task result.
    }
  }

  Future<void> publishTaskFailed(
    MediaTask task, [
    TaskExecutionNotificationSummary? summary,
  ]) async {
    final callback = onTaskFailed;
    if (callback == null) {
      return;
    }
    try {
      await callback(task, summary);
    } on Object {
      // Notification persistence must not change a failed task result.
    }
  }

  Future<TaskFailure> _taskFailure({
    required TaskFailureStage stage,
    required String technicalSummary,
    TaskFailureCode? fallbackCode,
    String? fallbackUserMessage,
    bool retryable = true,
    MediaKind? mediaKind,
  }) async {
    return taskFailureFromError(
      stage: stage,
      technicalSummary: technicalSummary,
      occurredAt: (await now()).millisecondsSinceEpoch,
      mediaKind: mediaKind,
      fallbackCode: fallbackCode,
      fallbackUserMessage: fallbackUserMessage,
      retryable: retryable,
    );
  }

  TaskExecutionNotificationSummary failureSummary(
    MediaTask task, {
    int? outputFileSize,
    int? durationMs,
  }) {
    final failure = task.failure;
    final reason = failure?.userMessage ?? '媒体处理未能完成';
    final suggestion = failure == null
        ? '建议查看任务日志获取详细信息，或重试该任务。'
        : _suggestionForRecovery(failure.recoveryAction);
    return TaskExecutionNotificationSummary(
      sourceFileSize: task.sourceFileFingerprint?.fileSize,
      outputFileSize: outputFileSize,
      durationMs: durationMs,
      outputPath: task.outputPath,
      failureReason: reason,
      failureSuggestion: suggestion,
    );
  }

  String failureSuggestionFor(MediaTask task) {
    final failure = task.failure;
    if (failure != null) {
      return _suggestionForRecovery(failure.recoveryAction);
    }
    return '建议查看任务日志获取详细信息，或重试该任务。';
  }

  String _suggestionForRecovery(TaskRecoveryAction action) {
    return switch (action) {
      TaskRecoveryAction.retryAnalysis => '请确认源文件可正常读取后重新分析。',
      TaskRecoveryAction.retryExecution => '请重试该任务；如再次失败，请查看任务日志。',
      TaskRecoveryAction.editConfiguration => '请修改任务格式、编码器或压缩参数后重试。',
      TaskRecoveryAction.chooseOutputDirectory => '请检查磁盘空间和目录权限，或更换输出位置后重试。',
      TaskRecoveryAction.relinkSource => '请重新指定仍可访问的源文件。',
      TaskRecoveryAction.inspectLog => '请查看任务日志获取技术详情。',
      TaskRecoveryAction.none => '当前错误不适合直接重试，请调整文件或配置后再试。',
    };
  }

  Future<bool?> isStepOutputSmallerThanSource(
    MediaTask task,
    FfmpegCommandStep step,
  ) async {
    if (task.mediaKind != MediaKind.image) {
      return true;
    }
    final outputPath = step.workingOutputPath ?? step.outputPath;
    if (outputPath == null) {
      return null;
    }

    final outputSize = await _getFileSize(outputPath);
    final sourceSize =
        task.sourceFileFingerprint?.fileSize ??
        await _getFileSize(task.inputPath);
    if (outputSize == null || sourceSize == null || sourceSize <= 0) {
      return null;
    }

    return outputSize < sourceSize;
  }

  Future<void> deleteStepOutput(FfmpegCommandStep step) async {
    await outputPreflightService.discardStep(step);
    if (step.workingOutputPath != null || step.outputPath == null) {
      return;
    }
    try {
      final file = File(step.outputPath!);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Best-effort cleanup; the task failure remains authoritative.
    }
  }

  Future<int?> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {
      // Ignore errors
    }
    return null;
  }

  Future<void> appendExecutionLogFooter(
    File? logFile, {
    required bool success,
    String? message,
    String? outputPath,
    int? outputSize,
    int? durationMs,
  }) async {
    if (logFile == null) {
      return;
    }

    try {
      final sink = logFile.openWrite(mode: FileMode.append);
      sink.writeln();
      sink.writeln('=' * 80);
      sink.writeln(success ? '任务完成' : '任务失败');
      if (message != null && message.trim().isNotEmpty) {
        sink.writeln(message);
      }
      if (outputPath != null) {
        sink.writeln('输出路径: $outputPath');
      }
      if (outputSize != null) {
        sink.writeln('输出大小: ${formatLogBytes(outputSize)}');
      }
      if (durationMs != null) {
        sink.writeln('耗时: ${formatLogDuration(durationMs)}');
      }
      sink.writeln('=' * 80);
      await sink.close();
    } on Object {
      // Logging is diagnostic only; execution state should not depend on it.
    }
  }

  String formatLogBytes(int bytes) {
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

  String formatLogDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    if (seconds < 60) {
      return '$seconds秒';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return '$minutes分$remainingSeconds秒';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours小时$remainingMinutes分$remainingSeconds秒';
  }

  Future<void> cleanupPlanFiles(FfmpegCommandPlan plan) async {
    for (final prefix in plan.cleanupPathPrefixes) {
      final directory = Directory(path.dirname(prefix));
      if (!await directory.exists()) {
        continue;
      }

      final prefixName = path.basename(prefix);
      await for (final entity in directory.list()) {
        if (!path.basename(entity.path).startsWith(prefixName)) {
          continue;
        }

        try {
          await entity.delete(recursive: true);
        } on Object {
          // Best-effort cleanup; compression result should not fail because
          // FFmpeg pass logs were already removed or locked by the OS.
        }
      }
    }
  }

  MediaTask _resolveExecutionOutputLocation(
    MediaTask task,
    AppSettings settings,
  ) {
    final outputDirectory = switch (task.config.outputLocationMode) {
      OutputLocationMode.source => '',
      OutputLocationMode.custom => task.config.outputDirectory.trim(),
      OutputLocationMode.system =>
        settings.saveOutputToSourceDirectory
            ? ''
            : settings.defaultOutputDirectory?.trim() ?? '',
    };
    return task.copyWith(
      config: task.config.copyWith(outputDirectory: outputDirectory),
    );
  }

  void _cleanupTaskTracking(String taskId) {
    _lastProgressPersistMs.remove(taskId);
    _preemptedTaskIds.remove(taskId);
    _suppressedTaskIds.remove(taskId);
  }

  /// 释放调度器租约，幂等操作。
  /// 调用后 [execution.schedulerLease] 被清空，重复调用安全无副作用。
  Future<void> _releaseSchedulerLease(TaskExecution execution) async {
    _lastProgressPersistMs.remove(execution.taskId);
    await _processLifecycle.releaseLease(execution);
  }

  Future<void> _continueAfterTask({String? excludedTaskId}) async {
    if (!continuousExecutionEnabled ||
        (!_executionScope.isContinuous && _preemptedTaskIds.isEmpty)) {
      await refreshStatus();
      return;
    }

    await fillAvailableSlots(
      allowExtremeCompression: _allowExtremeCompressionForScope,
      excludedTaskId: excludedTaskId,
    );
  }

  Future<void> _releaseLeaseBestEffort(MediaWorkLease? lease) async {
    try {
      await lease?.release();
    } on Object {
      // Best-effort.
    }
  }

  FfmpegQueueStatus resolveQueueStatus(List<MediaTask> tasks) {
    if (runningTaskIds.isNotEmpty ||
        tasks.any((task) => task.status == TaskStatus.running)) {
      return FfmpegQueueStatus.running;
    }

    if (_executions.values.any(
          (execution) => execution.state == TaskExecutionState.paused,
        ) ||
        tasks.any(isStartableTask)) {
      return FfmpegQueueStatus.ready;
    }

    return FfmpegQueueStatus.idle;
  }

  MediaTask? nextStartableTask(
    List<MediaTask> tasks, {
    List<TaskFolder>? folders,
    String? excludedTaskId,
  }) {
    final startableTasks = expandedExecutionOrder(tasks, folders ?? const [])
        .where((task) => task.id != excludedTaskId && isStartableTask(task))
        .toList();

    if (startableTasks.isEmpty) {
      return null;
    }

    return startableTasks.first;
  }

  List<MediaTask> expandedExecutionOrder(
    List<MediaTask> tasks,
    List<TaskFolder> folders,
  ) {
    final byId = <String, MediaTask>{for (final task in tasks) task.id: task};
    return const TaskFolderQueueProjection()
        .orderedTaskIds(tasks, folders)
        .map((taskId) => byId[taskId])
        .whereType<MediaTask>()
        .toList(growable: false);
  }

  bool isStartableTask(MediaTask task) {
    if (task.config.engineConfiguration != null) {
      return false;
    }
    if (task.isAnalysisReady) {
      return true;
    }
    return task.status == TaskStatus.paused && _executions.containsKey(task.id);
  }

  int _compareFolderTasksForExecution(MediaTask a, MediaTask b) {
    final order = (a.folderSortOrder ?? a.sortOrder).compareTo(
      b.folderSortOrder ?? b.sortOrder,
    );
    if (order != 0) {
      return order;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  MediaTask? findTaskById(List<MediaTask> tasks, String taskId) {
    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }
}
