import 'dart:async';
import 'dart:io';

import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/execution/media_work_scheduler.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';

enum TaskExecutionState { running, paused, finishing }

class TaskExecution {
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
    required this.runSequence,
    this.hardwareRetryCount = 0,
  });

  final String taskId;
  final String ffmpegPath;
  final FfmpegCommandPlan plan;
  final File logFile;
  StartedFfmpegProcess startedProcess;
  Future<FfmpegProcessObservation> observationFuture;
  PreparedMediaInput preparedInput;
  int stepIndex;
  TaskExecutionState state;
  int runSequence;
  Timer? outputMonitor;
  MediaWorkLease? schedulerLease;
  int hardwareRetryCount;
}

class TaskProcessLifecycle {
  const TaskProcessLifecycle(this.processController);

  final FfmpegProcessController processController;

  Future<void> pause(TaskExecution execution) async {
    await processController.pause(execution.startedProcess);
    execution.state = TaskExecutionState.paused;
  }

  Future<void> resume(TaskExecution execution) async {
    await processController.resume(execution.startedProcess);
    execution.state = TaskExecutionState.running;
  }

  Future<void> terminate(TaskExecution execution) {
    return processController.terminate(execution.startedProcess);
  }

  Future<void> releaseLease(TaskExecution execution) async {
    final lease = execution.schedulerLease;
    execution.schedulerLease = null;
    try {
      await lease?.release();
    } on Object {
      // Best-effort.
    }
  }
}
