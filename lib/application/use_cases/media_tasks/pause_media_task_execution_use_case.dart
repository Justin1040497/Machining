import 'package:machining/application/services/execution/ffmpeg_task_queue_runner.dart';

class PauseMediaTaskExecutionUseCase {
  final FfmpegTaskQueueRunner queueRunner;

  const PauseMediaTaskExecutionUseCase({required this.queueRunner});

  Future<FfmpegQueueStartResult> call(String taskId) {
    return queueRunner.pauseTask(taskId);
  }
}
