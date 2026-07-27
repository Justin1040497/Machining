import 'package:framelean/application/services/execution/execution_queue_result.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';

class StartExecutionQueueUseCase {
  final MediaTaskExecutionCoordinator executionCoordinator;

  const StartExecutionQueueUseCase({required this.executionCoordinator});

  Future<EngineQueueStartResult> call() {
    return executionCoordinator.startWorkbenchQueue();
  }
}
