import 'dart:async';
import 'dart:io';

import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/domain/entities/media_task.dart';
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
  final SourceFileChecker sourceFileChecker;
  final Future<ResolvedFfmpegRuntime> Function() readRuntime;
  final FfmpegCommandBuilder commandBuilder;
  final MediaInputPreparer mediaInputPreparer;
  final FfmpegProcessStarter processStarter;
  final FfmpegProcessController processController;
  final FfmpegProcessObserver processObserver;
  final bool continuousExecutionEnabled;
  final Future<DateTime> Function() now;
  final Future<String> Function(MediaTask task, FfmpegCommandPlan plan)
  createLogFilePath;

  final Map<String, TaskExecution> _executions = {};
  FfmpegQueueStatus _queueStatus = FfmpegQueueStatus.idle;
  String? _foregroundTaskId;
  Future<FfmpegQueueStartResult>? _startFuture;
  bool _queueRunIntentActive = false;

  DefaultFfmpegTaskQueueRunner({
    required this.repository,
    required this.sourceFileChecker,
    required this.readRuntime,
    required this.commandBuilder,
    this.mediaInputPreparer = const NoopMediaInputPreparer(),
    required this.processStarter,
    required this.processController,
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

    final foregroundId = _foregroundTaskId;
    if (foregroundId != null && foregroundId != taskId) {
      await suspendForegroundTask();
    }

    _queueRunIntentActive = true;
    final execution = _executions[taskId];
    if (execution != null) {
      return resumeExecution(task, execution);
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
      if (_foregroundTaskId == execution.taskId) {
        _foregroundTaskId = null;
      }

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

    if (_foregroundTaskId == taskId) {
      _foregroundTaskId = null;
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

    return runNextStartableTask(
      allowExtremeCompression: allowExtremeCompression,
    );
  }

  Future<FfmpegQueueStartResult> runNextStartableTask({
    bool allowExtremeCompression = false,
  }) async {
    final tasks = await repository.loadAllTasks();
    final task = nextStartableTask(tasks);
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

    PreparedMediaInput? preparedInput;
    late final FfmpegCommandPlan plan;
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
    final runningTask = task.markRunning(
      outputPath: plan.outputPath,
      startedAt: startedAt,
    );
    await repository.saveTask(runningTask);

    late final TaskExecution execution;
    try {
      execution = await startExecutionStep(
        task: executionInput.task.copyWith(
          status: runningTask.status,
          outputPath: runningTask.outputPath,
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
      await mediaInputPreparer.cleanup(executionInput);
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
    required PreparedMediaInput preparedInput,
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

    await processController.pause(execution.startedProcess);
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
    if (execution == null) {
      return;
    }

    final task = findTaskById(await repository.loadAllTasks(), taskId);
    if (task == null || task.status == TaskStatus.cancelled) {
      _executions.remove(taskId);
      if (_foregroundTaskId == taskId) {
        _foregroundTaskId = null;
      }
      await mediaInputPreparer.cleanup(execution.preparedInput);
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
        if (_foregroundTaskId == taskId) {
          _foregroundTaskId = null;
        }
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
      final completedAt = (await now()).millisecondsSinceEpoch;
      final completedTask = task.markCompleted(completedAt: completedAt);
      final outputSize = task.outputPath != null
          ? await _getFileSize(task.outputPath!)
          : null;
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
    }

    await cleanupPlanFiles(execution.plan);
    await mediaInputPreparer.cleanup(execution.preparedInput);
    await continueAfterTask();
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
    final tasks = await repository.loadAllTasks();
    final nextStatus = resolveQueueStatus(tasks);

    if (nextStatus == FfmpegQueueStatus.running) {
      _queueStatus = FfmpegQueueStatus.running;
      return;
    }

    if (nextStatus == FfmpegQueueStatus.ready) {
      if (!continuousExecutionEnabled ||
          !_queueRunIntentActive ||
          _foregroundTaskId != null) {
        _queueStatus = FfmpegQueueStatus.ready;
        return;
      }

      final nextTask = nextStartableTask(tasks, excludedTaskId: excludedTaskId);
      if (nextTask != null) {
        final execution = _executions[nextTask.id];
        if (execution != null) {
          await resumeExecution(nextTask, execution);
        } else {
          await startTask(nextTask);
        }
        return;
      }

      _queueStatus = FfmpegQueueStatus.ready;
      return;
    }

    _queueRunIntentActive = false;
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

  MediaTask? nextStartableTask(
    List<MediaTask> tasks, {
    String? excludedTaskId,
  }) {
    final startableTasks =
        tasks
            .where((task) => task.id != excludedTaskId && isStartableTask(task))
            .toList()
          ..sort((first, second) {
            final order = first.sortOrder.compareTo(second.sortOrder);
            if (order != 0) {
              return order;
            }

            return first.createdAt.compareTo(second.createdAt);
          });

    if (startableTasks.isEmpty) {
      return null;
    }

    return startableTasks.first;
  }

  bool isStartableTask(MediaTask task) {
    return task.status == TaskStatus.pending ||
        task.status == TaskStatus.paused;
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
