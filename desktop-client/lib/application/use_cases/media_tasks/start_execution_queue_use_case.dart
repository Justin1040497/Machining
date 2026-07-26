import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';

class StartExecutionQueueUseCase {
  final MediaTaskExecutionCoordinator executionCoordinator;

  const StartExecutionQueueUseCase({required this.executionCoordinator});

  Future<FfmpegQueueStartResult> call({
    // Retained for source compatibility while the workbench removes the
    // legacy compression-confirmation flow. Engine execution ignores it.
    bool allowExtremeCompression = false,
  }) {
    return executionCoordinator.startWorkbenchQueue();
  }
}
