import 'dart:async';
import 'dart:io';

import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/execution/execution_resource_guard.dart';
import 'package:framelean/application/services/execution/output_preflight_service.dart';
import 'package:framelean/application/services/execution/task_execution_notification_summary.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/domain/enums/task_status.dart';
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
  queued,
  throttled,
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
  PreparedMediaInput preparedInput;
  int stepIndex;
  TaskExecutionState state;

  TaskExecution({
    required this.taskId,
    required this.ffmpegPath,
    required this.plan,
    required this.logFile,
    required this.startedProcess,
    required this.observationFuture,
    required this.preparedInput,
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

  Set<String> get runningTaskIds;

  int get activeExecutionCount;

  int get effectiveMaxConcurrentExecutions;

  Future<FfmpegQueueStatus> refreshStatus();

  Future<FfmpegQueueStartResult> start({bool allowExtremeCompression = false});

  Future<FfmpegQueueStartResult> startOrResumeTask(
    String taskId, {
    bool allowExtremeCompression = false,
  });

  Future<FfmpegQueueStartResult> pauseTask(String taskId);

  Future<FfmpegQueueStartResult> pauseAllRunningTasks();

  Future<FfmpegQueueStartResult> cancelTask(String taskId);

  Future<void> cancelAllExecutions();
}

class DefaultFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  final MediaTaskRepository repository;
  final TaskFolderRepository taskFolderRepository;
  final SourceFileChecker sourceFileChecker;
  final Future<AppSettings> Function() readSettings;
  final Future<ResolvedFfmpegRuntime> Function() readRuntime;
  final FfmpegCommandBuilder commandBuilder;
  final ExecutionResourceGuard resourceGuard;
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
  Future<FfmpegQueueStartResult>? _startFuture;
  bool _queueRunIntentActive = false;
  final List<String> _priorityTaskIds = [];
  int _effectiveMaxConcurrentExecutions = defaultMaxConcurrentExecutions;

  DefaultFfmpegTaskQueueRunner({
    required this.repository,
    required this.taskFolderRepository,
    required this.sourceFileChecker,
    required this.readSettings,
    required this.readRuntime,
    required this.commandBuilder,
    required this.resourceGuard,
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
  }) : now = now ?? (() async => DateTime.now());

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

    _queueRunIntentActive = true;
    final startFuture = _start(
      allowExtremeCompression: allowExtremeCompression,
    );
    _startFuture = startFuture;
    unawaited(
      startFuture
          .then((result) {
            if (result.outcome ==
                    FfmpegQueueStartOutcome.compressionConfirmationRequired ||
                result.outcome == FfmpegQueueStartOutcome.noPendingTask ||
                result.outcome == FfmpegQueueStartOutcome.notReady) {
              _queueRunIntentActive = false;
            }
          })
          .whenComplete(() {
            _startFuture = null;
          })
          .catchError((_) {
            _queueRunIntentActive = false;
          }),
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

    if (!isStartableTask(task)) {
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        task: task,
        message: '当前任务状态不允许开始',
      );
    }

    _queueRunIntentActive = true;
    final execution = _executions[taskId];
    if (execution != null) {
      if (!await _hasCapacityFor(task, excludedTaskId: taskId)) {
        _prioritizeTask(taskId);
        return FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.queued,
          task: task,
          message: '任务已插队，等待空闲执行位',
        );
      }
      return resumeExecution(task, execution);
    }

    if (!await _hasCapacityFor(task)) {
      _prioritizeTask(taskId);
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.queued,
        task: task,
        message: '任务已插队，等待空闲执行位',
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

    await processController.pause(execution.startedProcess);
    execution.state = TaskExecutionState.paused;
    final task = findTaskById(await repository.loadAllTasks(), taskId);
    final pausedTask = task?.markPaused();
    if (pausedTask != null) {
      await repository.saveTask(pausedTask);
    }
    await continueAfterTask(excludedTaskId: taskId);
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
      task: pausedTask,
      message: '任务已挂起',
    );
  }

  @override
  Future<FfmpegQueueStartResult> pauseAllRunningTasks() async {
    _queueRunIntentActive = false;

    final tasks = await repository.loadAllTasks();
    final tasksById = {for (final task in tasks) task.id: task};
    MediaTask? lastPausedTask;

    for (final execution in _executions.values) {
      if (execution.state != TaskExecutionState.running) {
        continue;
      }

      await processController.pause(execution.startedProcess);
      execution.state = TaskExecutionState.paused;

      final task = tasksById[execution.taskId];
      if (task == null) {
        continue;
      }

      final pausedTask = task.markPaused();
      await repository.saveTask(pausedTask);
      lastPausedTask = pausedTask;
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
    if (execution != null) {
      await processController.terminate(execution.startedProcess);
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
    await continueAfterTask();
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.cancelled,
      task: cancelledTask,
      message: '任务已取消',
    );
  }

  @override
  Future<void> cancelAllExecutions() async {
    _queueRunIntentActive = false;
    for (final execution in [..._executions.values]) {
      execution.state = TaskExecutionState.finishing;
      await processController.terminate(execution.startedProcess);
      await cleanupPlanFiles(execution.plan);
      await mediaInputPreparer.cleanup(execution.preparedInput);
    }

    _executions.clear();
    _queueStatus = FfmpegQueueStatus.idle;
  }

  Future<FfmpegQueueStartResult> _start({
    required bool allowExtremeCompression,
  }) async {
    await refreshStatus();
    if (_queueStatus == FfmpegQueueStatus.idle) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.notReady,
        message: '没有可执行的任务',
      );
    }

    return fillAvailableSlots(allowExtremeCompression: allowExtremeCompression);
  }

  Future<FfmpegQueueStartResult> runNextStartableTask({
    bool allowExtremeCompression = false,
  }) async {
    final tasks = await repository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final task = nextStartableTask(tasks, folders: folders);
    if (task == null) {
      await refreshStatus();
      _queueRunIntentActive = false;
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.noPendingTask,
        message: '没有找到可执行任务',
      );
    }

    final execution = _executions[task.id];
    if (execution != null) {
      return resumeExecution(task, execution);
    }

    return startTask(task, allowExtremeCompression: allowExtremeCompression);
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

      final priorityTask = _nextPriorityTask(
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
          await _nextOrdinaryStartableTaskAllowed(
            tasks: tasks,
            folders: folders,
            runningTasks: runningTasks,
            userMaxConcurrentExecutions: settings.maxConcurrentExecutions,
            excludedTaskId: excludedTaskId,
          );
      if (nextTask == null) {
        await refreshStatus();
        if (_hasStartableCandidate(
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
        if (firstResult != null) {
          return firstResult;
        }
        _queueRunIntentActive = false;
        return const FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.noPendingTask,
          message: '没有找到可执行任务',
        );
      }

      _priorityTaskIds.remove(nextTask.id);
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
          result.outcome == FfmpegQueueStartOutcome.processStartFailed) {
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

  MediaTask? _nextPriorityTask(
    List<MediaTask> tasks, {
    String? excludedTaskId,
  }) {
    _priorityTaskIds.removeWhere(
      (taskId) =>
          taskId == excludedTaskId ||
          !tasks.any((task) => task.id == taskId && isStartableTask(task)),
    );
    for (final taskId in _priorityTaskIds) {
      final task = findTaskById(tasks, taskId);
      if (task != null && isStartableTask(task)) {
        return task;
      }
    }
    return null;
  }

  Future<MediaTask?> _nextOrdinaryStartableTaskAllowed({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
    required List<MediaTask> runningTasks,
    required int userMaxConcurrentExecutions,
    String? excludedTaskId,
  }) async {
    for (final task in expandedExecutionOrder(tasks, folders)) {
      if (task.id == excludedTaskId ||
          _priorityTaskIds.contains(task.id) ||
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

  bool _hasStartableCandidate(
    List<MediaTask> tasks, {
    required List<TaskFolder> folders,
    String? excludedTaskId,
  }) {
    return expandedExecutionOrder(
      tasks,
      folders,
    ).any((task) => task.id != excludedTaskId && isStartableTask(task));
  }

  void _prioritizeTask(String taskId) {
    _priorityTaskIds.remove(taskId);
    _priorityTaskIds.insert(0, taskId);
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
      await publishTaskFailed(failedTask, failureSummary(failedTask));
      await continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.ffmpegUnavailable,
        task: failedTask,
        message: 'FFmpeg 不可用',
      );
    }

    PreparedMediaInput? preparedInput;
    late FfmpegCommandPlan plan;
    var preflightTags = const <MediaTaskPolicyTag>{};
    try {
      preparedInput = await mediaInputPreparer.prepare(
        task,
        purpose: MediaInputPreparationPurpose.execution,
      );
      plan = commandBuilder.build(
        preparedInput.task,
        allowExtremeCompression: allowExtremeCompression,
        encoderCapabilities: runtime.encoderCapabilities,
      );
      final preflight = await outputPreflightService.prepare(
        task: preparedInput.task,
        plan: plan,
      );
      plan = preflight.plan;
      preflightTags = preflight.policyTags;
    } on CompressionConfirmationRequiredException catch (error) {
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
      final input = preparedInput;
      if (input != null) {
        await mediaInputPreparer.cleanup(input);
      }
      final failedTask = task.markFailed(error.toString());
      await repository.saveTask(failedTask);
      await publishTaskFailed(failedTask, failureSummary(failedTask));
      await continueAfterTask();
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
    final startedAt = (await now()).millisecondsSinceEpoch;
    final runningTask = task
        .withPolicyTags(preflightTags)
        .markRunning(outputPath: plan.outputPath, startedAt: startedAt);
    await repository.saveTask(runningTask);

    late final TaskExecution execution;
    try {
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
      final failedTask = runningTask.markFailed('FFmpeg 启动失败: $error');
      await repository.saveTask(failedTask);
      await publishTaskFailed(failedTask, failureSummary(failedTask));
      await mediaInputPreparer.cleanup(executionInput);
      await continueAfterTask();
      return FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.processStartFailed,
        task: failedTask,
        message: error.toString(),
      );
    }

    _executions[runningTask.id] = execution;
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
    required PreparedMediaInput preparedInput,
    required int stepIndex,
    required String ffmpegPath,
    required File logFile,
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
      outputPath: step.outputPath,
      progressMode: step.progressMode,
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
      preparedInput: preparedInput,
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

    await processController.resume(execution.startedProcess);
    execution.state = TaskExecutionState.running;
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
      await mediaInputPreparer.cleanup(execution.preparedInput);
      await continueAfterTask();
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
        final ineffectiveOutputSize = currentStep.outputPath == null
            ? null
            : await _getFileSize(currentStep.outputPath!);
        await deleteStepOutput(currentStep);
        final message = outputIsSmaller == null
            ? '图片压缩结果无法验证，未保留本次输出。'
            : '图片未有效压缩：输出文件不小于源文件，已清理本次无效输出。';

        if (currentStep.completionPolicy ==
                FfmpegStepCompletionPolicy.completeIfOutputSmallerThanSource &&
            execution.stepIndex < execution.plan.steps.length - 1) {
          // Continue to the fallback step below.
        } else {
          execution.state = TaskExecutionState.finishing;
          _executions.remove(taskId);

          await appendExecutionLogFooter(
            execution.logFile,
            success: false,
            message: message,
          );

          final failedTask = task
              .withPolicyTags(const {MediaTaskPolicyTag.ineffectiveCompression})
              .markFailed(
                message,
                failedAt: (await now()).millisecondsSinceEpoch,
              )
              .copyWith(clearOutputPath: true);
          await repository.saveTask(failedTask);
          await publishTaskFailed(
            failedTask,
            failureSummary(failedTask, outputFileSize: ineffectiveOutputSize),
          );
          await cleanupPlanFiles(execution.plan);
          await mediaInputPreparer.cleanup(execution.preparedInput);
          await continueAfterTask();
          return;
        }
      }
    }

    if (observation.status == FfmpegProcessObservationStatus.completed &&
        !completeCurrentPlan &&
        execution.stepIndex < execution.plan.steps.length - 1) {
      final nextStepIndex = execution.stepIndex + 1;
      try {
        final nextExecution = await startExecutionStep(
          task: task,
          plan: execution.plan,
          preparedInput: execution.preparedInput,
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
        await cleanupPlanFiles(execution.plan);
        await mediaInputPreparer.cleanup(execution.preparedInput);

        await appendExecutionLogFooter(
          execution.logFile,
          success: false,
          message: 'FFmpeg 启动失败: $error',
        );

        final failedTask = task.markFailed(
          'FFmpeg 启动失败: $error',
          failedAt: (await now()).millisecondsSinceEpoch,
        );
        await repository.saveTask(failedTask);
        await publishTaskFailed(failedTask, failureSummary(failedTask));
        await continueAfterTask();
      }
      return;
    }

    execution.state = TaskExecutionState.finishing;
    _executions.remove(taskId);

    if (observation.status == FfmpegProcessObservationStatus.completed) {
      final completedAt = (await now()).millisecondsSinceEpoch;
      final outputSize = task.outputPath != null
          ? await _getFileSize(task.outputPath!)
          : null;
      final completedTask = task.markCompleted(
        completedAt: completedAt,
        outputFileSize: outputSize,
      );
      final durationMs = task.startedAt != null
          ? completedAt - task.startedAt!
          : null;

      await appendExecutionLogFooter(
        execution.logFile,
        success: true,
        outputPath: task.outputPath,
        outputSize: outputSize,
        durationMs: durationMs,
      );

      await repository.saveTask(completedTask);
      await publishTaskCompleted(
        completedTask,
        TaskExecutionNotificationSummary(
          sourceFileSize: task.sourceFileFingerprint?.fileSize,
          outputFileSize: outputSize,
          durationMs: durationMs,
          outputPath: task.outputPath,
        ),
      );
    } else {
      await appendExecutionLogFooter(
        execution.logFile,
        success: false,
        message: observation.message ?? 'FFmpeg 执行失败',
      );

      final failedTask = task.markFailed(
        observation.message ?? 'FFmpeg 执行失败',
        failedAt: (await now()).millisecondsSinceEpoch,
      );
      await repository.saveTask(failedTask);
      await publishTaskFailed(failedTask, failureSummary(failedTask));
    }

    await cleanupPlanFiles(execution.plan);
    await mediaInputPreparer.cleanup(execution.preparedInput);
    await continueAfterTask();
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

  TaskExecutionNotificationSummary failureSummary(
    MediaTask task, {
    int? outputFileSize,
    int? durationMs,
  }) {
    return TaskExecutionNotificationSummary(
      sourceFileSize: task.sourceFileFingerprint?.fileSize,
      outputFileSize: outputFileSize,
      durationMs: durationMs,
      outputPath: task.outputPath,
      failureReason: task.errorMessage,
      failureSuggestion: failureSuggestionFor(task),
    );
  }

  String failureSuggestionFor(MediaTask task) {
    final reason = task.errorMessage?.trim() ?? '';
    final ineffectiveOutput =
        reason.contains('不小于源文件') ||
        reason.contains('未有效压缩') ||
        reason.contains('无法验证');
    if (task.mediaKind == MediaKind.image && ineffectiveOutput) {
      return '建议切换 WebP/JPG 格式、降低质量，或更换输出格式后重新压缩。';
    }
    return '建议查看任务日志，确认源文件、输出目录和 FFmpeg 运行时后重试。';
  }

  Future<bool?> isStepOutputSmallerThanSource(
    MediaTask task,
    FfmpegCommandStep step,
  ) async {
    if (task.mediaKind != MediaKind.image) {
      return true;
    }
    final outputPath = step.outputPath;
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
    final outputPath = step.outputPath;
    if (outputPath == null) {
      return;
    }
    try {
      final output = File(outputPath);
      if (await output.exists()) {
        await output.delete();
      }
    } on Object {
      // Best-effort cleanup; the task result still reflects ineffective output.
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

  Future<void> continueAfterTask({String? excludedTaskId}) async {
    if (!continuousExecutionEnabled || !_queueRunIntentActive) {
      await refreshStatus();
      return;
    }

    await fillAvailableSlots(excludedTaskId: excludedTaskId);
  }

  FfmpegQueueStatus resolveQueueStatus(List<MediaTask> tasks) {
    if (runningTaskIds.isNotEmpty ||
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
    final folderTasksById = <String, List<MediaTask>>{};
    for (final task in tasks) {
      final folderId = task.folderId;
      if (folderId == null) {
        continue;
      }
      folderTasksById.putIfAbsent(folderId, () => []).add(task);
    }

    for (final folderTasks in folderTasksById.values) {
      folderTasks.sort(_compareFolderTasksForExecution);
    }

    final topLevelItems = <_ExecutionTopLevelItem>[
      for (final folder in folders)
        _ExecutionTopLevelItem.folder(
          folder,
          folderTasksById[folder.id] ?? const <MediaTask>[],
        ),
      for (final task in tasks.where((task) => task.folderId == null))
        _ExecutionTopLevelItem.task(task),
    ]..sort(_compareTopLevelItemsForExecution);

    return [
      for (final item in topLevelItems)
        if (item.task != null) item.task! else ...item.folderTasks,
    ];
  }

  bool isStartableTask(MediaTask task) {
    return task.status == TaskStatus.pending ||
        task.status == TaskStatus.paused;
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

  int _compareTopLevelItemsForExecution(
    _ExecutionTopLevelItem a,
    _ExecutionTopLevelItem b,
  ) {
    final order = a.sortOrder.compareTo(b.sortOrder);
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

class _ExecutionTopLevelItem {
  const _ExecutionTopLevelItem._({
    required this.sortOrder,
    required this.createdAt,
    required this.folderTasks,
    this.task,
  });

  factory _ExecutionTopLevelItem.task(MediaTask task) {
    return _ExecutionTopLevelItem._(
      sortOrder: task.sortOrder,
      createdAt: task.createdAt,
      folderTasks: const [],
      task: task,
    );
  }

  factory _ExecutionTopLevelItem.folder(
    TaskFolder folder,
    List<MediaTask> folderTasks,
  ) {
    return _ExecutionTopLevelItem._(
      sortOrder: folder.sortOrder,
      createdAt: folder.createdAt,
      folderTasks: folderTasks,
    );
  }

  final int sortOrder;
  final int createdAt;
  final MediaTask? task;
  final List<MediaTask> folderTasks;
}
