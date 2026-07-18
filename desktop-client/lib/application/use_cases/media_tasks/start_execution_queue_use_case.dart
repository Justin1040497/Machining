import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';

class StartExecutionQueueUseCase {
  final FfmpegTaskQueueRunner queueRunner;

  const StartExecutionQueueUseCase({required this.queueRunner});

  Future<FfmpegQueueStartResult> call({bool allowExtremeCompression = false}) {
    return queueRunner.startWorkbenchQueue(
      allowExtremeCompression: allowExtremeCompression,
    );
  }
}
