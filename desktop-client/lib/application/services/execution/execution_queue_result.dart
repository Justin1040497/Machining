import 'package:framelean/domain/library.dart';

/// Result terminology kept stable at the Client boundary while FEngine owns
/// the actual queue and execution lane.
enum EngineQueueStartOutcome {
  started,
  resumed,
  paused,
  cancelled,
  notFound,
  invalidTaskState,
  notReady,
  alreadyRunning,
  noPendingTask,
  missingSource,
  compressionConfirmationRequired,
  queued,
  throttled,
  completed,
  executionFailed,
}

class EngineQueueStartResult {
  final EngineQueueStartOutcome outcome;
  final MediaTask? task;
  final String? message;

  const EngineQueueStartResult({
    required this.outcome,
    this.task,
    this.message,
  });
}
