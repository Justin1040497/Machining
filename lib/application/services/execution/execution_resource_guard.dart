import 'package:framelean/domain/library.dart';

class ExecutionCapacity {
  const ExecutionCapacity({
    required this.effectiveMaxConcurrentExecutions,
    this.reason,
  });

  final int effectiveMaxConcurrentExecutions;
  final String? reason;
}

abstract class ExecutionResourceGuard {
  Future<ExecutionCapacity> capacity({
    required int userMaxConcurrentExecutions,
    required List<MediaTask> runningTasks,
  });

  Future<bool> canStartTask({
    required MediaTask task,
    required List<MediaTask> runningTasks,
    required int userMaxConcurrentExecutions,
  });
}

bool isHeavyExecutionTask(MediaTask task) {
  return task.mediaKind == MediaKind.video;
}
