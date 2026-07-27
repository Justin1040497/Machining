import 'package:framelean/application/services/execution/execution_queue_result.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';

class StartOrResumeMediaTaskUseCase {
  final MediaTaskExecutionCoordinator executionCoordinator;

  const StartOrResumeMediaTaskUseCase({required this.executionCoordinator});

  Future<EngineQueueStartResult> call(
    String taskId, {
    // Retained for source compatibility while the workbench removes the
    // legacy compression-confirmation flow. Engine execution ignores it.
    bool allowExtremeCompression = false,
  }) {
    return executionCoordinator.startSingleTask(taskId);
  }
}
