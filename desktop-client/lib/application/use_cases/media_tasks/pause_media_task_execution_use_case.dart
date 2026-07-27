import 'package:framelean/application/services/execution/execution_queue_result.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';

class PauseMediaTaskExecutionUseCase {
  final MediaTaskExecutionCoordinator executionCoordinator;

  const PauseMediaTaskExecutionUseCase({required this.executionCoordinator});

  Future<EngineQueueStartResult> call(String taskId) {
    return executionCoordinator.pauseTask(taskId);
  }
}
