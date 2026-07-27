import 'package:framelean/application/services/execution/execution_queue_result.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';

class PauseAllMediaTaskExecutionsUseCase {
  final MediaTaskExecutionCoordinator executionCoordinator;

  const PauseAllMediaTaskExecutionsUseCase({
    required this.executionCoordinator,
  });

  Future<EngineQueueStartResult> call() {
    return executionCoordinator.pauseAll();
  }
}
