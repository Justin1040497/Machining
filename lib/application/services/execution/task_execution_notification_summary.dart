class TaskExecutionNotificationSummary {
  const TaskExecutionNotificationSummary({
    this.sourceFileSize,
    this.outputFileSize,
    this.durationMs,
    this.outputPath,
    this.failureReason,
    this.failureSuggestion,
  });

  final int? sourceFileSize;
  final int? outputFileSize;
  final int? durationMs;
  final String? outputPath;
  final String? failureReason;
  final String? failureSuggestion;
}
