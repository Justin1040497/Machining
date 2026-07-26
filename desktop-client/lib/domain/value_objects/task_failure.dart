enum TaskFailureStage {
  analysis,
  inputPreparation,
  commandPlanning,
  outputPreflight,
  processStart,
  processing,
  outputValidation,
  outputPublication,
  cleanup,
  recovery,
  unknown,
}

enum TaskFailureCode {
  analysisRuntimeUnavailable,
  analysisFailed,
  unsupportedMedia,
  corruptMedia,
  sourceUnavailable,
  inputPreparationFailed,
  commandBuildFailed,
  unsupportedConfiguration,
  encoderUnavailable,
  outputDirectoryCreationFailed,
  outputDirectoryNotWritable,
  invalidOutputPath,
  insufficientDiskSpace,
  securitySoftwareBlocked,
  outputFileInUse,
  processStartFailed,
  engineExecutionUnavailable,
  processExitedAbnormally,
  processStalled,
  processInterrupted,
  hardwareSessionLost,
  ineffectiveCompression,
  outputMissing,
  outputUnreadable,
  outputPublishFailed,
  cleanupFailed,
  applicationInterrupted,
  unknown,
}

enum TaskRecoveryAction {
  retryAnalysis,
  retryExecution,
  editConfiguration,
  chooseOutputDirectory,
  relinkSource,
  inspectLog,
  none,
}

class TaskFailure {
  const TaskFailure({
    required this.stage,
    required this.code,
    required this.userMessage,
    required this.technicalSummary,
    required this.occurredAt,
    required this.retryable,
  });

  final TaskFailureStage stage;
  final TaskFailureCode code;
  final String userMessage;
  final String technicalSummary;
  final int occurredAt;
  final bool retryable;

  TaskRecoveryAction get recoveryAction {
    if (code == TaskFailureCode.sourceUnavailable) {
      return TaskRecoveryAction.relinkSource;
    }
    if (stage == TaskFailureStage.analysis) {
      return retryable
          ? TaskRecoveryAction.retryAnalysis
          : TaskRecoveryAction.none;
    }
    if (stage == TaskFailureStage.commandPlanning ||
        code == TaskFailureCode.unsupportedConfiguration ||
        code == TaskFailureCode.encoderUnavailable ||
        code == TaskFailureCode.ineffectiveCompression) {
      return TaskRecoveryAction.editConfiguration;
    }
    if (stage == TaskFailureStage.outputPreflight ||
        stage == TaskFailureStage.outputPublication ||
        code == TaskFailureCode.outputDirectoryCreationFailed ||
        code == TaskFailureCode.outputDirectoryNotWritable ||
        code == TaskFailureCode.invalidOutputPath ||
        code == TaskFailureCode.insufficientDiskSpace ||
        code == TaskFailureCode.securitySoftwareBlocked ||
        code == TaskFailureCode.outputFileInUse) {
      return TaskRecoveryAction.chooseOutputDirectory;
    }
    if (retryable) {
      return TaskRecoveryAction.retryExecution;
    }
    if (stage == TaskFailureStage.processing ||
        stage == TaskFailureStage.outputValidation ||
        stage == TaskFailureStage.cleanup ||
        stage == TaskFailureStage.recovery ||
        stage == TaskFailureStage.unknown) {
      return TaskRecoveryAction.inspectLog;
    }
    return TaskRecoveryAction.none;
  }
}
