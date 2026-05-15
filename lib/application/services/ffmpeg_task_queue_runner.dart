import 'dart:async';
import 'dart:io';

import 'package:machining/application/repositories/media_task_repository.dart';
import 'package:machining/application/services/ffmpeg_command_builder.dart';
import 'package:machining/application/services/ffmpeg_locator.dart';
import 'package:machining/application/services/ffmpeg_process_observer.dart';
import 'package:machining/application/services/ffmpeg_process_starter.dart';
import 'package:machining/application/services/source_file_checker.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:path/path.dart' as path;

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
  completed,
  executionFailed,
}

enum TaskExecutionState { running, paused, finishing }

class TaskExecution {
  final String taskId;
  final String ffmpegPath;
  final FfmpegCommandPlan plan;
  final File logFile;
  StartedFfmpegProcess startedProcess;
  Future<FfmpegProcessObservation> observationFuture;
  int stepIndex;
  TaskExecutionState state;

  TaskExecution({
    required this.taskId,
    required this.ffmpegPath,
    required this.plan,
    required this.logFile,
    required this.startedProcess,
    required this.observationFuture,
    required this.stepIndex,
    required this.state,
  });
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

  Future<FfmpegQueueStatus> refreshStatus();

  Future<FfmpegQueueStartResult> start({bool allowExtremeCompression = false});

  Future<FfmpegQueueStartResult> startOrResumeTask(
    String taskId, {
    bool allowExtremeCompression = false,
  });

  Future<FfmpegQueueStartResult> pauseTask(String taskId);

  Future<FfmpegQueueStartResult> cancelTask(String taskId);

  Future<void> cancelAllExecutions();
}

class DefaultFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  final MediaTaskRepository repository;
  final SourceFileChecker sourceFileChecker;
  final Future<ResolvedFfmpegRuntime> Function() readRuntime;
  final FfmpegCommandBuilder commandBuilder;
  final FfmpegProcessStarter processStarter;
  final FfmpegProcessObserver processObserver;
  final bool continuousExecutionEnabled;
  final Future<DateTime> Function() now;
  final Future<String> Function(MediaTask task, FfmpegCommandPlan plan)
  createLogFilePath;

  final Map<String, TaskExecution> _executions = {};
  FfmpegQueueStatus _queueStatus = FfmpegQueueStatus.idle;
  String? _foregroundTaskId;
  Future<FfmpegQueueStartResult>? _startFuture;

  DefaultFfmpegTaskQueueRunner({
    required this.repository,
    required this.sourceFileChecker,
    required this.readRuntime,
    required this.commandBuilder,
    required this.processStarter,
    required this.processObserver,
    required this.createLogFilePath,
    this.continuousExecutionEnabled = true,
    Future<DateTime> Function()? now,
  }) : now = now ?? (() async => DateTime.now());

  @override
  FfmpegQueueStatus get queueStatus => _queueStatus;

  @override
  String? get foregroundTaskId => _foregroundTaskId;

  @override
  Future<FfmpegQueueStatus> refreshStatus() async {
    final tasks = await repository.loadAllTasks();
    _queueStatus = resolveQueueStatus(tasks);
    return _queueStatus;
  }

  @override
  Future<FfmpegQueueStartResult> start({bool allowExtremeCompression = false}) {
    final existingStart = _startFuture;
    if (existingStart != null) {
      return Future.value(
        const FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.alreadyRunning,
          message: '队列已经在启动或切换任务中',
        ),
      );
    }

    final startFuture = _start(
      allowExtremeCompression: allowExtremeCompression,
    );
    _startFuture = startFuture;
    unawaited(
      startFuture
          .whenComplete(() {
            _startFuture = null;
          })
          .catchError(
            (_) => const FfmpegQueueStartResult(
              outcome: FfmpegQueueStartOutcome.processStartFailed,
              message: '队列启动失败',
            ),
          ),
    );
    return startFuture;
  }

  @override
  Future<FfmpegQueueStartResult> startOrResumeTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) async {
    final tasks = await repository.loadAllTasks();
    final task = findTaskById(tasks, taskId);
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }

    final foregroundId = _foregroundTaskId;
    if (foregroundId != null && foregroundId != taskId) {
      await suspendForegroundTask();
    }

    final execution = _executions[taskId];
    if (execution != null) {
      return resumeExecution(task, execution);
    }

    if (task.status != TaskStatus.pending && task.status != TaskStatus.paused) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: task,
        message: '当前任务状态不允许开始',
      );
    }

    return startTask(task, allowExtremeCompression: allowExtremeCompression);
  }

  @override
  Future<FfmpegQueueStartResult> pauseTask(String taskId) async {
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

    if (_foregroundTaskId != taskId) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        message: '只能暂停当前前台运行任务',
      );
    }

    final pausedTask = await suspendForegroundTask();
    await continueAfterTask();
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
      task: pausedTask,
      message: '任务已挂起',
    );
  }

  @override
  Future<FfmpegQueueStartResult> cancelTask(String taskId) async {
    final tasks = await repository.loadAllTasks();
    final task = findTaskById(tasks, taskId);
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notFound,
        message: '找不到任务',
      );
    }

    final execution = _executions.remove(taskId);
    execution?.state = TaskExecutionState.finishing;
    execution?.startedProcess.process.kill();
    if (execution != null) {
      await cleanupPlanFiles(execution.plan);
    }

    if (_foregroundTaskId == taskId) {
      _foregroundTaskId = null;
    }

    final cancelledTask = task.markCancelled();
    await repository.saveTask(cancelledTask);
    await continueAfterTask();
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.cancelled,
      task: cancelledTask,
      message: '任务已取消',
    );
  }

  @override
  Future<void> cancelAllExecutions() async {
    for (final execution in _executions.values) {
      execution.state = TaskExecutionState.finishing;
      execution.startedProcess.process.kill();
      await cleanupPlanFiles(execution.plan);
    }

    _executions.clear();
    _foregroundTaskId = null;
    _queueStatus = FfmpegQueueStatus.idle;
  }

  Future<FfmpegQueueStartResult> _start({
    required bool allowExtremeCompression,
  }) async {
    await refreshStatus();
    if (_foregroundTaskId != null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.alreadyRunning,
        message: '已有前台任务正在执行',
      );
    }

    if (_queueStatus != FfmpegQueueStatus.ready) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notReady,
        message: '没有可执行的任务',
      );
    }

    final pausedExecution = firstPausedExecution();
    if (pausedExecution != null) {
      final task = findTaskById(
        await repository.loadAllTasks(),
        pausedExecution.taskId,
      );
      if (task != null) {
        return resumeExecution(task, pausedExecution);
      }
    }

    return runNextPendingTask(allowExtremeCompression: allowExtremeCompression);
  }

  Future<FfmpegQueueStartResult> runNextPendingTask({
    bool allowExtremeCompression = false,
  }) async {
    final tasks = await repository.loadAllTasks();
    final task = nextPendingTask(tasks);
    if (task == null) {
      await refreshStatus();
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.noPendingTask,
        message: '没有找到 pending 任务',
      );
    }

    return startTask(task, allowExtremeCompression: allowExtremeCompression);
  }

  Future<FfmpegQueueStartResult> startTask(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) async {
    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      await continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.missingSource,
        task: updatedTask,
        message: '源文件不存在，等待用户重新指定文件',
      );
    }

    final runtime = await readRuntime();
    if (!runtime.canEncode || runtime.ffmpeg == null) {
      final failedTask = task.markFailed('FFmpeg 不可用');
      await repository.saveTask(failedTask);
      await continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.ffmpegUnavailable,
        task: failedTask,
        message: 'FFmpeg 不可用',
      );
    }

    late final FfmpegCommandPlan plan;
    try {
      plan = commandBuilder.build(
        task,
        allowExtremeCompression: allowExtremeCompression,
        encoderCapabilities: runtime.encoderCapabilities,
      );
    } on CompressionConfirmationRequiredException catch (error) {
      await refreshStatus();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.compressionConfirmationRequired,
        task: task,
        message: error.toString(),
      );
    } on Object catch (error) {
      final failedTask = task.markFailed(error.toString());
      await repository.saveTask(failedTask);
      await continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.commandBuildFailed,
        task: failedTask,
        message: error.toString(),
      );
    }

    final logFile = await File(
      await createLogFilePath(task, plan),
    ).create(recursive: true);
    final startedAt = (await now()).millisecondsSinceEpoch;
    final runningTask = task.markRunning(
      outputPath: plan.outputPath,
      startedAt: startedAt,
    );
    await repository.saveTask(runningTask);

    late final TaskExecution execution;
    try {
      execution = await startExecutionStep(
        task: runningTask,
        plan: plan,
        stepIndex: 0,
        ffmpegPath: runtime.ffmpeg!.path,
        logFile: logFile,
      );
    } on Object catch (error) {
      final failedTask = runningTask.markFailed('FFmpeg 启动失败: $error');
      await repository.saveTask(failedTask);
      await continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.processStartFailed,
        task: failedTask,
        message: error.toString(),
      );
    }

    _executions[runningTask.id] = execution;
    _foregroundTaskId = runningTask.id;
    _queueStatus = FfmpegQueueStatus.running;
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
    required int stepIndex,
    required String ffmpegPath,
    required File logFile,
  }) async {
    final step = plan.steps[stepIndex];
    final startedProcess = await processStarter.start(
      ffmpegPath: ffmpegPath,
      args: step.args,
      logFile: logFile,
    );
    final observationFuture = processObserver.observe(
      startedProcess: startedProcess,
      task: task,
      outputPath: step.outputPath,
      onProgress: (progress) async {
        final currentTasks = await repository.loadAllTasks();
        final currentTask = findTaskById(currentTasks, task.id);
        if (currentTask == null || currentTask.status != TaskStatus.running) {
          return;
        }

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
      stepIndex: stepIndex,
      state: TaskExecutionState.running,
    );
  }

  void observeExecution(TaskExecution execution) {
    unawaited(
      execution.observationFuture
          .then(
            (observation) => finishObservedTask(execution.taskId, observation),
          )
          .catchError(
            (Object error) => finishObservedTask(
              execution.taskId,
              FfmpegProcessObservation.failed('FFmpeg 输出监听失败: $error'),
            ),
          ),
    );
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

    execution.startedProcess.process.kill(ProcessSignal.sigcont);
    execution.state = TaskExecutionState.running;
    final resumedTask = task.markResumed();
    await repository.saveTask(resumedTask);
    _foregroundTaskId = task.id;
    _queueStatus = FfmpegQueueStatus.running;

    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.resumed,
      task: resumedTask,
      message: '任务已恢复执行',
    );
  }

  Future<MediaTask?> suspendForegroundTask() async {
    final taskId = _foregroundTaskId;
    if (taskId == null) {
      return null;
    }

    final execution = _executions[taskId];
    if (execution == null || execution.state != TaskExecutionState.running) {
      _foregroundTaskId = null;
      return null;
    }

    execution.startedProcess.process.kill(ProcessSignal.sigstop);
    execution.state = TaskExecutionState.paused;
    _foregroundTaskId = null;

    final task = findTaskById(await repository.loadAllTasks(), taskId);
    if (task == null) {
      return null;
    }

    final pausedTask = task.markPaused();
    await repository.saveTask(pausedTask);
    await refreshStatus();
    return pausedTask;
  }

  Future<void> finishObservedTask(
    String taskId,
    FfmpegProcessObservation observation,
  ) async {
    final execution = _executions[taskId];
    if (execution == null || execution.state == TaskExecutionState.paused) {
      return;
    }

    final task = findTaskById(await repository.loadAllTasks(), taskId);
    if (task == null || task.status == TaskStatus.cancelled) {
      _executions.remove(taskId);
      if (_foregroundTaskId == taskId) {
        _foregroundTaskId = null;
      }
      await continueAfterTask();
      return;
    }

    if (observation.status == FfmpegProcessObservationStatus.completed &&
        execution.stepIndex < execution.plan.steps.length - 1) {
      final nextStepIndex = execution.stepIndex + 1;
      try {
        final nextExecution = await startExecutionStep(
          task: task,
          plan: execution.plan,
          stepIndex: nextStepIndex,
          ffmpegPath: execution.ffmpegPath,
          logFile: execution.logFile,
        );
        execution.startedProcess = nextExecution.startedProcess;
        execution.observationFuture = nextExecution.observationFuture;
        execution.stepIndex = nextStepIndex;
        execution.state = TaskExecutionState.running;
        observeExecution(execution);
      } on Object catch (error) {
        execution.state = TaskExecutionState.finishing;
        _executions.remove(taskId);
        if (_foregroundTaskId == taskId) {
          _foregroundTaskId = null;
        }
        await cleanupPlanFiles(execution.plan);
        final failedTask = task.markFailed(
          'FFmpeg 启动失败: $error',
          failedAt: (await now()).millisecondsSinceEpoch,
        );
        await repository.saveTask(failedTask);
        await continueAfterTask();
      }
      return;
    }

    execution.state = TaskExecutionState.finishing;
    _executions.remove(taskId);
    if (_foregroundTaskId == taskId) {
      _foregroundTaskId = null;
    }

    if (observation.status == FfmpegProcessObservationStatus.completed) {
      final completedTask = task.markCompleted(
        completedAt: (await now()).millisecondsSinceEpoch,
      );
      await repository.saveTask(completedTask);
    } else {
      final failedTask = task.markFailed(
        observation.message ?? 'FFmpeg 执行失败',
        failedAt: (await now()).millisecondsSinceEpoch,
      );
      await repository.saveTask(failedTask);
    }

    await cleanupPlanFiles(execution.plan);
    await continueAfterTask();
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

  Future<void> continueAfterTask() async {
    final tasks = await repository.loadAllTasks();
    final nextStatus = resolveQueueStatus(tasks);

    if (nextStatus == FfmpegQueueStatus.running) {
      _queueStatus = FfmpegQueueStatus.running;
      return;
    }

    if (nextStatus == FfmpegQueueStatus.ready) {
      if (!continuousExecutionEnabled || _foregroundTaskId != null) {
        _queueStatus = FfmpegQueueStatus.ready;
        return;
      }

      final nextTask = nextPendingTask(tasks);
      if (nextTask != null) {
        await startTask(nextTask);
        return;
      }

      _queueStatus = FfmpegQueueStatus.ready;
      return;
    }

    _queueStatus = FfmpegQueueStatus.idle;
  }

  FfmpegQueueStatus resolveQueueStatus(List<MediaTask> tasks) {
    if (_foregroundTaskId != null ||
        tasks.any((task) => task.status == TaskStatus.running)) {
      return FfmpegQueueStatus.running;
    }

    if (_executions.values.any(
          (execution) => execution.state == TaskExecutionState.paused,
        ) ||
        tasks.any(
          (task) =>
              task.status == TaskStatus.pending ||
              task.status == TaskStatus.paused,
        )) {
      return FfmpegQueueStatus.ready;
    }

    return FfmpegQueueStatus.idle;
  }

  MediaTask? nextPendingTask(List<MediaTask> tasks) {
    final pendingTasks =
        tasks.where((task) => task.status == TaskStatus.pending).toList()
          ..sort((first, second) {
            final order = first.sortOrder.compareTo(second.sortOrder);
            if (order != 0) {
              return order;
            }

            return first.createdAt.compareTo(second.createdAt);
          });

    if (pendingTasks.isEmpty) {
      return null;
    }

    return pendingTasks.first;
  }

  TaskExecution? firstPausedExecution() {
    for (final execution in _executions.values) {
      if (execution.state == TaskExecutionState.paused) {
        return execution;
      }
    }

    return null;
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
