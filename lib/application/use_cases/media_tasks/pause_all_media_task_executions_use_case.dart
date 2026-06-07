import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';

class PauseAllMediaTaskExecutionsUseCase {
  final FfmpegTaskQueueRunner queueRunner;

  const PauseAllMediaTaskExecutionsUseCase({required this.queueRunner});

  Future<FfmpegQueueStartResult> call() {
    return queueRunner.pauseAllRunningTasks();
  }
}
