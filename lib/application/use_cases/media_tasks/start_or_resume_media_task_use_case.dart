import 'package:machining/application/services/execution/ffmpeg_task_queue_runner.dart';

class StartOrResumeMediaTaskUseCase {
  final FfmpegTaskQueueRunner queueRunner;

  const StartOrResumeMediaTaskUseCase({required this.queueRunner});

  Future<FfmpegQueueStartResult> call(
    String taskId, {
    bool allowExtremeCompression = false,
  }) {
    return queueRunner.startOrResumeTask(
      taskId,
      allowExtremeCompression: allowExtremeCompression,
    );
  }
}
