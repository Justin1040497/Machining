/// 任务状态
enum TaskStatus {
  awaitAnalysis,
  analysisQueued,
  analyzing,
  ready,
  analysisFailed,
  executionQueued,
  running,
  preempting,
  preempted,
  resuming,
  paused,
  completed,
  executionFailed,
  cancelled,
  missingSource;

  @Deprecated('Use awaitAnalysis; persisted state is await_analysis.')
  static const TaskStatus awaitingAnalysis = TaskStatus.awaitAnalysis;

  @Deprecated('Use ready; persisted state is ready.')
  static const TaskStatus pending = TaskStatus.ready;

  @Deprecated('Use analysisFailed or executionFailed.')
  static const TaskStatus failed = TaskStatus.executionFailed;
}
