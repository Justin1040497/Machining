import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/services/engine/fengine_frame_codec.dart';
import 'package:framelean/infrastructure/services/engine/fengine_protocol_client.dart';

void main() {
  group('FEngineProtocolClient', () {
    test('completes a work request only after its terminal event', () async {
      final fixture = await _connectedFixture(<String>['hello-1', 'analyze-1']);
      addTearDown(fixture.dispose);
      final events = <FEngineProtocolEvent>[];
      final subscription = fixture.client.events.listen(events.add);
      addTearDown(subscription.cancel);

      var completed = false;
      final operation = fixture.client
          .requestWork(
            commandType: 'analyze_media',
            commandPayload: const <String, Object?>{'client_task_id': 'task-1'},
            expectedTerminalEvent: 'analysis_completed',
          )
          .whenComplete(() => completed = true);
      await _pump();

      fixture.transport.emit(
        _response(
          requestId: 'analyze-1',
          sequence: 2,
          type: 'accepted',
          payload: _accepted('work-1'),
        ),
      );
      await _pump();
      expect(completed, isFalse);

      fixture.transport.emit(
        _event(
          requestId: 'analyze-1',
          sequence: 3,
          type: 'work_queued',
          payload: <String, Object?>{'work_id': 'work-1', 'queue_position': 0},
        ),
      );
      await _pump();
      expect(completed, isFalse);

      fixture.transport.emit(
        _event(
          requestId: 'analyze-1',
          sequence: 4,
          type: 'analysis_completed',
          payload: <String, Object?>{
            'work_id': 'work-1',
            'client_task_id': 'task-1',
            'client_file_id': 'file-1',
            'analysis': <String, Object?>{'analysis_id': 'analysis-1'},
          },
        ),
      );

      final result = await operation;
      expect(result.workId, 'work-1');
      expect(result.sequence, 4);
      expect(events.map((event) => event.type), [
        'work_queued',
        'analysis_completed',
      ]);
    });

    test('accepts atomic batch receipt after child queue events', () async {
      final fixture = await _connectedFixture(<String>['hello-1', 'batch-1']);
      addTearDown(fixture.dispose);
      final events = <FEngineProtocolEvent>[];
      final subscription = fixture.client.events.listen(events.add);
      addTearDown(subscription.cancel);

      final operation = fixture.client.requestImmediate(
        commandType: 'submit_analysis_batch',
        commandPayload: const <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'client_task_id': 'task-1'},
          ],
        },
        expectedResponseType: 'batch_accepted',
      );
      await _pump();

      fixture.transport.emit(
        _response(
          requestId: 'batch-child:batch-1:0',
          sequence: 2,
          type: 'accepted',
          payload: _accepted('work-1'),
        ),
      );
      fixture.transport.emit(
        _event(
          requestId: 'batch-child:batch-1:0',
          sequence: 3,
          type: 'work_queued',
          payload: <String, Object?>{
            'work_id': 'work-1',
            'client_task_id': 'task-1',
            'queue_kind': 'analysis',
            'queue_position': 1,
            'queue_revision': 1,
          },
        ),
      );
      fixture.transport.emit(
        _event(
          requestId: 'batch-child:batch-1:0',
          sequence: 4,
          type: 'analysis_completed',
          payload: _analysisCompleted('work-1', 'analysis-1'),
        ),
      );
      fixture.transport.emit(
        _response(
          requestId: 'batch-1',
          sequence: 5,
          type: 'batch_accepted',
          payload: <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'client_task_id': 'task-1',
                'child_request_id': 'batch-child:batch-1:0',
                'work_id': 'work-1',
                'queue_kind': 'analysis',
                'queue_position': 1,
                'queue_revision': 1,
              },
            ],
          },
        ),
      );

      final result = await operation;
      expect(result.sequence, 5);
      expect(result.payload['items'], hasLength(1));
      expect(events.map((event) => event.type), [
        'work_queued',
        'analysis_completed',
      ]);
    });

    test('allows interleaved requests to share one work id', () async {
      final fixture = await _connectedFixture(<String>[
        'hello-1',
        'analyze-1',
        'analyze-2',
      ]);
      addTearDown(fixture.dispose);

      final first = fixture.client.requestWork(
        commandType: 'analyze_media',
        commandPayload: const <String, Object?>{'client_task_id': 'task-1'},
        expectedTerminalEvent: 'analysis_completed',
      );
      final second = fixture.client.requestWork(
        commandType: 'analyze_media',
        commandPayload: const <String, Object?>{'client_task_id': 'task-1'},
        expectedTerminalEvent: 'analysis_completed',
      );
      await _pump();

      fixture.transport.emit(
        _response(
          requestId: 'analyze-1',
          sequence: 2,
          type: 'accepted',
          payload: _accepted('work-shared'),
        ),
      );
      fixture.transport.emit(
        _response(
          requestId: 'analyze-2',
          sequence: 3,
          type: 'accepted',
          payload: <String, Object?>{
            ..._accepted('work-shared'),
            'deduplicated': true,
          },
        ),
      );
      fixture.transport.emit(
        _event(
          requestId: 'analyze-2',
          sequence: 4,
          type: 'analysis_completed',
          payload: _analysisCompleted('work-shared', 'analysis-1'),
        ),
      );
      fixture.transport.emit(
        _event(
          requestId: 'analyze-1',
          sequence: 5,
          type: 'analysis_completed',
          payload: _analysisCompleted('work-shared', 'analysis-1'),
        ),
      );

      expect((await second).workId, 'work-shared');
      expect((await first).workId, 'work-shared');
    });

    test('accepts duplicate Accepted responses for the same work', () async {
      final fixture = await _connectedFixture(<String>['hello-1', 'analyze-1']);
      addTearDown(fixture.dispose);

      final operation = fixture.client.requestWork(
        commandType: 'analyze_media',
        commandPayload: const <String, Object?>{'client_task_id': 'task-1'},
        expectedTerminalEvent: 'analysis_completed',
      );
      await _pump();
      fixture.transport.emit(
        _response(
          requestId: 'analyze-1',
          sequence: 2,
          type: 'accepted',
          payload: _accepted('work-1'),
        ),
      );
      fixture.transport.emit(
        _response(
          requestId: 'analyze-1',
          sequence: 3,
          type: 'accepted',
          payload: _accepted('work-1'),
        ),
      );
      fixture.transport.emit(
        _event(
          requestId: 'analyze-1',
          sequence: 4,
          type: 'analysis_completed',
          payload: _analysisCompleted('work-1', 'analysis-1'),
        ),
      );

      expect((await operation).workId, 'work-1');
    });

    test(
      'fails pending work but keeps the session for snapshot recovery on a gap',
      () async {
        final fixture = await _connectedFixture(<String>[
          'hello-1',
          'analyze-1',
          'ping-1',
        ]);
        addTearDown(fixture.dispose);
        final events = <FEngineProtocolEvent>[];
        final subscription = fixture.client.events.listen(events.add);
        addTearDown(subscription.cancel);

        final work = fixture.client.requestWork(
          commandType: 'analyze_media',
          commandPayload: const <String, Object?>{'client_task_id': 'task-1'},
          expectedTerminalEvent: 'analysis_completed',
        );
        final ping = fixture.client.ping();
        final workExpectation = expectLater(
          work,
          throwsA(
            isA<EngineGatewayException>().having(
              (error) => error.kind,
              'kind',
              EngineGatewayFailureKind.protocol,
            ),
          ),
        );
        final pingExpectation = expectLater(
          ping,
          throwsA(isA<EngineGatewayException>()),
        );
        await _pump();

        fixture.transport.emit(
          _response(
            requestId: 'analyze-1',
            sequence: 3,
            type: 'accepted',
            payload: _accepted('work-1'),
          ),
        );

        await workExpectation;
        await pingExpectation;
        await _pump();
        expect(fixture.transport.terminated, isFalse);
        expect(fixture.client.isConnected, isTrue);
        expect(events.single.type, 'sequence_gap');
        expect(events.single.payload['expected_sequence'], 2);
        expect(events.single.payload['actual_sequence'], 3);
      },
    );

    test('maps Worker error output without closing the session', () async {
      final fixture = await _connectedFixture(<String>[
        'hello-1',
        'ping-1',
        'ping-2',
      ]);
      addTearDown(fixture.dispose);

      final firstPing = fixture.client.ping();
      final expectation = expectLater(
        firstPing,
        throwsA(
          isA<EngineWorkerException>()
              .having((error) => error.code, 'code', 'WORKER_BUSY')
              .having((error) => error.retryable, 'retryable', true),
        ),
      );
      await _pump();
      fixture.transport.emit(
        _workerError(
          requestId: 'ping-1',
          sequence: 2,
          code: 'WORKER_BUSY',
          retryable: true,
        ),
      );
      await expectation;

      final secondPing = fixture.client.ping();
      await _pump();
      fixture.transport.emit(
        _response(requestId: 'ping-2', sequence: 3, type: 'pong'),
      );
      await secondPing;
      expect(fixture.client.isConnected, isTrue);
    });

    test('maps work_failed as the terminal operation failure', () async {
      final fixture = await _connectedFixture(<String>[
        'hello-1',
        'snapshot-1',
      ]);
      addTearDown(fixture.dispose);
      final events = <FEngineProtocolEvent>[];
      final subscription = fixture.client.events.listen(events.add);
      addTearDown(subscription.cancel);

      final operation = fixture.client.requestWork(
        commandType: 'get_analysis_snapshot',
        commandPayload: const <String, Object?>{'analysis_id': 'analysis-1'},
        expectedTerminalEvent: 'analysis_snapshot_ready',
      );
      final expectation = expectLater(
        operation,
        throwsA(
          isA<EngineWorkerException>().having(
            (error) => error.engineCode,
            'engineCode',
            'ANALYSIS_SOURCE_CHANGED',
          ),
        ),
      );
      await _pump();
      fixture.transport.emit(
        _response(
          requestId: 'snapshot-1',
          sequence: 2,
          type: 'accepted',
          payload: _accepted('work-1'),
        ),
      );
      fixture.transport.emit(
        _event(
          requestId: 'snapshot-1',
          sequence: 3,
          type: 'work_failed',
          payload: <String, Object?>{
            'work_id': 'work-1',
            'error': <String, Object?>{
              'code': 'RUNTIME_FAILURE',
              'engine_code': 'ANALYSIS_SOURCE_CHANGED',
              'message': 'source changed',
              'retryable': false,
            },
          },
        ),
      );

      await expectation;
      expect(events.single.error?.engineCode, 'ANALYSIS_SOURCE_CHANGED');
    });

    test('includes drained stderr when stdout closes unexpectedly', () async {
      final fixture = await _connectedFixture(<String>['hello-1', 'analyze-1']);
      addTearDown(fixture.dispose);

      final operation = fixture.client.requestWork(
        commandType: 'analyze_media',
        commandPayload: const <String, Object?>{'client_task_id': 'task-1'},
        expectedTerminalEvent: 'analysis_completed',
      );
      final expectation = expectLater(
        operation,
        throwsA(
          isA<EngineGatewayException>().having(
            (error) => error.message,
            'message',
            contains('runtime diagnostic'),
          ),
        ),
      );
      fixture.transport.emitStderr('runtime diagnostic');
      await _pump();
      await fixture.transport.closeStdout();

      await expectation;
    });

    test('waits for shutdown_complete rather than shutdown ACK', () async {
      final fixture = await _connectedFixture(<String>[
        'hello-1',
        'shutdown-1',
      ]);
      final closeFuture = fixture.client.close();
      var completed = false;
      closeFuture.whenComplete(() => completed = true);
      await _pump();

      fixture.transport.emit(
        _response(
          requestId: 'shutdown-1',
          sequence: 2,
          type: 'shutdown_accepted',
        ),
      );
      await _pump();
      expect(completed, isFalse);

      fixture.transport.emit(
        _event(requestId: 'shutdown-1', sequence: 3, type: 'shutdown_complete'),
      );
      fixture.transport.completeExit(0);
      await closeFuture;
      await fixture.transport.dispose();
    });

    test('closing a persistent transport detaches without shutdown', () async {
      final transport = _PersistentFakeTransport();
      final fixture = await _connectedFixture(<String>[
        'hello-1',
      ], transport: transport);

      await fixture.client.close();

      expect(transport.inputClosed, isTrue);
      expect(
        transport.writes
            .map(_decodeFrame)
            .map((request) => request['command'] as Map<String, Object?>)
            .map((command) => command['type']),
        <String>['hello'],
      );
      await transport.dispose();
    });

    test('explicit shutdown still stops a persistent worker', () async {
      final transport = _PersistentFakeTransport(autoCompleteShutdown: true);
      final fixture = await _connectedFixture(<String>[
        'hello-1',
        'shutdown-1',
      ], transport: transport);

      await fixture.client.shutdownWorker();

      expect(
        transport.writes
            .map(_decodeFrame)
            .map((request) => request['command'] as Map<String, Object?>)
            .map((command) => command['type']),
        <String>['hello', 'shutdown'],
      );
      await transport.dispose();
    });
  });
}

Future<_ConnectedFixture> _connectedFixture(
  List<String> requestIds, {
  _FakeTransport? transport,
}) async {
  transport ??= _FakeTransport();
  final ids = Queue<String>.of(requestIds);
  final client = FEngineProtocolClient(
    transport: transport,
    createRequestId: ids.removeFirst,
  );
  final connectFuture = client.connect(
    clientName: 'FrameLean Desktop',
    clientVersion: '1.3.0',
  );
  await _pump();

  final request = _decodeFrame(transport.writes.single);
  expect(request['session_id'], isNull);
  expect(request['request_id'], 'hello-1');
  expect((request['command']! as Map<String, Object?>)['type'], 'hello');

  transport.emit(
    _response(
      requestId: 'hello-1',
      sequence: 1,
      type: 'hello',
      payload: <String, Object?>{
        'negotiated_protocol_version': 1,
        'engine_version': '0.1.0',
        'heartbeat_timeout_ms': 15000,
        'resumed': false,
      },
    ),
  );
  final hello = await connectFuture;
  expect(hello.sessionId, 'session-1');
  return _ConnectedFixture(client, transport);
}

final class _ConnectedFixture {
  const _ConnectedFixture(this.client, this.transport);

  final FEngineProtocolClient client;
  final _FakeTransport transport;

  Future<void> dispose() async {
    await client.abort();
    await transport.dispose();
  }
}

class _FakeTransport implements FEngineTransport {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final Completer<int> _exitCompleter = Completer<int>();
  final List<Uint8List> writes = <Uint8List>[];
  bool inputClosed = false;
  bool terminated = false;

  @override
  Stream<List<int>> get stdoutBytes => _stdoutController.stream;

  @override
  Stream<List<int>> get stderrBytes => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  Future<void> write(Uint8List bytes) async {
    writes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> closeInput() async {
    inputClosed = true;
  }

  @override
  bool terminate() {
    terminated = true;
    completeExit(-15);
    return true;
  }

  void emit(Map<String, Object?> envelope) {
    _stdoutController.add(FEngineFrameCodec.encode(envelope));
  }

  void emitStderr(String text) {
    _stderrController.add(Uint8List.fromList(text.codeUnits));
  }

  Future<void> closeStdout() => _stdoutController.close();

  void completeExit(int value) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(value);
    }
  }

  Future<void> dispose() async {
    completeExit(0);
    if (!_stdoutController.isClosed) {
      await _stdoutController.close();
    }
    if (!_stderrController.isClosed) {
      await _stderrController.close();
    }
  }
}

final class _PersistentFakeTransport extends _FakeTransport
    implements FEnginePersistentTransport {
  _PersistentFakeTransport({this.autoCompleteShutdown = false});

  final bool autoCompleteShutdown;

  @override
  Future<void> write(Uint8List bytes) async {
    await super.write(bytes);
    final request = _decodeFrame(bytes);
    final command = request['command'] as Map<String, Object?>;
    if (autoCompleteShutdown && command['type'] == 'shutdown') {
      final requestId = request['request_id'] as String;
      emit(
        _response(requestId: requestId, sequence: 2, type: 'shutdown_accepted'),
      );
      emit(
        _event(requestId: requestId, sequence: 3, type: 'shutdown_complete'),
      );
    }
  }

  @override
  Future<void> closeInput() async {
    await super.closeInput();
    completeExit(0);
  }
}

Map<String, Object?> _decodeFrame(Uint8List bytes) {
  final decoder = FEngineFrameDecoder();
  final message = decoder.add(bytes).single;
  decoder.close();
  return message;
}

Map<String, Object?> _response({
  required String requestId,
  required int sequence,
  required String type,
  Map<String, Object?>? payload,
}) {
  final response = <String, Object?>{'type': type};
  if (payload != null) {
    response['payload'] = payload;
  }
  return _output(
    requestId: requestId,
    sequence: sequence,
    kind: 'response',
    payload: response,
  );
}

Map<String, Object?> _event({
  required String requestId,
  required int sequence,
  required String type,
  Map<String, Object?>? payload,
}) {
  final event = <String, Object?>{'type': type};
  if (payload != null) {
    event['payload'] = payload;
  }
  return _output(
    requestId: requestId,
    sequence: sequence,
    kind: 'event',
    payload: event,
  );
}

Map<String, Object?> _workerError({
  required String requestId,
  required int sequence,
  required String code,
  required bool retryable,
}) {
  return _output(
    requestId: requestId,
    sequence: sequence,
    kind: 'error',
    payload: <String, Object?>{
      'code': code,
      'engine_code': null,
      'message': 'worker error',
      'retryable': retryable,
    },
  );
}

Map<String, Object?> _output({
  required String requestId,
  required int sequence,
  required String kind,
  required Map<String, Object?> payload,
}) {
  return <String, Object?>{
    'protocol_version': 1,
    'session_id': 'session-1',
    'sequence': sequence,
    'request_id': requestId,
    'output': <String, Object?>{'kind': kind, 'payload': payload},
  };
}

Map<String, Object?> _accepted(String workId) {
  return <String, Object?>{
    'work_id': workId,
    'queue_kind': 'analysis',
    'queue_position': 0,
    'queue_revision': 1,
    'state': 'queued',
    'analysis_id': null,
    'deduplicated': false,
  };
}

Map<String, Object?> _analysisCompleted(String workId, String analysisId) {
  return <String, Object?>{
    'work_id': workId,
    'client_task_id': 'task-1',
    'client_file_id': 'file-1',
    'analysis': <String, Object?>{'analysis_id': analysisId},
  };
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
