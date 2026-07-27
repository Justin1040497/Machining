import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/infrastructure/services/engine/fengine_frame_codec.dart';

const int fengineProtocolVersion = 1;

abstract interface class FEngineTransport {
  Stream<List<int>> get stdoutBytes;

  Stream<List<int>> get stderrBytes;

  Future<int> get exitCode;

  Future<void> write(Uint8List bytes);

  Future<void> closeInput();

  bool terminate();
}

/// Marks a transport whose worker lifetime is independent of this connection.
abstract interface class FEnginePersistentTransport
    implements FEngineTransport {}

final class LocalFEngineProcessTransport implements FEngineTransport {
  LocalFEngineProcessTransport(this.process);

  final Process process;

  @override
  Stream<List<int>> get stdoutBytes => process.stdout;

  @override
  Stream<List<int>> get stderrBytes => process.stderr;

  @override
  Future<int> get exitCode => process.exitCode;

  @override
  Future<void> write(Uint8List bytes) async {
    process.stdin.add(bytes);
    await process.stdin.flush();
  }

  @override
  Future<void> closeInput() => process.stdin.close();

  @override
  bool terminate() => process.kill();
}

final class LocalFEngineSocketTransport implements FEnginePersistentTransport {
  LocalFEngineSocketTransport(this.socket);

  final Socket socket;

  @override
  Stream<List<int>> get stdoutBytes => socket;

  @override
  Stream<List<int>> get stderrBytes => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => socket.done.then((_) => 0);

  @override
  Future<void> write(Uint8List bytes) async {
    socket.add(bytes);
    await socket.flush();
  }

  @override
  Future<void> closeInput() => socket.close();

  @override
  bool terminate() {
    socket.destroy();
    return true;
  }
}

final class FEngineHelloResult {
  const FEngineHelloResult({
    required this.sessionId,
    required this.sequence,
    required this.negotiatedProtocolVersion,
    required this.engineVersion,
    required this.heartbeatTimeout,
    required this.resumed,
  });

  final String sessionId;
  final int sequence;
  final int negotiatedProtocolVersion;
  final String engineVersion;
  final Duration heartbeatTimeout;
  final bool resumed;
}

final class FEngineProtocolResult {
  const FEngineProtocolResult({
    required this.requestId,
    required this.sequence,
    required this.workId,
    required this.payload,
    this.queueKind,
    this.queuePosition,
    this.queueRevision,
  });

  final String requestId;
  final int sequence;
  final String? workId;
  final Map<String, Object?> payload;
  final String? queueKind;
  final int? queuePosition;
  final int? queueRevision;
}

final class FEngineProtocolEvent {
  const FEngineProtocolEvent({
    required this.requestId,
    required this.sequence,
    required this.type,
    required this.workId,
    required this.payload,
    this.error,
  });

  final String requestId;
  final int sequence;
  final String type;
  final String? workId;
  final Map<String, Object?> payload;
  final EngineWorkerException? error;
}

enum _PendingRequestKind { hello, ping, immediate, work, shutdown }

final class _PendingRequest {
  _PendingRequest({
    required this.kind,
    required this.expectedTerminalEvents,
    this.expectedResponseType,
  });

  final _PendingRequestKind kind;
  final Set<String>? expectedTerminalEvents;
  final String? expectedResponseType;
  final Completer<FEngineProtocolResult> completer =
      Completer<FEngineProtocolResult>();
  String? workId;
  String? queueKind;
  int? queuePosition;
  int? queueRevision;
  Timer? timeoutTimer;
}

final class FEngineProtocolClient {
  FEngineProtocolClient({
    required FEngineTransport transport,
    required String Function() createRequestId,
    this.requestTimeout = const Duration(seconds: 10),
    this.shutdownTimeout = const Duration(seconds: 35),
    this.maximumStderrTailBytes = 64 * 1024,
  }) : _transport = transport,
       _createRequestId = createRequestId {
    _stdoutSubscription = _transport.stdoutBytes.listen(
      _handleStdoutBytes,
      onError: _handleStdoutError,
      onDone: _handleStdoutDone,
      cancelOnError: false,
    );
    _stderrSubscription = _transport.stderrBytes.listen(
      _handleStderrBytes,
      onError: _handleStderrError,
      cancelOnError: false,
    );
    unawaited(_transport.exitCode.then(_handleExit, onError: _handleExitError));
  }

  final FEngineTransport _transport;
  final String Function() _createRequestId;
  final Duration requestTimeout;
  final Duration shutdownTimeout;
  final int maximumStderrTailBytes;
  final FEngineFrameDecoder _decoder = FEngineFrameDecoder();
  final Map<String, _PendingRequest> _pending = <String, _PendingRequest>{};
  final StreamController<FEngineProtocolEvent> _eventController =
      StreamController<FEngineProtocolEvent>.broadcast();
  final List<int> _stderrTail = <int>[];

  late final StreamSubscription<List<int>> _stdoutSubscription;
  late final StreamSubscription<List<int>> _stderrSubscription;
  Future<FEngineHelloResult>? _connectFuture;
  String? _sessionId;
  int? _lastSequence;
  bool _failed = false;
  bool _closing = false;
  bool _disposed = false;
  int? _exitCode;

  Stream<FEngineProtocolEvent> get events => _eventController.stream;

  String get stderrTail {
    return utf8.decode(_stderrTail, allowMalformed: true);
  }

  bool get isConnected => _sessionId != null && !_failed && !_disposed;

  Future<FEngineHelloResult> connect({
    required String clientName,
    required String clientVersion,
  }) {
    return _connectFuture ??= _connect(
      clientName: clientName,
      clientVersion: clientVersion,
    );
  }

  Future<FEngineHelloResult> _connect({
    required String clientName,
    required String clientVersion,
  }) async {
    final result = await _send(
      kind: _PendingRequestKind.hello,
      commandType: 'hello',
      commandPayload: <String, Object?>{
        'minimum_protocol_version': fengineProtocolVersion,
        'maximum_protocol_version': fengineProtocolVersion,
        'client_name': clientName,
        'client_version': clientVersion,
      },
      sessionId: null,
      timeout: requestTimeout,
    );
    final payload = result.payload;
    final negotiatedVersion = _requireInt(
      payload,
      'negotiated_protocol_version',
      r'$.output.payload.payload',
    );
    if (negotiatedVersion != fengineProtocolVersion) {
      throw _protocolFailure(
        'FEngine negotiated unsupported protocol version $negotiatedVersion',
        requestId: result.requestId,
      );
    }
    final sessionId = _requireNonEmptyString(
      payload,
      '_envelope_session_id',
      r'$.output.payload.payload',
    );
    _sessionId = sessionId;
    return FEngineHelloResult(
      sessionId: sessionId,
      sequence: result.sequence,
      negotiatedProtocolVersion: negotiatedVersion,
      engineVersion: _requireNonEmptyString(
        payload,
        'engine_version',
        r'$.output.payload.payload',
      ),
      heartbeatTimeout: Duration(
        milliseconds: _requirePositiveInt(
          payload,
          'heartbeat_timeout_ms',
          r'$.output.payload.payload',
        ),
      ),
      resumed: _requireBool(payload, 'resumed', r'$.output.payload.payload'),
    );
  }

  Future<FEngineProtocolResult> ping() {
    _ensureConnected();
    return _send(
      kind: _PendingRequestKind.ping,
      commandType: 'ping',
      sessionId: _sessionId,
      timeout: requestTimeout,
    );
  }

  Future<FEngineProtocolResult> requestWork({
    required String commandType,
    Map<String, Object?>? commandPayload,
    required String expectedTerminalEvent,
    Set<String> alternativeTerminalEvents = const <String>{},
    String? requestId,
  }) {
    _ensureConnected();
    return _send(
      kind: _PendingRequestKind.work,
      commandType: commandType,
      commandPayload: commandPayload,
      expectedTerminalEvent: expectedTerminalEvent,
      alternativeTerminalEvents: alternativeTerminalEvents,
      requestId: requestId,
      sessionId: _sessionId,
    );
  }

  Future<FEngineProtocolResult> requestImmediate({
    required String commandType,
    required Map<String, Object?> commandPayload,
    required String expectedResponseType,
  }) {
    _ensureConnected();
    return _send(
      kind: _PendingRequestKind.immediate,
      commandType: commandType,
      commandPayload: commandPayload,
      expectedResponseType: expectedResponseType,
      sessionId: _sessionId,
    );
  }

  Future<void> close() async {
    if (_disposed) {
      return;
    }
    _closing = true;
    if (_transport is FEnginePersistentTransport) {
      await _closeTransport();
      return;
    }
    await shutdownWorker();
  }

  Future<void> shutdownWorker() async {
    if (_disposed) {
      return;
    }
    _closing = true;
    if (isConnected) {
      try {
        await _send(
          kind: _PendingRequestKind.shutdown,
          commandType: 'shutdown',
          expectedTerminalEvent: 'shutdown_complete',
          sessionId: _sessionId,
          timeout: shutdownTimeout,
        );
      } on Object {
        _transport.terminate();
      }
    } else if (_exitCode == null) {
      _transport.terminate();
    }

    await _closeTransport();
  }

  Future<void> abort() async {
    if (_disposed) {
      return;
    }
    _closing = true;
    _transport.terminate();
    try {
      await _transport.closeInput();
    } on Object {
      // Best effort during an already failed connection.
    }
    await _disposeStreams();
  }

  Future<void> _closeTransport() async {
    try {
      await _transport.closeInput();
    } on Object {
      // The peer may already have closed its input while terminating.
    }
    if (_exitCode == null) {
      try {
        await _transport.exitCode.timeout(const Duration(seconds: 5));
      } on Object {
        _transport.terminate();
      }
    }
    await _disposeStreams();
  }

  Future<FEngineProtocolResult> _send({
    required _PendingRequestKind kind,
    required String commandType,
    required String? sessionId,
    Map<String, Object?>? commandPayload,
    String? expectedTerminalEvent,
    Set<String> alternativeTerminalEvents = const <String>{},
    String? expectedResponseType,
    Duration? timeout,
    String? requestId,
  }) async {
    _ensureCanSend(kind);
    final resolvedRequestId = _nextRequestId(requestId);
    final pending = _PendingRequest(
      kind: kind,
      expectedResponseType: expectedResponseType,
      expectedTerminalEvents: expectedTerminalEvent == null
          ? null
          : <String>{expectedTerminalEvent, ...alternativeTerminalEvents},
    );
    _pending[resolvedRequestId] = pending;
    if (timeout != null) {
      pending.timeoutTimer = Timer(timeout, () {
        _failConnection(
          EngineGatewayException(
            kind: EngineGatewayFailureKind.connection,
            message: 'FEngine request timed out after ${timeout.inSeconds}s',
            requestId: resolvedRequestId,
          ),
        );
      });
    }

    final command = <String, Object?>{'type': commandType};
    if (commandPayload != null) {
      command['payload'] = commandPayload;
    }
    final envelope = <String, Object?>{
      'protocol_version': fengineProtocolVersion,
      'session_id': sessionId,
      'request_id': resolvedRequestId,
      'command': command,
    };

    try {
      await _transport.write(FEngineFrameCodec.encode(envelope));
    } on Object catch (error) {
      final failure = EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'cannot write FEngine request: $error',
        requestId: resolvedRequestId,
      );
      _completeError(resolvedRequestId, failure);
      _failConnection(failure);
    }
    return pending.completer.future;
  }

  void _handleStdoutBytes(List<int> bytes) {
    if (_disposed || _failed) {
      return;
    }
    try {
      for (final message in _decoder.add(bytes)) {
        _handleEnvelope(message);
      }
    } on Object catch (error) {
      _failConnection(_protocolFailure('cannot decode FEngine frame: $error'));
    }
  }

  void _handleEnvelope(Map<String, Object?> envelope) {
    final protocolVersion = _requireInt(envelope, 'protocol_version', r'$');
    if (protocolVersion != fengineProtocolVersion) {
      throw _protocolFailure(
        'FEngine output uses unsupported protocol version $protocolVersion',
      );
    }
    final sequence = _requirePositiveInt(envelope, 'sequence', r'$');
    final requestId = _requireNonEmptyString(envelope, 'request_id', r'$');
    final envelopeSessionId = _requireNonEmptyString(
      envelope,
      'session_id',
      r'$',
    );
    final sessionId = _sessionId;
    if (sessionId != null && envelopeSessionId != sessionId) {
      throw _protocolFailure(
        'FEngine output session does not match the active session',
        requestId: requestId,
      );
    }
    final previousSequence = _lastSequence;
    if (previousSequence != null && sequence != previousSequence + 1) {
      _lastSequence = sequence;
      final failure = _protocolFailure(
        'FEngine output sequence jumped from $previousSequence to $sequence; '
        'an authoritative snapshot is required',
        requestId: requestId,
      );
      for (final pendingRequestId in _pending.keys.toList(growable: false)) {
        _completeError(pendingRequestId, failure);
      }
      _eventController.add(
        FEngineProtocolEvent(
          requestId: requestId,
          sequence: sequence,
          type: 'sequence_gap',
          workId: null,
          payload: <String, Object?>{
            'expected_sequence': previousSequence + 1,
            'actual_sequence': sequence,
          },
        ),
      );
      return;
    }
    _lastSequence = sequence;
    final output = _requireObject(envelope, 'output', r'$');
    final kind = _requireNonEmptyString(output, 'kind', r'$.output');
    final payload = _requireObject(output, 'payload', r'$.output');
    final pending = _pending[requestId];
    if (pending == null) {
      if (kind == 'response' && requestId.startsWith('batch-child:')) {
        final type = _requireNonEmptyString(
          payload,
          'type',
          r'$.output.payload',
        );
        if (type != 'accepted') {
          throw _protocolFailure(
            'FEngine batch child returned unsupported response "$type"',
            requestId: requestId,
          );
        }
        return;
      }
      if (kind == 'event') {
        _handleUnsolicitedEvent(
          requestId: requestId,
          sequence: sequence,
          event: payload,
        );
        return;
      }
      if (kind == 'error') {
        _failConnection(_parseWorkerError(payload, requestId: requestId));
        return;
      }
      throw _protocolFailure(
        'FEngine output references unknown request "$requestId"',
        requestId: requestId,
      );
    }
    switch (kind) {
      case 'response':
        _handleResponse(
          requestId: requestId,
          sequence: sequence,
          envelopeSessionId: envelopeSessionId,
          pending: pending,
          response: payload,
        );
      case 'event':
        _handleEvent(
          requestId: requestId,
          sequence: sequence,
          pending: pending,
          event: payload,
        );
      case 'error':
        _completeError(
          requestId,
          _parseWorkerError(payload, requestId: requestId),
        );
      default:
        throw _protocolFailure(
          'FEngine output has unsupported kind "$kind"',
          requestId: requestId,
        );
    }
  }

  void _handleUnsolicitedEvent({
    required String requestId,
    required int sequence,
    required Map<String, Object?> event,
  }) {
    final type = _requireNonEmptyString(event, 'type', r'$.output.payload');
    const executionEventTypes = <String>{
      'work_queued',
      'work_started',
      'analysis_completed',
      'execution_submitted',
      'execution_started',
      'execution_progress',
      'execution_paused',
      'execution_resumed',
      'execution_state_changed',
      'warning',
      'execution_completed',
      'execution_failed',
      'execution_cancelled',
    };
    if (!executionEventTypes.contains(type)) {
      throw _protocolFailure(
        'FEngine emitted unsupported unsolicited event "$type"',
        requestId: requestId,
      );
    }
    final payload = _readPayloadObject(event, type);
    _eventController.add(
      FEngineProtocolEvent(
        requestId: requestId,
        sequence: sequence,
        type: type,
        workId: null,
        payload: payload,
      ),
    );
  }

  void _handleResponse({
    required String requestId,
    required int sequence,
    required String envelopeSessionId,
    required _PendingRequest pending,
    required Map<String, Object?> response,
  }) {
    final type = _requireNonEmptyString(response, 'type', r'$.output.payload');
    final payload = _readPayloadObject(response, type);
    switch (pending.kind) {
      case _PendingRequestKind.hello:
        if (type != 'hello') {
          throw _unexpectedType(requestId, 'response.hello', 'response.$type');
        }
        _completeSuccess(
          requestId,
          FEngineProtocolResult(
            requestId: requestId,
            sequence: sequence,
            workId: null,
            payload: <String, Object?>{
              ...payload,
              '_envelope_session_id': envelopeSessionId,
            },
          ),
        );
      case _PendingRequestKind.ping:
        if (type != 'pong') {
          throw _unexpectedType(requestId, 'response.pong', 'response.$type');
        }
        _completeSuccess(
          requestId,
          FEngineProtocolResult(
            requestId: requestId,
            sequence: sequence,
            workId: null,
            payload: payload,
          ),
        );
      case _PendingRequestKind.immediate:
        final expected = pending.expectedResponseType;
        if (expected == null || type != expected) {
          throw _unexpectedType(
            requestId,
            'response.${expected ?? '<missing>'}',
            'response.$type',
          );
        }
        _completeSuccess(
          requestId,
          FEngineProtocolResult(
            requestId: requestId,
            sequence: sequence,
            workId: null,
            payload: payload,
          ),
        );
      case _PendingRequestKind.work:
        if (type != 'accepted') {
          throw _unexpectedType(
            requestId,
            'response.accepted',
            'response.$type',
          );
        }
        _bindWorkId(
          pending,
          _requireNonEmptyString(
            payload,
            'work_id',
            r'$.output.payload.payload',
          ),
          requestId,
        );
        pending.queueKind = _requireNonEmptyString(
          payload,
          'queue_kind',
          r'$.output.payload.payload',
        );
        pending.queuePosition = _requireInt(
          payload,
          'queue_position',
          r'$.output.payload.payload',
        );
        pending.queueRevision = _requireInt(
          payload,
          'queue_revision',
          r'$.output.payload.payload',
        );
      case _PendingRequestKind.shutdown:
        if (type != 'shutdown_accepted') {
          throw _unexpectedType(
            requestId,
            'response.shutdown_accepted',
            'response.$type',
          );
        }
    }
  }

  void _handleEvent({
    required String requestId,
    required int sequence,
    required _PendingRequest pending,
    required Map<String, Object?> event,
  }) {
    final type = _requireNonEmptyString(event, 'type', r'$.output.payload');
    final payload = _readPayloadObject(event, type);
    final workId = switch (type) {
      'shutdown_complete' => null,
      _ => _requireNonEmptyString(
        payload,
        'work_id',
        r'$.output.payload.payload',
      ),
    };
    if (workId != null) {
      _bindWorkId(pending, workId, requestId);
    }

    if (type == 'work_failed') {
      final error = _parseWorkerError(
        _requireObject(payload, 'error', r'$.output.payload.payload'),
        requestId: requestId,
      );
      _eventController.add(
        FEngineProtocolEvent(
          requestId: requestId,
          sequence: sequence,
          type: type,
          workId: workId,
          payload: payload,
          error: error,
        ),
      );
      _completeError(requestId, error);
      return;
    }

    _eventController.add(
      FEngineProtocolEvent(
        requestId: requestId,
        sequence: sequence,
        type: type,
        workId: workId,
        payload: payload,
      ),
    );

    if (type == 'work_queued' || type == 'work_started') {
      if (pending.kind != _PendingRequestKind.work) {
        throw _unexpectedType(requestId, 'terminal event', 'event.$type');
      }
      return;
    }

    final expected = pending.expectedTerminalEvents;
    if (expected == null || !expected.contains(type)) {
      throw _unexpectedType(
        requestId,
        expected == null ? 'no event' : 'one of ${expected.join(', ')}',
        'event.$type',
      );
    }
    _completeSuccess(
      requestId,
      FEngineProtocolResult(
        requestId: requestId,
        sequence: sequence,
        workId: workId,
        payload: payload,
        queueKind: pending.queueKind,
        queuePosition: pending.queuePosition,
        queueRevision: pending.queueRevision,
      ),
    );
  }

  void _bindWorkId(_PendingRequest pending, String workId, String requestId) {
    final existing = pending.workId;
    if (existing != null && existing != workId) {
      throw _protocolFailure(
        'FEngine changed work_id for request "$requestId"',
        requestId: requestId,
      );
    }
    pending.workId = workId;
  }

  void _completeSuccess(String requestId, FEngineProtocolResult result) {
    final pending = _pending.remove(requestId);
    if (pending == null) {
      return;
    }
    pending.timeoutTimer?.cancel();
    if (!pending.completer.isCompleted) {
      pending.completer.complete(result);
    }
  }

  void _completeError(String requestId, Object error) {
    final pending = _pending.remove(requestId);
    if (pending == null) {
      return;
    }
    pending.timeoutTimer?.cancel();
    if (!pending.completer.isCompleted) {
      pending.completer.completeError(error);
    }
  }

  void _handleStdoutError(Object error, StackTrace stackTrace) {
    _failConnection(
      EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'FEngine stdout failed: $error',
      ),
      stackTrace,
    );
  }

  void _handleStdoutDone() {
    if (_disposed || (_closing && _pending.isEmpty)) {
      return;
    }
    try {
      _decoder.close();
    } on Object catch (error) {
      _failConnection(
        _protocolFailure('FEngine stdout ended with a truncated frame: $error'),
      );
      return;
    }
    _failConnection(
      EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: _connectionEndedMessage('FEngine stdout closed unexpectedly'),
      ),
    );
  }

  void _handleStderrBytes(List<int> bytes) {
    if (maximumStderrTailBytes <= 0 || bytes.isEmpty) {
      return;
    }
    _stderrTail.addAll(bytes);
    final overflow = _stderrTail.length - maximumStderrTailBytes;
    if (overflow > 0) {
      _stderrTail.removeRange(0, overflow);
    }
  }

  void _handleStderrError(Object error, StackTrace stackTrace) {
    _failConnection(
      EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'FEngine stderr failed: $error',
      ),
      stackTrace,
    );
  }

  void _handleExit(int exitCode) {
    _exitCode = exitCode;
    if (_disposed || (_closing && _pending.isEmpty && exitCode == 0)) {
      return;
    }
    _failConnection(
      EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: _connectionEndedMessage(
          'FEngine exited with status $exitCode',
        ),
      ),
    );
  }

  void _handleExitError(Object error, StackTrace stackTrace) {
    _failConnection(
      EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'cannot observe FEngine exit status: $error',
      ),
      stackTrace,
    );
  }

  void _failConnection(
    EngineGatewayException failure, [
    StackTrace? stackTrace,
  ]) {
    if (_failed || _disposed) {
      return;
    }
    _failed = true;
    final pendingEntries = _pending.entries.toList(growable: false);
    _pending.clear();
    for (final entry in pendingEntries) {
      entry.value.timeoutTimer?.cancel();
      if (!entry.value.completer.isCompleted) {
        entry.value.completer.completeError(
          failure,
          stackTrace ?? StackTrace.current,
        );
      }
    }
    if (!_closing) {
      _transport.terminate();
    }
  }

  Future<void> _disposeStreams() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final closeFailure = const EngineGatewayException(
      kind: EngineGatewayFailureKind.closed,
      message: 'FEngine connection closed',
    );
    final pendingEntries = _pending.entries.toList(growable: false);
    _pending.clear();
    for (final entry in pendingEntries) {
      entry.value.timeoutTimer?.cancel();
      if (!entry.value.completer.isCompleted) {
        entry.value.completer.completeError(closeFailure);
      }
    }
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    await _eventController.close();
  }

  void _ensureConnected() {
    if (!isConnected) {
      throw EngineGatewayException(
        kind: _disposed
            ? EngineGatewayFailureKind.closed
            : EngineGatewayFailureKind.connection,
        message: 'FEngine handshake is not complete',
      );
    }
  }

  void _ensureCanSend(_PendingRequestKind kind) {
    if (_disposed ||
        _failed ||
        (_closing && kind != _PendingRequestKind.shutdown)) {
      throw EngineGatewayException(
        kind: _disposed
            ? EngineGatewayFailureKind.closed
            : EngineGatewayFailureKind.connection,
        message: 'FEngine connection cannot accept new requests',
      );
    }
    if (kind != _PendingRequestKind.hello && _sessionId == null) {
      _ensureConnected();
    }
  }

  String _nextRequestId(String? requested) {
    final requestId = requested ?? _createRequestId();
    if (requestId.trim().isEmpty ||
        requestId.length > 256 ||
        _pending.containsKey(requestId)) {
      throw const EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'request id generator returned an invalid or duplicate id',
      );
    }
    return requestId;
  }

  String _connectionEndedMessage(String summary) {
    final diagnostics = stderrTail.trim();
    if (diagnostics.isEmpty) {
      return summary;
    }
    return '$summary; stderr: $diagnostics';
  }

  EngineWorkerException _parseWorkerError(
    Map<String, Object?> json, {
    required String requestId,
  }) {
    return EngineWorkerException(
      code: _requireNonEmptyString(json, 'code', r'$.output.payload'),
      engineCode: _readNullableString(json, 'engine_code', r'$.output.payload'),
      retryable: _requireBool(json, 'retryable', r'$.output.payload'),
      message: _requireNonEmptyString(json, 'message', r'$.output.payload'),
      requestId: requestId,
    );
  }

  EngineGatewayException _unexpectedType(
    String requestId,
    String expected,
    String actual,
  ) {
    return _protocolFailure(
      'FEngine request "$requestId" expected $expected but received $actual',
      requestId: requestId,
    );
  }

  EngineGatewayException _protocolFailure(String message, {String? requestId}) {
    return EngineGatewayException(
      kind: EngineGatewayFailureKind.protocol,
      message: message,
      requestId: requestId,
    );
  }

  Map<String, Object?> _readPayloadObject(
    Map<String, Object?> envelope,
    String type,
  ) {
    final payload = envelope['payload'];
    if (payload == null) {
      if (type == 'pong' ||
          type == 'shutdown_accepted' ||
          type == 'shutdown_complete') {
        return const <String, Object?>{};
      }
      throw _protocolFailure(
        'FEngine $type output is missing its payload object',
      );
    }
    return _expectObject(payload, r'$.output.payload.payload');
  }

  Map<String, Object?> _requireObject(
    Map<String, Object?> json,
    String key,
    String path,
  ) {
    return _expectObject(json[key], '$path.$key');
  }

  Map<String, Object?> _expectObject(Object? value, String path) {
    if (value is! Map) {
      throw _protocolFailure('$path must be an object');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw _protocolFailure('$path contains a non-string key');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  String _requireNonEmptyString(
    Map<String, Object?> json,
    String key,
    String path,
  ) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw _protocolFailure('$path.$key must be a non-empty string');
    }
    return value;
  }

  String? _readNullableString(
    Map<String, Object?> json,
    String key,
    String path,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw _protocolFailure('$path.$key must be a string or null');
    }
    return value;
  }

  int _requireInt(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! int) {
      throw _protocolFailure('$path.$key must be an integer');
    }
    return value;
  }

  int _requirePositiveInt(Map<String, Object?> json, String key, String path) {
    final value = _requireInt(json, key, path);
    if (value <= 0) {
      throw _protocolFailure('$path.$key must be positive');
    }
    return value;
  }

  bool _requireBool(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! bool) {
      throw _protocolFailure('$path.$key must be a boolean');
    }
    return value;
  }
}
