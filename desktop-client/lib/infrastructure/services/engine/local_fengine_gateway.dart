import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/services/engine/fengine_protocol_client.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

typedef FEngineTransportLauncher =
    Future<FEngineTransport> Function({
      required String executablePath,
      required String snapshotDirectory,
    });

final class LocalFEngineGateway
    implements EngineBatchGateway, EngineMediaGateway, EngineProcessControl {
  LocalFEngineGateway({
    required this.executablePath,
    required this.snapshotDirectory,
    required this.clientVersion,
    this.clientName = 'FrameLean Desktop',
    FEngineTransportLauncher? launchTransport,
    String Function()? createRequestId,
  }) : _launchTransport = launchTransport ?? _launchLocalTransport,
       _createRequestId = createRequestId ?? const Uuid().v4;

  final String executablePath;
  final String snapshotDirectory;
  final String clientName;
  final String clientVersion;
  final FEngineTransportLauncher _launchTransport;
  final String Function() _createRequestId;
  final StreamController<EngineWorkEvent> _eventController =
      StreamController<EngineWorkEvent>.broadcast();

  Future<EngineConnectionInfo>? _connectionFuture;
  FEngineProtocolClient? _client;
  StreamSubscription<FEngineProtocolEvent>? _eventSubscription;
  Timer? _heartbeatTimer;
  bool _heartbeatInFlight = false;
  Object? _backgroundFailure;
  bool _closing = false;
  bool _closed = false;
  String? _sessionId;

  @override
  Stream<EngineWorkEvent> get events => _eventController.stream;

  @override
  Future<EngineConnectionInfo> connect() {
    if (_closed || _closing) {
      throw const EngineGatewayException(
        kind: EngineGatewayFailureKind.closed,
        message: 'FEngine gateway is closed',
      );
    }
    return _connectionFuture ??= _connect();
  }

  Future<EngineConnectionInfo> _connect() async {
    late final FEngineTransport transport;
    try {
      transport = await _launchTransport(
        executablePath: executablePath,
        snapshotDirectory: snapshotDirectory,
      );
    } on Object catch (error) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'cannot start FEngine: $error',
      );
    }

    final client = FEngineProtocolClient(
      transport: transport,
      createRequestId: _createRequestId,
    );
    _client = client;
    _eventSubscription = client.events.listen(_forwardEvent);
    try {
      final hello = await client.connect(
        clientName: clientName,
        clientVersion: clientVersion,
      );
      _sessionId = hello.sessionId;
      _startHeartbeat(hello.heartbeatTimeout);
      return EngineConnectionInfo(
        sessionId: hello.sessionId,
        protocolVersion: hello.negotiatedProtocolVersion,
        engineVersion: hello.engineVersion,
        heartbeatTimeout: hello.heartbeatTimeout,
        resumed: hello.resumed,
      );
    } on Object {
      await client.abort();
      rethrow;
    }
  }

  @override
  Future<EngineOperationResult<EngineAnalysisCompletionDocument>> analyze(
    EngineAnalysisRequest request,
  ) async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'analyze_media',
      commandPayload: _analysisCommandPayload(request),
      expectedTerminalEvent: 'analysis_completed',
      requestId: request.requestId,
    );
    final document = _parseDocument(
      requestId: result.requestId,
      parse: () {
        final snapshotValue = result.payload['snapshot'];
        return EngineAnalysisCompletionDocument(
          analysis: EngineAnalysisResponseDocument.fromJson(
            _requireObject(result.payload, 'analysis', 'analysis_completed'),
          ),
          snapshot: snapshotValue == null
              ? null
              : EngineAnalysisSnapshotDocument.fromJson(
                  _requireObject(
                    result.payload,
                    'snapshot',
                    'analysis_completed',
                  ),
                ),
        );
      },
    );
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: document,
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineBatchSubmission>> submitAnalysisBatch(
    List<EngineAnalysisRequest> requests,
  ) async {
    if (requests.isEmpty) {
      throw const EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'analysis batch must not be empty',
      );
    }
    return _submitBatch(
      commandType: 'submit_analysis_batch',
      items: requests.map(_analysisCommandPayload).toList(growable: false),
    );
  }

  @override
  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>>
  getAnalysisSnapshot(
    String analysisId, {
    EngineWorkPriority priority = EngineWorkPriority.foreground,
  }) async {
    if (analysisId.trim().isEmpty) {
      throw const EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'analysis id must not be empty',
      );
    }
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'get_analysis_snapshot',
      commandPayload: <String, Object?>{
        'analysis_id': analysisId,
        'priority': priority.name,
      },
      expectedTerminalEvent: 'analysis_snapshot_ready',
    );
    final document = _parseDocument(
      requestId: result.requestId,
      parse: () => EngineAnalysisSnapshotDocument.fromJson(
        _requireObject(result.payload, 'snapshot', 'analysis_snapshot_ready'),
      ),
    );
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: document,
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EnginePreviewFramesResult>>
  generatePreviewFrames(EnginePreviewFramesRequest request) async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'generate_preview_frames',
      commandPayload: <String, Object?>{
        'client_task_id': request.clientTaskId,
        'source': _sourceFactsPayload(request.source),
        'output_directory': request.outputDirectory,
        'timestamps_us': request.timestampsUs,
        'max_width': request.maxWidth,
        'priority': request.priority.name,
      },
      expectedTerminalEvent: 'preview_frames_ready',
      requestId: request.requestId,
    );
    final resultJson = _requireObject(
      result.payload,
      'result',
      'preview_frames_ready',
    );
    final frames =
        _requireList(resultJson, 'frames', requestId: result.requestId)
            .map((value) {
              final frame = _objectValue(
                value,
                'preview frame',
                result.requestId,
              );
              return EnginePreviewFrameArtifact(
                index: _requireIntValue(
                  frame,
                  'index',
                  requestId: result.requestId,
                ),
                requestedTimestampUs: _requireIntValue(
                  frame,
                  'requested_timestamp_us',
                  requestId: result.requestId,
                ),
                decodedTimestampUs: _requireIntValue(
                  frame,
                  'decoded_timestamp_us',
                  requestId: result.requestId,
                ),
                width: _requireIntValue(
                  frame,
                  'width',
                  requestId: result.requestId,
                ),
                height: _requireIntValue(
                  frame,
                  'height',
                  requestId: result.requestId,
                ),
                outputPath: _requireNonEmptyString(
                  frame,
                  'output_path',
                  'preview frame',
                  requestId: result.requestId,
                ),
              );
            })
            .toList(growable: false);
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: EnginePreviewFramesResult(
        outputDirectory: _requireNonEmptyString(
          resultJson,
          'output_directory',
          'preview_frames_ready',
          requestId: result.requestId,
        ),
        frames: frames,
      ),
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineVideoThumbnailResult>>
  generateVideoThumbnail(EngineVideoThumbnailRequest request) async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'generate_video_thumbnail',
      commandPayload: <String, Object?>{
        'client_task_id': request.clientTaskId,
        'source': _sourceFactsPayload(request.source),
        'output_path': request.outputPath,
        'duration_us': request.durationUs,
        'max_width': request.maxWidth,
        'priority': request.priority.name,
      },
      expectedTerminalEvent: 'video_thumbnail_ready',
      requestId: request.requestId,
    );
    final resultJson = _requireObject(
      result.payload,
      'result',
      'video_thumbnail_ready',
    );
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: EngineVideoThumbnailResult(
        outputPath: _requireNonEmptyString(
          resultJson,
          'output_path',
          'video_thumbnail_ready',
          requestId: result.requestId,
        ),
        requestedTimestampUs: _requireIntValue(
          resultJson,
          'requested_timestamp_us',
          requestId: result.requestId,
        ),
        decodedTimestampUs: _requireIntValue(
          resultJson,
          'decoded_timestamp_us',
          requestId: result.requestId,
        ),
        width: _requireIntValue(
          resultJson,
          'width',
          requestId: result.requestId,
        ),
        height: _requireIntValue(
          resultJson,
          'height',
          requestId: result.requestId,
        ),
      ),
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineExecutionSubmission>> submitExecution(
    EngineExecutionRequest request,
  ) async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'submit_execution',
      commandPayload: _executionCommandPayload(request),
      expectedTerminalEvent: 'execution_submitted',
      requestId: request.requestId,
    );
    final clientTaskId = _requireNonEmptyString(
      result.payload,
      'client_task_id',
      'execution_submitted',
      requestId: result.requestId,
    );
    if (clientTaskId != request.clientTaskId) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message:
            'FEngine execution_submitted client_task_id does not match '
            'the submitted task',
        requestId: result.requestId,
      );
    }
    final submissionJson = _requireObject(
      result.payload,
      'submission',
      'execution_submitted',
      requestId: result.requestId,
    );
    final submission = EngineExecutionSubmission(
      executionId: _requireNonEmptyString(
        submissionJson,
        'execution_id',
        'execution_submitted submission',
        requestId: result.requestId,
      ),
      state: _parseExecutionState(submissionJson, requestId: result.requestId),
      queuePosition: _requireIntValue(
        submissionJson,
        'queue_position',
        requestId: result.requestId,
      ),
      queueRevision: _requireIntValue(
        submissionJson,
        'queue_revision',
        requestId: result.requestId,
      ),
    );
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: submission,
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineBatchSubmission>> submitExecutionBatch(
    List<EngineExecutionRequest> requests,
  ) async {
    if (requests.isEmpty) {
      throw const EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'execution batch must not be empty',
      );
    }
    return _submitBatch(
      commandType: 'submit_execution_batch',
      items: requests.map(_executionCommandPayload).toList(growable: false),
    );
  }

  Future<EngineOperationResult<EngineBatchSubmission>> _submitBatch({
    required String commandType,
    required List<Map<String, Object?>> items,
  }) async {
    final connection = await connect();
    final result = await (await _connectedClient()).requestImmediate(
      commandType: commandType,
      commandPayload: <String, Object?>{'items': items},
      expectedResponseType: 'batch_accepted',
    );
    final parsedItems =
        _requireList(result.payload, 'items', requestId: result.requestId)
            .map((value) {
              final item = _objectValue(
                value,
                'batch submission item',
                result.requestId,
              );
              return EngineBatchSubmissionItem(
                clientTaskId: _requireNonEmptyString(
                  item,
                  'client_task_id',
                  'batch submission item',
                  requestId: result.requestId,
                ),
                childRequestId: _requireNonEmptyString(
                  item,
                  'child_request_id',
                  'batch submission item',
                  requestId: result.requestId,
                ),
                workId: _requireNonEmptyString(
                  item,
                  'work_id',
                  'batch submission item',
                  requestId: result.requestId,
                ),
                queueKind: _parseQueueKind(
                  _requireNonEmptyString(
                    item,
                    'queue_kind',
                    'batch submission item',
                    requestId: result.requestId,
                  ),
                )!,
                queuePosition: _requireIntValue(
                  item,
                  'queue_position',
                  requestId: result.requestId,
                ),
                queueRevision: _requireIntValue(
                  item,
                  'queue_revision',
                  requestId: result.requestId,
                ),
              );
            })
            .toList(growable: false);
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: parsedItems.first.workId,
      sequence: result.sequence,
      value: EngineBatchSubmission(items: parsedItems),
    );
  }

  @override
  Future<EngineOperationResult<EngineStateSnapshot>> getEngineSnapshot() async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'get_engine_snapshot',
      commandPayload: const <String, Object?>{},
      expectedTerminalEvent: 'engine_snapshot_ready',
    );
    final snapshot = _parseEngineStateSnapshot(
      _requireObject(
        result.payload,
        'snapshot',
        'engine_snapshot_ready',
        requestId: result.requestId,
      ),
      requestId: result.requestId,
    );
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: snapshot,
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineQueueOrderOutcome>> applyQueueOrder({
    required int orderRevision,
    required int expectedAnalysisQueueRevision,
    required int expectedExecutionQueueRevision,
    required List<String> orderedTaskIds,
  }) async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: 'apply_queue_order',
      commandPayload: <String, Object?>{
        'order_revision': orderRevision,
        'expected_analysis_queue_revision': expectedAnalysisQueueRevision,
        'expected_execution_queue_revision': expectedExecutionQueueRevision,
        'ordered_task_ids': orderedTaskIds,
      },
      expectedTerminalEvent: 'queue_order_applied',
      alternativeTerminalEvents: const <String>{'queue_order_conflict'},
    );
    final EngineQueueOrderOutcome outcome;
    if (result.payload['result'] != null) {
      final applied = _requireObject(
        result.payload,
        'result',
        'queue_order_applied',
        requestId: result.requestId,
      );
      outcome = EngineQueueOrderApplied(
        orderRevision: _requireIntValue(
          applied,
          'order_revision',
          requestId: result.requestId,
        ),
        analysisQueueRevision: _requireIntValue(
          applied,
          'analysis_queue_revision',
          requestId: result.requestId,
        ),
        executionQueueRevision: _requireIntValue(
          applied,
          'execution_queue_revision',
          requestId: result.requestId,
        ),
        analysisPositions: _parseQueuePositions(
          applied,
          'analysis_positions',
          requestId: result.requestId,
          execution: false,
        ),
        executionPositions: _parseQueuePositions(
          applied,
          'execution_positions',
          requestId: result.requestId,
          execution: true,
        ),
      );
    } else {
      outcome = EngineQueueOrderConflict(
        orderRevision: _requireIntValue(
          result.payload,
          'order_revision',
          requestId: result.requestId,
        ),
        snapshot: _parseEngineStateSnapshot(
          _requireObject(
            result.payload,
            'snapshot',
            'queue_order_conflict',
            requestId: result.requestId,
          ),
          requestId: result.requestId,
        ),
      );
    }
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: outcome,
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineExecutionState>> preemptAndStart(
    String executionId,
  ) {
    return _controlExecutionRequest(
      commandType: 'preempt_and_start',
      commandPayload: <String, Object?>{'execution_id': executionId},
    );
  }

  @override
  Future<EngineOperationResult<EngineExecutionState>> controlExecution(
    String executionId,
    EngineExecutionControlAction action,
  ) {
    return _controlExecutionRequest(
      commandType: 'control_execution',
      commandPayload: <String, Object?>{
        'execution_id': executionId,
        'action': action.name,
      },
    );
  }

  Future<EngineOperationResult<EngineExecutionState>> _controlExecutionRequest({
    required String commandType,
    required Map<String, Object?> commandPayload,
  }) async {
    final connection = await connect();
    final client = await _connectedClient();
    final result = await client.requestWork(
      commandType: commandType,
      commandPayload: commandPayload,
      expectedTerminalEvent: 'execution_control_accepted',
    );
    final state = _parseExecutionStateName(
      _requireNonEmptyString(
        result.payload,
        'state',
        'execution_control_accepted',
        requestId: result.requestId,
      ),
      requestId: result.requestId,
    );
    return EngineOperationResult(
      sessionId: connection.sessionId,
      requestId: result.requestId,
      workId: _requireWorkId(result),
      sequence: result.sequence,
      value: state,
      queueKind: _parseQueueKind(result.queueKind),
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<void> ping() async {
    final client = await _connectedClient();
    await client.ping();
  }

  @override
  Future<void> close() async {
    if (_closed || _closing) {
      return;
    }
    _closing = true;
    _heartbeatTimer?.cancel();
    final client = _client;
    if (client != null) {
      await client.close();
    }
    await _eventSubscription?.cancel();
    await _eventController.close();
    _closed = true;
    _closing = false;
  }

  @override
  Future<void> shutdownEngine() async {
    if (_closed || _closing) {
      return;
    }
    _closing = true;
    _heartbeatTimer?.cancel();
    final client = _client;
    if (client != null) {
      await client.shutdownWorker();
    }
    await _eventSubscription?.cancel();
    await _eventController.close();
    _closed = true;
    _closing = false;
  }

  Future<FEngineProtocolClient> _connectedClient() async {
    await connect();
    final failure = _backgroundFailure;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    final client = _client;
    if (client == null || !client.isConnected) {
      throw const EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'FEngine connection is unavailable',
      );
    }
    return client;
  }

  void _startHeartbeat(Duration timeout) {
    final timeoutMilliseconds = timeout.inMilliseconds;
    final intervalMilliseconds = (timeoutMilliseconds ~/ 3).clamp(1000, 5000);
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: intervalMilliseconds),
      (_) {
        if (_closing || _closed || _heartbeatInFlight) {
          return;
        }
        _heartbeatInFlight = true;
        unawaited(
          _sendHeartbeat().whenComplete(() {
            _heartbeatInFlight = false;
          }),
        );
      },
    );
  }

  Future<void> _sendHeartbeat() async {
    try {
      final client = _client;
      if (client == null || !client.isConnected) {
        return;
      }
      await client.ping();
    } on Object catch (error) {
      _backgroundFailure ??= error;
      await _client?.abort();
    }
  }

  void _forwardEvent(FEngineProtocolEvent event) {
    final workId = event.workId;
    final type = switch (event.type) {
      'work_queued' => EngineWorkEventType.queued,
      'work_started' => EngineWorkEventType.started,
      'work_failed' => EngineWorkEventType.failed,
      'analysis_completed' ||
      'analysis_snapshot_ready' ||
      'configuration_resolved' => EngineWorkEventType.completed,
      'execution_submitted' => EngineWorkEventType.executionSubmitted,
      'engine_snapshot_ready' => EngineWorkEventType.snapshot,
      'queue_order_applied' => EngineWorkEventType.queueOrderApplied,
      'queue_order_conflict' => EngineWorkEventType.queueOrderConflict,
      'execution_control_accepted' => EngineWorkEventType.completed,
      'execution_started' => EngineWorkEventType.executionStarted,
      'execution_progress' => EngineWorkEventType.executionProgress,
      'execution_paused' => EngineWorkEventType.executionPaused,
      'execution_resumed' => EngineWorkEventType.executionResumed,
      'execution_state_changed' => EngineWorkEventType.executionStateChanged,
      'warning' => EngineWorkEventType.warning,
      'sequence_gap' => EngineWorkEventType.sequenceGap,
      'execution_completed' => EngineWorkEventType.executionCompleted,
      'execution_failed' => EngineWorkEventType.executionFailed,
      'execution_cancelled' => EngineWorkEventType.executionCancelled,
      _ => null,
    };
    if (type == null) {
      return;
    }
    _eventController.add(
      EngineWorkEvent(
        requestId: event.requestId,
        workId: workId,
        sequence: event.sequence,
        type: type,
        sessionId: _sessionId,
        queuePosition: event.type == 'execution_submitted'
            ? _readNestedNullableInt(
                event.payload,
                'submission',
                'queue_position',
              )
            : _readNullableInt(event.payload, 'queue_position'),
        queueRemaining: _readNullableInt(event.payload, 'queue_remaining'),
        queueKind: _parseQueueKind(event.payload['queue_kind'] as String?),
        queueRevision: event.type == 'execution_submitted'
            ? _readNestedNullableInt(
                event.payload,
                'submission',
                'queue_revision',
              )
            : _readNullableInt(event.payload, 'queue_revision'),
        clientTaskId: event.payload['client_task_id'] as String?,
        executionId: event.type == 'execution_submitted'
            ? _readNestedNullableString(
                event.payload,
                'submission',
                'execution_id',
              )
            : event.payload['execution_id'] as String?,
        executionState: _readForwardedExecutionState(event),
        pauseReason: _readPauseReason(event),
        preemptedByExecutionId:
            event.payload['preempted_by_execution_id'] as String?,
        resumeDepth: _readNullableInt(event.payload, 'resume_depth'),
        progress: _readExecutionProgress(event),
        outputPath: event.payload['output_path'] as String?,
        engineCode: event.payload['engine_code'] as String?,
        message: event.payload['message'] as String?,
        error: event.error,
      ),
    );
  }

  EngineExecutionState? _readExecutionState(FEngineProtocolEvent event) {
    final explicitState = event.type == 'execution_submitted'
        ? _readNestedNullableString(event.payload, 'submission', 'state')
        : event.payload['state'];
    if (explicitState is String) {
      return _parseExecutionStateName(
        explicitState,
        requestId: event.requestId,
      );
    }
    return switch (event.type) {
      'execution_progress' => EngineExecutionState.running,
      'execution_paused' =>
        event.payload['pause_reason'] == 'preemption'
            ? EngineExecutionState.preempted
            : EngineExecutionState.paused,
      'execution_resumed' => EngineExecutionState.resuming,
      'execution_completed' => EngineExecutionState.completed,
      'execution_failed' => EngineExecutionState.failed,
      'execution_cancelled' => EngineExecutionState.cancelled,
      _ => null,
    };
  }

  EngineExecutionState? _readForwardedExecutionState(
    FEngineProtocolEvent event,
  ) {
    try {
      return _readExecutionState(event);
    } on EngineGatewayException {
      // The request awaiting this terminal event performs strict parsing and
      // reports the protocol error to its caller. Event fan-out must not turn
      // the same malformed payload into an uncaught stream callback error.
      return null;
    }
  }

  EngineExecutionPauseReason? _readPauseReason(FEngineProtocolEvent event) {
    return switch (event.payload['pause_reason']) {
      null => null,
      'user' => EngineExecutionPauseReason.user,
      'preemption' => EngineExecutionPauseReason.preemption,
      final Object value => throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine returned unsupported pause reason "$value"',
        requestId: event.requestId,
      ),
    };
  }

  EngineExecutionProgress? _readExecutionProgress(FEngineProtocolEvent event) {
    final value = event.payload['progress'];
    if (value == null) {
      return null;
    }
    final progress = _objectValue(value, 'execution progress', event.requestId);
    return EngineExecutionProgress(
      mediaTimeUs: _requireIntValue(
        progress,
        'media_time_us',
        requestId: event.requestId,
      ),
      processedBytes: _requireIntValue(
        progress,
        'processed_bytes',
        requestId: event.requestId,
      ),
    );
  }

  T _parseDocument<T>({
    required String requestId,
    required T Function() parse,
  }) {
    try {
      return parse();
    } on EngineDocumentException catch (error) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: error.toString(),
        requestId: requestId,
      );
    }
  }

  String _requireWorkId(FEngineProtocolResult result) {
    final workId = result.workId;
    if (workId == null || workId.trim().isEmpty) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine terminal event omitted work_id',
        requestId: result.requestId,
      );
    }
    return workId;
  }

  Map<String, Object?> _analysisCommandPayload(EngineAnalysisRequest request) {
    return <String, Object?>{
      'client_task_id': request.clientTaskId,
      'client_file_id': request.clientFileId,
      'source': _sourceFactsPayload(request.source),
      'task_mode': _taskModeName(request.taskMode),
      'priority': request.priority.name,
      'force_reanalysis': request.forceReanalysis,
    };
  }

  Map<String, Object?> _sourceFactsPayload(EngineSourceFacts source) {
    return <String, Object?>{
      'path': source.path,
      'file_size_bytes': source.fileSizeBytes,
      'modified_time_unix_nanos': source.modifiedTimeUnixNanos,
    };
  }

  Map<String, Object?> _executionCommandPayload(
    EngineExecutionRequest request,
  ) {
    return <String, Object?>{
      'client_task_id': request.clientTaskId,
      'analysis_id': request.analysisId,
      'expected_revision': request.expectedRevision,
      'selection': request.selection,
      'output': <String, Object?>{
        'requested_path': request.requestedOutputPath,
        'collision_policy': _collisionPolicyName(request.collisionPolicy),
      },
      'priority': request.priority.name,
    };
  }

  String _taskModeName(EngineTaskMode mode) {
    return switch (mode) {
      EngineTaskMode.videoCompress => 'video_compress',
      EngineTaskMode.videoConvert => 'video_convert',
      EngineTaskMode.audioCompress => 'audio_compress',
      EngineTaskMode.audioConvert => 'audio_convert',
      EngineTaskMode.imageCompress => 'image_compress',
      EngineTaskMode.imageConvert => 'image_convert',
    };
  }

  String _collisionPolicyName(EngineOutputCollisionPolicy policy) {
    return switch (policy) {
      EngineOutputCollisionPolicy.failIfExists => 'fail_if_exists',
      EngineOutputCollisionPolicy.generateUnique => 'generate_unique',
    };
  }

  EngineExecutionState _parseExecutionState(
    Map<String, Object?> json, {
    required String requestId,
  }) {
    final state = _requireNonEmptyString(
      json,
      'state',
      'execution_submitted submission',
      requestId: requestId,
    );
    return _parseExecutionStateName(state, requestId: requestId);
  }

  EngineExecutionState _parseExecutionStateName(
    String state, {
    required String requestId,
  }) {
    return switch (state) {
      'queued' => EngineExecutionState.queued,
      'running' => EngineExecutionState.running,
      'preempting' => EngineExecutionState.preempting,
      'preempted' => EngineExecutionState.preempted,
      'resuming' => EngineExecutionState.resuming,
      'pause_requested' => EngineExecutionState.pauseRequested,
      'paused' => EngineExecutionState.paused,
      'cancel_requested' => EngineExecutionState.cancelRequested,
      'cancelled' => EngineExecutionState.cancelled,
      'completed' => EngineExecutionState.completed,
      'failed' => EngineExecutionState.failed,
      _ => throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message:
            'FEngine execution_submitted submission contains unsupported '
            'state "$state"',
        requestId: requestId,
      ),
    };
  }

  EngineQueueKind? _parseQueueKind(String? value) {
    return switch (value) {
      null => null,
      'analysis' => EngineQueueKind.analysis,
      'execution' => EngineQueueKind.execution,
      'control' => EngineQueueKind.control,
      _ => throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine returned unsupported queue kind "$value"',
      ),
    };
  }

  EngineStateSnapshot _parseEngineStateSnapshot(
    Map<String, Object?> json, {
    required String requestId,
  }) {
    final analysisEntries =
        _requireList(json, 'analysis_queue', requestId: requestId)
            .map((value) {
              final entry = _objectValue(
                value,
                'analysis queue entry',
                requestId,
              );
              return EngineAnalysisQueueEntrySnapshot(
                workId: _requireNonEmptyString(
                  entry,
                  'work_id',
                  'analysis queue entry',
                  requestId: requestId,
                ),
                clientTaskId: _requireNonEmptyString(
                  entry,
                  'client_task_id',
                  'analysis queue entry',
                  requestId: requestId,
                ),
                queuePosition: _requireIntValue(
                  entry,
                  'queue_position',
                  requestId: requestId,
                ),
              );
            })
            .toList(growable: false);
    final lane = _requireObject(
      json,
      'execution_lane',
      'engine snapshot',
      requestId: requestId,
    );
    return EngineStateSnapshot(
      analysisQueueRevision: _requireIntValue(
        json,
        'analysis_queue_revision',
        requestId: requestId,
      ),
      activeAnalysis: json['active_analysis'] == null
          ? null
          : _parseAnalysisQueueEntry(
              _objectValue(
                json['active_analysis'],
                'active analysis',
                requestId,
              ),
              requestId: requestId,
            ),
      analysisQueue: analysisEntries,
      terminalAnalyses:
          _requireList(json, 'terminal_analyses', requestId: requestId)
              .map((value) {
                final terminal = _objectValue(
                  value,
                  'terminal analysis',
                  requestId,
                );
                return EngineTerminalAnalysisSnapshot(
                  workId: _requireNonEmptyString(
                    terminal,
                    'work_id',
                    'terminal analysis',
                    requestId: requestId,
                  ),
                  clientTaskId: _requireNonEmptyString(
                    terminal,
                    'client_task_id',
                    'terminal analysis',
                    requestId: requestId,
                  ),
                  clientFileId: _requireNonEmptyString(
                    terminal,
                    'client_file_id',
                    'terminal analysis',
                    requestId: requestId,
                  ),
                  analysisId: _requireNonEmptyString(
                    terminal,
                    'analysis_id',
                    'terminal analysis',
                    requestId: requestId,
                  ),
                  analysisRevision: _requireIntValue(
                    terminal,
                    'analysis_revision',
                    requestId: requestId,
                  ),
                  succeeded: _requireBoolValue(
                    terminal,
                    'succeeded',
                    requestId: requestId,
                  ),
                  engineCode: terminal['engine_code'] as String?,
                  message: terminal['message'] as String?,
                );
              })
              .toList(growable: false),
      executionLane: EngineExecutionLaneSnapshot(
        queueRevision: _requireIntValue(
          lane,
          'queue_revision',
          requestId: requestId,
        ),
        active: lane['active'] == null
            ? null
            : _parseScheduledExecution(
                _objectValue(lane['active'], 'active execution', requestId),
                requestId: requestId,
              ),
        normalWaiting:
            _requireList(lane, 'normal_waiting', requestId: requestId)
                .map(
                  (value) => _parseScheduledExecution(
                    _objectValue(value, 'waiting execution', requestId),
                    requestId: requestId,
                  ),
                )
                .toList(growable: false),
        resumeStack: _requireList(lane, 'resume_stack', requestId: requestId)
            .map(
              (value) => _parseScheduledExecution(
                _objectValue(value, 'resume execution', requestId),
                requestId: requestId,
              ),
            )
            .toList(growable: false),
        userPaused: _requireList(lane, 'user_paused', requestId: requestId)
            .map(
              (value) => _parseScheduledExecution(
                _objectValue(value, 'user-paused execution', requestId),
                requestId: requestId,
              ),
            )
            .toList(growable: false),
      ),
      terminalExecutions:
          _requireList(json, 'terminal_executions', requestId: requestId)
              .map((value) {
                final terminal = _objectValue(
                  value,
                  'terminal execution',
                  requestId,
                );
                return EngineTerminalExecutionSnapshot(
                  executionId: _requireNonEmptyString(
                    terminal,
                    'execution_id',
                    'terminal execution',
                    requestId: requestId,
                  ),
                  clientTaskId: _requireNonEmptyString(
                    terminal,
                    'client_task_id',
                    'terminal execution',
                    requestId: requestId,
                  ),
                  state: _parseExecutionStateName(
                    _requireNonEmptyString(
                      terminal,
                      'state',
                      'terminal execution',
                      requestId: requestId,
                    ),
                    requestId: requestId,
                  ),
                  outputPath: terminal['output_path'] as String?,
                  engineCode: terminal['engine_code'] as String?,
                  message: terminal['message'] as String?,
                );
              })
              .toList(growable: false),
      lastSequence: _requireIntValue(
        json,
        'last_sequence',
        requestId: requestId,
      ),
    );
  }

  EngineAnalysisQueueEntrySnapshot _parseAnalysisQueueEntry(
    Map<String, Object?> entry, {
    required String requestId,
  }) {
    return EngineAnalysisQueueEntrySnapshot(
      workId: _requireNonEmptyString(
        entry,
        'work_id',
        'analysis queue entry',
        requestId: requestId,
      ),
      clientTaskId: _requireNonEmptyString(
        entry,
        'client_task_id',
        'analysis queue entry',
        requestId: requestId,
      ),
      queuePosition: _requireIntValue(
        entry,
        'queue_position',
        requestId: requestId,
      ),
    );
  }

  EngineScheduledExecution _parseScheduledExecution(
    Map<String, Object?> json, {
    required String requestId,
  }) {
    final pauseReason = json['pause_reason'];
    final checkpoint = json['checkpoint'];
    return EngineScheduledExecution(
      executionId: _requireNonEmptyString(
        json,
        'execution_id',
        'scheduled execution',
        requestId: requestId,
      ),
      state: _parseExecutionStateName(
        _requireNonEmptyString(
          json,
          'state',
          'scheduled execution',
          requestId: requestId,
        ),
        requestId: requestId,
      ),
      pauseReason: switch (pauseReason) {
        null => null,
        'user' => EngineExecutionPauseReason.user,
        'preemption' => EngineExecutionPauseReason.preemption,
        _ => throw EngineGatewayException(
          kind: EngineGatewayFailureKind.protocol,
          message: 'FEngine scheduled execution has invalid pause_reason',
          requestId: requestId,
        ),
      },
      preemptedByExecutionId: json['preempted_by_execution_id'] as String?,
      checkpoint: checkpoint == null
          ? null
          : _objectValue(checkpoint, 'execution checkpoint', requestId),
    );
  }

  List<EngineQueuePosition> _parseQueuePositions(
    Map<String, Object?> json,
    String key, {
    required String requestId,
    required bool execution,
  }) {
    return _requireList(json, key, requestId: requestId)
        .map((value) {
          final position = _objectValue(value, key, requestId);
          return EngineQueuePosition(
            clientTaskId: _requireNonEmptyString(
              position,
              'client_task_id',
              key,
              requestId: requestId,
            ),
            queuePosition: _requireIntValue(
              position,
              'queue_position',
              requestId: requestId,
            ),
            workId: execution
                ? null
                : _requireNonEmptyString(
                    position,
                    'work_id',
                    key,
                    requestId: requestId,
                  ),
            executionId: execution
                ? _requireNonEmptyString(
                    position,
                    'execution_id',
                    key,
                    requestId: requestId,
                  )
                : null,
          );
        })
        .toList(growable: false);
  }

  List<Object?> _requireList(
    Map<String, Object?> json,
    String key, {
    required String requestId,
  }) {
    final value = json[key];
    if (value is! List) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine payload has invalid "$key" list',
        requestId: requestId,
      );
    }
    return value.cast<Object?>();
  }

  Map<String, Object?> _objectValue(
    Object? value,
    String context,
    String requestId,
  ) {
    if (value is! Map) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine $context must be an object',
        requestId: requestId,
      );
    }
    return value.map((key, value) {
      if (key is! String) {
        throw EngineGatewayException(
          kind: EngineGatewayFailureKind.protocol,
          message: 'FEngine $context contains a non-string key',
          requestId: requestId,
        );
      }
      return MapEntry(key, value);
    });
  }

  int _requireIntValue(
    Map<String, Object?> json,
    String key, {
    required String requestId,
  }) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine payload has invalid "$key" integer',
        requestId: requestId,
      );
    }
    return value;
  }

  bool _requireBoolValue(
    Map<String, Object?> json,
    String key, {
    required String requestId,
  }) {
    final value = json[key];
    if (value is! bool) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine payload has invalid "$key" boolean',
        requestId: requestId,
      );
    }
    return value;
  }

  Map<String, Object?> _requireObject(
    Map<String, Object?> json,
    String key,
    String eventType, {
    String? requestId,
  }) {
    final value = json[key];
    if (value is! Map) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine $eventType event omitted "$key"',
        requestId: requestId,
      );
    }
    return value.map((key, value) {
      if (key is! String) {
        throw EngineGatewayException(
          kind: EngineGatewayFailureKind.protocol,
          message: 'FEngine $eventType event contains a non-string key',
          requestId: requestId,
        );
      }
      return MapEntry(key, value);
    });
  }

  String _requireNonEmptyString(
    Map<String, Object?> json,
    String key,
    String context, {
    required String requestId,
  }) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'FEngine $context event has invalid "$key"',
        requestId: requestId,
      );
    }
    return value;
  }

  int? _readNullableInt(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is int ? value : null;
  }

  int? _readNestedNullableInt(
    Map<String, Object?> json,
    String objectKey,
    String valueKey,
  ) {
    final object = json[objectKey];
    return object is Map ? object[valueKey] as int? : null;
  }

  String? _readNestedNullableString(
    Map<String, Object?> json,
    String objectKey,
    String valueKey,
  ) {
    final object = json[objectKey];
    return object is Map ? object[valueKey] as String? : null;
  }

  static Future<FEngineTransport> _launchLocalTransport({
    required String executablePath,
    required String snapshotDirectory,
  }) async {
    final snapshotDir = Directory(snapshotDirectory);
    await snapshotDir.create(recursive: true);
    final endpointFile = File(
      path.join(snapshotDirectory, 'engine-endpoint.json'),
    );
    final existing = await _connectDaemon(endpointFile);
    if (existing != null) {
      return existing;
    }
    try {
      if (await endpointFile.exists()) {
        await endpointFile.delete();
      }
    } on FileSystemException {
      // A concurrently starting daemon may own the endpoint; polling below
      // will still connect to it when it becomes available.
    }
    await Process.start(
      executablePath,
      <String>[
        'serve-daemon',
        '--snapshot-dir',
        snapshotDirectory,
        '--endpoint-file',
        endpointFile.path,
      ],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    Object? lastFailure;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final transport = await _connectDaemon(endpointFile);
        if (transport != null) {
          return transport;
        }
      } on Object catch (error) {
        lastFailure = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError(
      'FEngine daemon endpoint did not become ready'
      '${lastFailure == null ? '' : ': $lastFailure'}',
    );
  }

  static Future<FEngineTransport?> _connectDaemon(File endpointFile) async {
    if (!await endpointFile.exists()) {
      return null;
    }
    Map<String, Object?> endpoint;
    try {
      final decoded = jsonDecode(await endpointFile.readAsString());
      if (decoded is! Map) {
        return null;
      }
      endpoint = decoded.map((key, value) => MapEntry(key.toString(), value));
    } on Object {
      return null;
    }
    final host = endpoint['host'];
    final port = endpoint['port'];
    final token = endpoint['token'];
    if (host != '127.0.0.1' ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        token is! String ||
        token.isEmpty ||
        token.length > 128) {
      return null;
    }
    Socket socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 500),
      );
    } on SocketException {
      return null;
    }
    socket.add(utf8.encode('$token\n'));
    await socket.flush();
    return LocalFEngineSocketTransport(socket);
  }
}
