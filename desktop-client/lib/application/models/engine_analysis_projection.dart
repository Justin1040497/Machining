/// Client-side projection that associates a product task with an FEngine
/// analysis snapshot.
///
/// [snapshotJson] is intentionally opaque. The Client persists and forwards
/// the FLL-owned document without mirroring its nested fields into the product
/// task schema.
class EngineAnalysisProjection {
  const EngineAnalysisProjection({
    required this.taskId,
    required this.clientFileId,
    required this.engineSessionId,
    required this.lastEventSequence,
    required this.updatedAt,
    this.analysisId,
    this.revision,
    this.schemaVersion,
    this.snapshotJson,
    this.validityStatus,
    this.analysisWorkId,
    this.analysisRequestId,
    this.analysisQueuePosition,
    this.analysisQueueRevision,
    this.executionId,
    this.executionRequestId,
    this.executionQueuePosition,
    this.executionQueueRevision,
    this.executionState,
    this.pauseReason,
    this.preemptedByExecutionId,
    this.resumeDepth,
    this.mediaTimeUs,
    this.processedBytes,
  }) : assert(taskId != ''),
       assert(clientFileId != ''),
       assert(engineSessionId != ''),
       assert(revision == null || revision >= 0),
       assert(lastEventSequence >= 0);

  final String taskId;
  final String clientFileId;
  final String engineSessionId;
  final String? analysisId;
  final int? revision;
  final String? schemaVersion;
  final String? snapshotJson;
  final String? validityStatus;
  final String? analysisWorkId;
  final String? analysisRequestId;
  final int? analysisQueuePosition;
  final int? analysisQueueRevision;
  final String? executionId;
  final String? executionRequestId;
  final int? executionQueuePosition;
  final int? executionQueueRevision;
  final String? executionState;
  final String? pauseReason;
  final String? preemptedByExecutionId;
  final int? resumeDepth;
  final int? mediaTimeUs;
  final int? processedBytes;
  final int lastEventSequence;
  final DateTime updatedAt;

  EngineAnalysisProjection copyWith({
    String? engineSessionId,
    String? analysisWorkId,
    bool clearAnalysisWorkId = false,
    String? analysisRequestId,
    bool clearAnalysisRequestId = false,
    int? analysisQueuePosition,
    bool clearAnalysisQueuePosition = false,
    int? analysisQueueRevision,
    String? executionId,
    bool clearExecutionId = false,
    String? executionRequestId,
    bool clearExecutionRequestId = false,
    int? executionQueuePosition,
    bool clearExecutionQueuePosition = false,
    int? executionQueueRevision,
    String? executionState,
    bool clearExecutionState = false,
    String? pauseReason,
    bool clearPauseReason = false,
    String? preemptedByExecutionId,
    bool clearPreemptedByExecutionId = false,
    int? resumeDepth,
    int? mediaTimeUs,
    int? processedBytes,
    int? lastEventSequence,
    DateTime? updatedAt,
  }) {
    return EngineAnalysisProjection(
      taskId: taskId,
      clientFileId: clientFileId,
      engineSessionId: engineSessionId ?? this.engineSessionId,
      analysisId: analysisId,
      revision: revision,
      schemaVersion: schemaVersion,
      snapshotJson: snapshotJson,
      validityStatus: validityStatus,
      analysisWorkId: clearAnalysisWorkId
          ? null
          : analysisWorkId ?? this.analysisWorkId,
      analysisRequestId: clearAnalysisRequestId
          ? null
          : analysisRequestId ?? this.analysisRequestId,
      analysisQueuePosition: clearAnalysisQueuePosition
          ? null
          : analysisQueuePosition ?? this.analysisQueuePosition,
      analysisQueueRevision:
          analysisQueueRevision ?? this.analysisQueueRevision,
      executionId: clearExecutionId ? null : executionId ?? this.executionId,
      executionRequestId: clearExecutionRequestId
          ? null
          : executionRequestId ?? this.executionRequestId,
      executionQueuePosition: clearExecutionQueuePosition
          ? null
          : executionQueuePosition ?? this.executionQueuePosition,
      executionQueueRevision:
          executionQueueRevision ?? this.executionQueueRevision,
      executionState: clearExecutionState
          ? null
          : executionState ?? this.executionState,
      pauseReason: clearPauseReason ? null : pauseReason ?? this.pauseReason,
      preemptedByExecutionId: clearPreemptedByExecutionId
          ? null
          : preemptedByExecutionId ?? this.preemptedByExecutionId,
      resumeDepth: resumeDepth ?? this.resumeDepth,
      mediaTimeUs: mediaTimeUs ?? this.mediaTimeUs,
      processedBytes: processedBytes ?? this.processedBytes,
      lastEventSequence: lastEventSequence ?? this.lastEventSequence,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
