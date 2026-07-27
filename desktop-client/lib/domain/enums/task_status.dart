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
}
