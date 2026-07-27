import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_documents.dart';

enum EngineWorkPriority { background, normal, foreground }

enum EngineOutputCollisionPolicy { failIfExists, generateUnique }

enum EngineQueueKind { analysis, execution, control }

enum EngineExecutionState {
  queued,
  running,
  preempting,
  preempted,
  resuming,
  pauseRequested,
  paused,
  cancelRequested,
  cancelled,
  completed,
  failed,
}

enum EngineExecutionPauseReason { user, preemption }

enum EngineExecutionControlAction { pause, resume, cancel }

enum EngineWorkEventType {
  queued,
  started,
  completed,
  failed,
  snapshot,
  queueOrderApplied,
  queueOrderConflict,
  executionSubmitted,
  executionStarted,
  executionProgress,
  executionPaused,
  executionResumed,
  executionStateChanged,
  warning,
  sequenceGap,
  executionCompleted,
  executionFailed,
  executionCancelled,
}

enum EngineGatewayFailureKind { connection, protocol, worker, closed }

final class EngineSourceFacts {
  const EngineSourceFacts({
    required this.path,
    required this.fileSizeBytes,
    required this.modifiedTimeUnixNanos,
  }) : assert(path != ''),
       assert(fileSizeBytes >= 0);

  final String path;
  final int fileSizeBytes;
  final String? modifiedTimeUnixNanos;
}

final class EngineAnalysisRequest {
  const EngineAnalysisRequest({
    required this.clientTaskId,
    required this.clientFileId,
    required this.source,
    required this.taskMode,
    this.priority = EngineWorkPriority.normal,
    this.forceReanalysis = false,
    this.requestId,
  }) : assert(clientTaskId != ''),
       assert(clientFileId != '');

  final String clientTaskId;
  final String clientFileId;
  final EngineSourceFacts source;
  final EngineTaskMode taskMode;
  final EngineWorkPriority priority;
  final bool forceReanalysis;
  final String? requestId;
}

final class EnginePreviewFramesRequest {
  const EnginePreviewFramesRequest({
    required this.clientTaskId,
    required this.source,
    required this.outputDirectory,
    required this.timestampsUs,
    this.maxWidth,
    this.priority = EngineWorkPriority.foreground,
    this.requestId,
  }) : assert(clientTaskId != ''),
       assert(outputDirectory != ''),
       assert(timestampsUs.length > 0),
       assert(maxWidth == null || maxWidth > 0);

  final String clientTaskId;
  final EngineSourceFacts source;
  final String outputDirectory;
  final List<int> timestampsUs;
  final int? maxWidth;
  final EngineWorkPriority priority;
  final String? requestId;
}

final class EnginePreviewFrameArtifact {
  const EnginePreviewFrameArtifact({
    required this.index,
    required this.requestedTimestampUs,
    required this.decodedTimestampUs,
    required this.width,
    required this.height,
    required this.outputPath,
  });

  final int index;
  final int requestedTimestampUs;
  final int decodedTimestampUs;
  final int width;
  final int height;
  final String outputPath;
}

final class EnginePreviewFramesResult {
  const EnginePreviewFramesResult({
    required this.outputDirectory,
    required this.frames,
  });

  final String outputDirectory;
  final List<EnginePreviewFrameArtifact> frames;
}

final class EngineVideoThumbnailRequest {
  const EngineVideoThumbnailRequest({
    required this.clientTaskId,
    required this.source,
    required this.outputPath,
    required this.maxWidth,
    this.durationUs,
    this.priority = EngineWorkPriority.background,
    this.requestId,
  }) : assert(clientTaskId != ''),
       assert(outputPath != ''),
       assert(maxWidth > 0);

  final String clientTaskId;
  final EngineSourceFacts source;
  final String outputPath;
  final int? durationUs;
  final int maxWidth;
  final EngineWorkPriority priority;
  final String? requestId;
}

final class EngineVideoThumbnailResult {
  const EngineVideoThumbnailResult({
    required this.outputPath,
    required this.requestedTimestampUs,
    required this.decodedTimestampUs,
    required this.width,
    required this.height,
  });

  final String outputPath;
  final int requestedTimestampUs;
  final int decodedTimestampUs;
  final int width;
  final int height;
}

final class EngineManualOverrides {
  const EngineManualOverrides({
    this.container,
    this.videoCodec,
    this.audioCodec,
    this.outputPixelFormat,
    this.preservesHdr,
  });

  final String? container;
  final String? videoCodec;
  final String? audioCodec;
  final String? outputPixelFormat;
  final bool? preservesHdr;
}

sealed class EngineConfigurationSelection {
  const EngineConfigurationSelection();

  String get candidateId;
}

final class EnginePresetSelection extends EngineConfigurationSelection {
  const EnginePresetSelection({
    required this.presetId,
    required this.candidateId,
    this.overrides = const EngineManualOverrides(),
  }) : assert(presetId != ''),
       assert(candidateId != '');

  final String presetId;

  @override
  final String candidateId;

  final EngineManualOverrides overrides;
}

final class EngineTargetSizeSelection extends EngineConfigurationSelection {
  const EngineTargetSizeSelection({
    required this.candidateId,
    required this.targetBytes,
    required this.allowResolutionChange,
    required this.allowFrameRateChange,
  }) : assert(candidateId != ''),
       assert(targetBytes > 0);

  @override
  final String candidateId;

  final int targetBytes;
  final bool allowResolutionChange;
  final bool allowFrameRateChange;
}

final class EngineManualConfigurationSelection
    extends EngineConfigurationSelection {
  const EngineManualConfigurationSelection({
    required this.candidateId,
    this.overrides = const EngineManualOverrides(),
  }) : assert(candidateId != '');

  @override
  final String candidateId;

  final EngineManualOverrides overrides;
}

String engineConfigurationSelectionMode(
  EngineConfigurationSelection selection,
) {
  return switch (selection) {
    EnginePresetSelection() => 'preset',
    EngineTargetSizeSelection() => 'custom_target_size',
    EngineManualConfigurationSelection() => 'manual',
  };
}

Map<String, Object?> engineConfigurationSelectionToJson(
  EngineConfigurationSelection selection,
) {
  return switch (selection) {
    EnginePresetSelection() => <String, Object?>{
      'mode': 'preset',
      'selection': <String, Object?>{
        'preset_id': selection.presetId,
        'candidate_id': selection.candidateId,
        'overrides': _engineManualOverridesToJson(selection.overrides),
      },
    },
    EngineTargetSizeSelection() => <String, Object?>{
      'mode': 'custom_target_size',
      'selection': <String, Object?>{
        'candidate_id': selection.candidateId,
        'target_bytes': selection.targetBytes,
        'allow_resolution_change': selection.allowResolutionChange,
        'allow_frame_rate_change': selection.allowFrameRateChange,
      },
    },
    EngineManualConfigurationSelection() => <String, Object?>{
      'mode': 'manual',
      'selection': <String, Object?>{
        'candidate_id': selection.candidateId,
        'overrides': _engineManualOverridesToJson(selection.overrides),
      },
    },
  };
}

Map<String, Object?> _engineManualOverridesToJson(
  EngineManualOverrides overrides,
) {
  return <String, Object?>{
    if (overrides.container != null) 'container': overrides.container,
    if (overrides.videoCodec != null) 'video_codec': overrides.videoCodec,
    if (overrides.audioCodec != null) 'audio_codec': overrides.audioCodec,
    if (overrides.outputPixelFormat != null)
      'output_pixel_format': overrides.outputPixelFormat,
    if (overrides.preservesHdr != null) 'preserves_hdr': overrides.preservesHdr,
  };
}

final class EngineExecutionRequest {
  const EngineExecutionRequest({
    required this.clientTaskId,
    required this.analysisId,
    required this.expectedRevision,
    required this.selection,
    required this.requestedOutputPath,
    required this.collisionPolicy,
    this.priority = EngineWorkPriority.normal,
    this.requestId,
  }) : assert(clientTaskId != ''),
       assert(analysisId != ''),
       assert(expectedRevision >= 0),
       assert(requestedOutputPath != '');

  final String clientTaskId;
  final String analysisId;
  final int expectedRevision;
  final Map<String, Object?> selection;
  final String requestedOutputPath;
  final EngineOutputCollisionPolicy collisionPolicy;
  final EngineWorkPriority priority;
  final String? requestId;
}

final class EngineExecutionSubmission {
  const EngineExecutionSubmission({
    required this.executionId,
    required this.state,
    this.queuePosition = 0,
    this.queueRevision = 0,
  }) : assert(executionId != '');

  final String executionId;
  final EngineExecutionState state;
  final int queuePosition;
  final int queueRevision;
}

final class EngineExecutionProgress {
  const EngineExecutionProgress({
    required this.mediaTimeUs,
    required this.processedBytes,
  });

  final int mediaTimeUs;
  final int processedBytes;
}

final class EngineBatchSubmissionItem {
  const EngineBatchSubmissionItem({
    required this.clientTaskId,
    required this.childRequestId,
    required this.workId,
    required this.queueKind,
    required this.queuePosition,
    required this.queueRevision,
  });

  final String clientTaskId;
  final String childRequestId;
  final String workId;
  final EngineQueueKind queueKind;
  final int queuePosition;
  final int queueRevision;
}

final class EngineBatchSubmission {
  const EngineBatchSubmission({required this.items});

  final List<EngineBatchSubmissionItem> items;
}

final class EngineScheduledExecution {
  const EngineScheduledExecution({
    required this.executionId,
    required this.state,
    required this.pauseReason,
    required this.preemptedByExecutionId,
    required this.checkpoint,
  });

  final String executionId;
  final EngineExecutionState state;
  final EngineExecutionPauseReason? pauseReason;
  final String? preemptedByExecutionId;
  final Map<String, Object?>? checkpoint;
}

final class EngineExecutionLaneSnapshot {
  const EngineExecutionLaneSnapshot({
    required this.queueRevision,
    required this.active,
    required this.normalWaiting,
    required this.resumeStack,
    this.userPaused = const <EngineScheduledExecution>[],
  });

  final int queueRevision;
  final EngineScheduledExecution? active;
  final List<EngineScheduledExecution> normalWaiting;
  final List<EngineScheduledExecution> resumeStack;
  final List<EngineScheduledExecution> userPaused;
}

final class EngineAnalysisQueueEntrySnapshot {
  const EngineAnalysisQueueEntrySnapshot({
    required this.workId,
    required this.clientTaskId,
    required this.queuePosition,
  });

  final String workId;
  final String clientTaskId;
  final int queuePosition;
}

final class EngineStateSnapshot {
  const EngineStateSnapshot({
    required this.analysisQueueRevision,
    this.activeAnalysis,
    required this.analysisQueue,
    this.terminalAnalyses = const <EngineTerminalAnalysisSnapshot>[],
    required this.executionLane,
    this.terminalExecutions = const <EngineTerminalExecutionSnapshot>[],
    required this.lastSequence,
  });

  final int analysisQueueRevision;
  final EngineAnalysisQueueEntrySnapshot? activeAnalysis;
  final List<EngineAnalysisQueueEntrySnapshot> analysisQueue;
  final List<EngineTerminalAnalysisSnapshot> terminalAnalyses;
  final EngineExecutionLaneSnapshot executionLane;
  final List<EngineTerminalExecutionSnapshot> terminalExecutions;
  final int lastSequence;
}

final class EngineTerminalAnalysisSnapshot {
  const EngineTerminalAnalysisSnapshot({
    required this.workId,
    required this.clientTaskId,
    required this.clientFileId,
    required this.analysisId,
    required this.analysisRevision,
    required this.succeeded,
    this.engineCode,
    this.message,
  });

  final String workId;
  final String clientTaskId;
  final String clientFileId;
  final String analysisId;
  final int analysisRevision;
  final bool succeeded;
  final String? engineCode;
  final String? message;
}

final class EngineTerminalExecutionSnapshot {
  const EngineTerminalExecutionSnapshot({
    required this.executionId,
    required this.clientTaskId,
    required this.state,
    this.outputPath,
    this.engineCode,
    this.message,
  });

  final String executionId;
  final String clientTaskId;
  final EngineExecutionState state;
  final String? outputPath;
  final String? engineCode;
  final String? message;
}

final class EngineQueuePosition {
  const EngineQueuePosition({
    required this.clientTaskId,
    required this.queuePosition,
    this.workId,
    this.executionId,
  });

  final String clientTaskId;
  final int queuePosition;
  final String? workId;
  final String? executionId;
}

sealed class EngineQueueOrderOutcome {
  const EngineQueueOrderOutcome({required this.orderRevision});

  final int orderRevision;
}

final class EngineQueueOrderApplied extends EngineQueueOrderOutcome {
  const EngineQueueOrderApplied({
    required super.orderRevision,
    required this.analysisQueueRevision,
    required this.executionQueueRevision,
    required this.analysisPositions,
    required this.executionPositions,
  });

  final int analysisQueueRevision;
  final int executionQueueRevision;
  final List<EngineQueuePosition> analysisPositions;
  final List<EngineQueuePosition> executionPositions;
}

final class EngineQueueOrderConflict extends EngineQueueOrderOutcome {
  const EngineQueueOrderConflict({
    required super.orderRevision,
    required this.snapshot,
  });

  final EngineStateSnapshot snapshot;
}

/// Raised when a persisted opaque selection cannot be decoded into the
/// versioned FLL selection model.
final class EngineConfigurationSelectionException implements Exception {
  const EngineConfigurationSelectionException(this.message);

  final String message;

  @override
  String toString() => 'Invalid engine configuration selection: $message';
}

EngineConfigurationSelection engineConfigurationSelectionFromEncoded(
  String encoded,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } on FormatException catch (error) {
    throw EngineConfigurationSelectionException(error.message);
  }
  if (decoded is! Map) {
    throw const EngineConfigurationSelectionException(
      'selection document must be an object',
    );
  }
  return engineConfigurationSelectionFromJson(_stringObjectMap(decoded));
}

EngineConfigurationSelection engineConfigurationSelectionFromJson(
  Map<String, Object?> json,
) {
  final mode = _requiredSelectionString(json, 'mode');
  final selection = _requiredSelectionObject(json, 'selection');
  final candidateId = _requiredSelectionString(selection, 'candidate_id');

  return switch (mode) {
    'preset' => EnginePresetSelection(
      presetId: _requiredSelectionString(selection, 'preset_id'),
      candidateId: candidateId,
      overrides: _selectionOverrides(selection),
    ),
    'custom_target_size' => EngineTargetSizeSelection(
      candidateId: candidateId,
      targetBytes: _requiredSelectionPositiveInt(selection, 'target_bytes'),
      allowResolutionChange: _requiredSelectionBool(
        selection,
        'allow_resolution_change',
      ),
      allowFrameRateChange: _requiredSelectionBool(
        selection,
        'allow_frame_rate_change',
      ),
    ),
    'manual' => EngineManualConfigurationSelection(
      candidateId: candidateId,
      overrides: _selectionOverrides(selection),
    ),
    _ => throw EngineConfigurationSelectionException(
      'unsupported selection mode "$mode"',
    ),
  };
}

Map<String, Object?> _stringObjectMap(Map<dynamic, dynamic> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const EngineConfigurationSelectionException(
        'selection object contains a non-string key',
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _requiredSelectionString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw EngineConfigurationSelectionException(
      'selection.$key must be a non-empty string',
    );
  }
  return value;
}

int _requiredSelectionPositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw EngineConfigurationSelectionException(
      'selection.$key must be a positive integer',
    );
  }
  return value;
}

bool _requiredSelectionBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw EngineConfigurationSelectionException(
      'selection.$key must be a boolean',
    );
  }
  return value;
}

Map<String, Object?> _requiredSelectionObject(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! Map) {
    throw EngineConfigurationSelectionException(
      'selection.$key must be an object',
    );
  }
  return _stringObjectMap(value);
}

EngineManualOverrides _selectionOverrides(Map<String, Object?> selection) {
  final value = selection['overrides'];
  if (value == null) {
    return const EngineManualOverrides();
  }
  if (value is! Map) {
    throw const EngineConfigurationSelectionException(
      'selection.overrides must be an object',
    );
  }
  final overrides = _stringObjectMap(value);
  return EngineManualOverrides(
    container: _optionalSelectionString(overrides, 'container'),
    videoCodec: _optionalSelectionString(overrides, 'video_codec'),
    audioCodec: _optionalSelectionString(overrides, 'audio_codec'),
    outputPixelFormat: _optionalSelectionString(
      overrides,
      'output_pixel_format',
    ),
    preservesHdr: _optionalSelectionBool(overrides, 'preserves_hdr'),
  );
}

String? _optionalSelectionString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw EngineConfigurationSelectionException(
      'selection.overrides.$key must be a non-empty string',
    );
  }
  return value;
}

bool? _optionalSelectionBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw EngineConfigurationSelectionException(
      'selection.overrides.$key must be a boolean',
    );
  }
  return value;
}

final class EngineConnectionInfo {
  const EngineConnectionInfo({
    required this.sessionId,
    required this.protocolVersion,
    required this.engineVersion,
    required this.heartbeatTimeout,
    required this.resumed,
  });

  final String sessionId;
  final int protocolVersion;
  final String engineVersion;
  final Duration heartbeatTimeout;
  final bool resumed;
}

final class EngineOperationResult<T> {
  const EngineOperationResult({
    required this.sessionId,
    required this.requestId,
    required this.workId,
    required this.sequence,
    required this.value,
    this.queueKind,
    this.queuePosition,
    this.queueRevision,
  });

  final String sessionId;
  final String requestId;
  final String workId;
  final int sequence;
  final T value;
  final EngineQueueKind? queueKind;
  final int? queuePosition;
  final int? queueRevision;
}

final class EngineWorkEvent {
  const EngineWorkEvent({
    required this.requestId,
    required this.workId,
    required this.sequence,
    required this.type,
    this.sessionId,
    this.queuePosition,
    this.queueRemaining,
    this.queueKind,
    this.queueRevision,
    this.clientTaskId,
    this.executionId,
    this.executionState,
    this.pauseReason,
    this.preemptedByExecutionId,
    this.resumeDepth,
    this.progress,
    this.outputPath,
    this.engineCode,
    this.message,
    this.error,
  });

  final String requestId;
  final String? workId;
  final int sequence;
  final EngineWorkEventType type;
  final String? sessionId;
  final int? queuePosition;
  final int? queueRemaining;
  final EngineQueueKind? queueKind;
  final int? queueRevision;
  final String? clientTaskId;
  final String? executionId;
  final EngineExecutionState? executionState;
  final EngineExecutionPauseReason? pauseReason;
  final String? preemptedByExecutionId;
  final int? resumeDepth;
  final EngineExecutionProgress? progress;
  final String? outputPath;
  final String? engineCode;
  final String? message;
  final EngineWorkerException? error;
}

class EngineGatewayException implements Exception {
  const EngineGatewayException({
    required this.kind,
    required this.message,
    this.requestId,
  });

  final EngineGatewayFailureKind kind;
  final String message;
  final String? requestId;

  @override
  String toString() => 'Engine gateway ${kind.name} failure: $message';
}

final class EngineWorkerException extends EngineGatewayException {
  const EngineWorkerException({
    required this.code,
    required this.engineCode,
    required this.retryable,
    required super.message,
    required super.requestId,
  }) : super(kind: EngineGatewayFailureKind.worker);

  final String code;
  final String? engineCode;
  final bool retryable;
}

abstract interface class EngineGateway {
  Future<EngineConnectionInfo> connect();

  Stream<EngineWorkEvent> get events;

  Future<EngineOperationResult<EngineAnalysisCompletionDocument>> analyze(
    EngineAnalysisRequest request,
  );

  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>>
  getAnalysisSnapshot(
    String analysisId, {
    EngineWorkPriority priority = EngineWorkPriority.foreground,
  });

  Future<EngineOperationResult<EngineExecutionSubmission>> submitExecution(
    EngineExecutionRequest request,
  );

  Future<void> ping();

  Future<void> close();
}

abstract interface class EngineMediaGateway implements EngineGateway {
  Future<EngineOperationResult<EnginePreviewFramesResult>>
  generatePreviewFrames(EnginePreviewFramesRequest request);

  Future<EngineOperationResult<EngineVideoThumbnailResult>>
  generateVideoThumbnail(EngineVideoThumbnailRequest request);
}

abstract interface class EngineLifecycleGateway implements EngineGateway {
  Future<EngineOperationResult<EngineStateSnapshot>> getEngineSnapshot();

  Future<EngineOperationResult<EngineQueueOrderOutcome>> applyQueueOrder({
    required int orderRevision,
    required int expectedAnalysisQueueRevision,
    required int expectedExecutionQueueRevision,
    required List<String> orderedTaskIds,
  });

  Future<EngineOperationResult<EngineExecutionState>> preemptAndStart(
    String executionId,
  );

  Future<EngineOperationResult<EngineExecutionState>> controlExecution(
    String executionId,
    EngineExecutionControlAction action,
  );
}

/// Optional ownership boundary for a local engine that outlives a Client
/// connection. Ordinary [EngineGateway.close] only detaches from it.
abstract interface class EngineProcessControl {
  Future<void> shutdownEngine();
}

abstract interface class EngineBatchGateway implements EngineLifecycleGateway {
  Future<EngineOperationResult<EngineBatchSubmission>> submitAnalysisBatch(
    List<EngineAnalysisRequest> requests,
  );

  Future<EngineOperationResult<EngineBatchSubmission>> submitExecutionBatch(
    List<EngineExecutionRequest> requests,
  );
}
