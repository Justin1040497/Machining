import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/services/engine/fengine_frame_codec.dart';
import 'package:framelean/infrastructure/services/engine/fengine_protocol_client.dart';
import 'package:framelean/infrastructure/services/engine/local_fengine_gateway.dart';

void main() {
  group('LocalFEngineGateway', () {
    test('parses authoritative queue and offline terminal snapshots', () async {
      final fixture = await _connectedGateway(<String>[
        'hello-1',
        'snapshot-1',
        'shutdown-1',
      ]);
      addTearDown(fixture.dispose);

      final operation = fixture.gateway.getEngineSnapshot();
      await _pump();
      expect(fixture.transport.lastRequest['command'], <String, Object?>{
        'type': 'get_engine_snapshot',
      });
      fixture.transport.respond(
        requestId: 'snapshot-1',
        kind: 'response',
        type: 'accepted',
        payload: _accepted('snapshot-work'),
      );
      fixture.transport.respond(
        requestId: 'snapshot-1',
        kind: 'event',
        type: 'engine_snapshot_ready',
        payload: <String, Object?>{
          'work_id': 'snapshot-work',
          'snapshot': <String, Object?>{
            'analysis_queue_revision': 2,
            'active_analysis': null,
            'analysis_queue': <Object?>[],
            'terminal_analyses': <Object?>[
              <String, Object?>{
                'work_id': 'analysis-work',
                'client_task_id': 'task-analysis',
                'client_file_id': 'file-analysis',
                'analysis_id': 'analysis-1',
                'analysis_revision': 3,
                'succeeded': true,
                'engine_code': null,
                'message': null,
              },
            ],
            'execution_lane': <String, Object?>{
              'queue_revision': 4,
              'active_executions': <Object?>[],
              'normal_waiting': <Object?>[],
              'video_resume_stack': <Object?>[],
              'auxiliary_resume_stack': <Object?>[],
              'user_paused': <Object?>[],
            },
            'terminal_executions': <Object?>[
              <String, Object?>{
                'execution_id': 'execution-1',
                'client_task_id': 'task-execution',
                'resource_pool': 'auxiliary',
                'state': 'completed',
                'output_path': '/output.wav',
                'engine_code': null,
                'message': null,
              },
            ],
            'last_sequence': 8,
          },
        },
      );

      final result = await operation;
      expect(result.value.analysisQueueRevision, 2);
      expect(result.value.terminalAnalyses.single.analysisId, 'analysis-1');
      expect(result.value.terminalAnalyses.single.succeeded, isTrue);
      expect(
        result.value.terminalExecutions.single.state,
        EngineExecutionState.completed,
      );
      expect(result.value.terminalExecutions.single.outputPath, '/output.wav');
    });

    test(
      'maps analysis request and returns the terminal FLL document',
      () async {
        final fixture = await _connectedGateway(<String>[
          'hello-1',
          'analyze-1',
          'shutdown-1',
        ]);
        addTearDown(fixture.dispose);
        final events = <EngineWorkEvent>[];
        final subscription = fixture.gateway.events.listen(events.add);
        addTearDown(subscription.cancel);

        var completed = false;
        final operation = fixture.gateway
            .analyze(
              const EngineAnalysisRequest(
                clientTaskId: 'task-1',
                clientFileId: 'file-1',
                source: EngineSourceFacts(
                  path: '/media/input.mp4',
                  fileSizeBytes: 123,
                  modifiedTimeUnixNanos: '456000000',
                ),
                taskMode: EngineTaskMode.videoCompress,
                priority: EngineWorkPriority.background,
              ),
            )
            .whenComplete(() => completed = true);
        await _pump();

        final request = fixture.transport.lastRequest;
        final command = request['command']! as Map<String, Object?>;
        final payload = command['payload']! as Map<String, Object?>;
        expect(command['type'], 'analyze_media');
        expect(payload['task_mode'], 'video_compress');
        expect(payload['priority'], 'background');
        expect(payload['force_reanalysis'], isFalse);
        expect(payload['source'], <String, Object?>{
          'path': '/media/input.mp4',
          'file_size_bytes': 123,
          'modified_time_unix_nanos': '456000000',
        });

        fixture.transport.respond(
          requestId: 'analyze-1',
          kind: 'response',
          type: 'accepted',
          payload: _accepted('work-1'),
        );
        await _pump();
        expect(completed, isFalse);

        fixture.transport.respond(
          requestId: 'analyze-1',
          kind: 'event',
          type: 'work_queued',
          payload: <String, Object?>{'work_id': 'work-1', 'queue_position': 2},
        );
        fixture.transport.respond(
          requestId: 'analyze-1',
          kind: 'event',
          type: 'analysis_completed',
          payload: <String, Object?>{
            'work_id': 'work-1',
            'client_task_id': 'task-1',
            'client_file_id': 'file-1',
            'analysis': _analysisResponse(),
          },
        );

        final result = await operation;
        await _pump();
        expect(result.workId, 'work-1');
        expect(result.value.analysis.analysisId, 'analysis-1');
        expect(result.value.snapshot, isNull);
        expect(events.map((event) => event.type), [
          EngineWorkEventType.queued,
          EngineWorkEventType.completed,
        ]);
        expect(events.first.queuePosition, 2);
      },
    );

    test('returns failed analysis as a typed FLL result', () async {
      final fixture = await _connectedGateway(<String>[
        'hello-1',
        'analyze-1',
        'shutdown-1',
      ]);
      addTearDown(fixture.dispose);

      final operation = fixture.gateway.analyze(
        const EngineAnalysisRequest(
          clientTaskId: 'task-1',
          clientFileId: 'file-1',
          source: EngineSourceFacts(
            path: '/media/input.bin',
            fileSizeBytes: 5,
            modifiedTimeUnixNanos: null,
          ),
          taskMode: EngineTaskMode.videoCompress,
        ),
      );
      await _pump();
      fixture.transport.respond(
        requestId: 'analyze-1',
        kind: 'response',
        type: 'accepted',
        payload: _accepted('work-1'),
      );
      fixture.transport.respond(
        requestId: 'analyze-1',
        kind: 'event',
        type: 'analysis_completed',
        payload: <String, Object?>{
          'work_id': 'work-1',
          'client_task_id': 'task-1',
          'client_file_id': 'file-1',
          'analysis': _failedAnalysisResponse(),
        },
      );

      final result = await operation;
      expect(
        result.value.analysis.mediaAnalysisStatus,
        EngineMediaAnalysisStatus.failed,
      );
      expect(result.value.analysis.errorCode, 'MEDIA_INVALID_FORMAT');
    });

    test('maps preview frame requests and terminal artifacts', () async {
      final fixture = await _connectedGateway(<String>[
        'hello-1',
        'preview-1',
        'shutdown-1',
      ]);
      addTearDown(fixture.dispose);

      final operation = fixture.gateway.generatePreviewFrames(
        EnginePreviewFramesRequest(
          clientTaskId: 'task-1',
          source: EngineSourceFacts(
            path: '/media/input.mp4',
            fileSizeBytes: 123,
            modifiedTimeUnixNanos: '456000000',
          ),
          outputDirectory: '/cache/previews/task-1',
          timestampsUs: <int>[1000000, 2000000],
          maxWidth: 960,
        ),
      );
      await _pump();

      final command =
          fixture.transport.lastRequest['command']! as Map<String, Object?>;
      final payload = command['payload']! as Map<String, Object?>;
      expect(command['type'], 'generate_preview_frames');
      expect(payload['client_task_id'], 'task-1');
      expect(payload['timestamps_us'], <int>[1000000, 2000000]);
      expect(payload['max_width'], 960);
      expect(payload['source'], <String, Object?>{
        'path': '/media/input.mp4',
        'file_size_bytes': 123,
        'modified_time_unix_nanos': '456000000',
      });

      fixture.transport.respond(
        requestId: 'preview-1',
        kind: 'response',
        type: 'accepted',
        payload: <String, Object?>{
          ..._accepted('preview-work'),
          'queue_kind': 'control',
        },
      );
      fixture.transport.respond(
        requestId: 'preview-1',
        kind: 'event',
        type: 'preview_frames_ready',
        payload: <String, Object?>{
          'work_id': 'preview-work',
          'client_task_id': 'task-1',
          'result': <String, Object?>{
            'output_directory': '/cache/previews/task-1',
            'frames': <Object?>[
              <String, Object?>{
                'index': 0,
                'requested_timestamp_us': 1000000,
                'decoded_timestamp_us': 1001000,
                'width': 960,
                'height': 540,
                'output_path': '/cache/previews/task-1/frame-000.bmp',
              },
              <String, Object?>{
                'index': 1,
                'requested_timestamp_us': 2000000,
                'decoded_timestamp_us': 2001000,
                'width': 960,
                'height': 540,
                'output_path': '/cache/previews/task-1/frame-001.bmp',
              },
            ],
          },
        },
      );

      final result = await operation;
      expect(result.queueKind, EngineQueueKind.control);
      expect(result.value.frames, hasLength(2));
      expect(result.value.frames.last.decodedTimestampUs, 2001000);
      expect(
        result.value.frames.last.outputPath,
        '/cache/previews/task-1/frame-001.bmp',
      );
    });

    test('maps video thumbnail requests and terminal artifacts', () async {
      final fixture = await _connectedGateway(<String>[
        'hello-1',
        'thumbnail-1',
        'shutdown-1',
      ]);
      addTearDown(fixture.dispose);

      final operation = fixture.gateway.generateVideoThumbnail(
        const EngineVideoThumbnailRequest(
          clientTaskId: 'task-2',
          source: EngineSourceFacts(
            path: '/media/input.mov',
            fileSizeBytes: 321,
            modifiedTimeUnixNanos: '654000000',
          ),
          outputPath: '/cache/thumbnails/task-2.bmp',
          durationUs: 12000000,
          maxWidth: 80,
        ),
      );
      await _pump();

      final command =
          fixture.transport.lastRequest['command']! as Map<String, Object?>;
      final payload = command['payload']! as Map<String, Object?>;
      expect(command['type'], 'generate_video_thumbnail');
      expect(payload['duration_us'], 12000000);
      expect(payload['max_width'], 80);
      expect(payload['priority'], 'background');

      fixture.transport.respond(
        requestId: 'thumbnail-1',
        kind: 'response',
        type: 'accepted',
        payload: <String, Object?>{
          ..._accepted('thumbnail-work'),
          'queue_kind': 'control',
        },
      );
      fixture.transport.respond(
        requestId: 'thumbnail-1',
        kind: 'event',
        type: 'video_thumbnail_ready',
        payload: <String, Object?>{
          'work_id': 'thumbnail-work',
          'client_task_id': 'task-2',
          'result': <String, Object?>{
            'output_path': '/cache/thumbnails/task-2.bmp',
            'requested_timestamp_us': 1440000,
            'decoded_timestamp_us': 1441000,
            'width': 80,
            'height': 45,
          },
        },
      );

      final result = await operation;
      expect(result.queueKind, EngineQueueKind.control);
      expect(result.value.outputPath, '/cache/thumbnails/task-2.bmp');
      expect(result.value.width, 80);
      expect(result.value.height, 45);
    });

    test(
      'submits execution with the engine-owned selection and output policy',
      () async {
        final fixture = await _connectedGateway(<String>[
          'hello-1',
          'submit-1',
          'shutdown-1',
        ]);
        addTearDown(fixture.dispose);
        final events = <EngineWorkEvent>[];
        final subscription = fixture.gateway.events.listen(events.add);
        addTearDown(subscription.cancel);

        final operation = fixture.gateway.submitExecution(
          const EngineExecutionRequest(
            clientTaskId: 'task-1',
            analysisId: 'analysis-1',
            expectedRevision: 3,
            selection: <String, Object?>{
              'mode': 'manual',
              'selection': <String, Object?>{
                'candidate_id': 'candidate-1',
                'overrides': <String, Object?>{'video_codec': 'h264'},
              },
            },
            requestedOutputPath: '/media/output.mp4',
            collisionPolicy: EngineOutputCollisionPolicy.generateUnique,
            priority: EngineWorkPriority.foreground,
          ),
        );
        await _pump();

        final request = fixture.transport.lastRequest;
        final command = request['command']! as Map<String, Object?>;
        final payload = command['payload']! as Map<String, Object?>;
        expect(command['type'], 'submit_execution');
        expect(payload, <String, Object?>{
          'client_task_id': 'task-1',
          'analysis_id': 'analysis-1',
          'expected_revision': 3,
          'selection': <String, Object?>{
            'mode': 'manual',
            'selection': <String, Object?>{
              'candidate_id': 'candidate-1',
              'overrides': <String, Object?>{'video_codec': 'h264'},
            },
          },
          'output': <String, Object?>{
            'requested_path': '/media/output.mp4',
            'collision_policy': 'generate_unique',
          },
          'priority': 'foreground',
        });

        fixture.transport.respond(
          requestId: 'submit-1',
          kind: 'response',
          type: 'accepted',
          payload: _accepted('work-1'),
        );
        fixture.transport.respond(
          requestId: 'submit-1',
          kind: 'event',
          type: 'work_queued',
          payload: <String, Object?>{'work_id': 'work-1', 'queue_position': 1},
        );
        fixture.transport.respond(
          requestId: 'submit-1',
          kind: 'event',
          type: 'execution_submitted',
          payload: <String, Object?>{
            'work_id': 'work-1',
            'client_task_id': 'task-1',
            'submission': <String, Object?>{
              'execution_id': 'execution-1',
              'state': 'queued',
              'queue_position': 1,
              'queue_revision': 2,
            },
          },
        );

        final result = await operation;
        await _pump();
        expect(result.workId, 'work-1');
        expect(result.value.executionId, 'execution-1');
        expect(result.value.state, EngineExecutionState.queued);
        expect(events.map((event) => event.type), [
          EngineWorkEventType.queued,
          EngineWorkEventType.executionSubmitted,
        ]);
      },
    );

    test(
      'rejects execution submissions with mismatched identity or state',
      () async {
        final malformedSubmissions = <String, Map<String, Object?>>{
          'mismatched client task': <String, Object?>{
            'execution_id': 'execution-1',
            'state': 'queued',
            '_client_task_id': 'other-task',
          },
          'empty execution id': <String, Object?>{
            'execution_id': '',
            'state': 'queued',
            '_client_task_id': 'task-1',
          },
          'unknown state': <String, Object?>{
            'execution_id': 'execution-1',
            'state': 'not_a_state',
            '_client_task_id': 'task-1',
          },
        };

        for (final entry in malformedSubmissions.entries) {
          final fixture = await _connectedGateway(<String>[
            'hello-1',
            'submit-1',
            'shutdown-1',
          ]);
          addTearDown(fixture.dispose);

          final operation = fixture.gateway.submitExecution(
            _executionRequest(),
          );
          await _pump();
          fixture.transport.respond(
            requestId: 'submit-1',
            kind: 'response',
            type: 'accepted',
            payload: _accepted('work-1'),
          );
          final submission = Map<String, Object?>.from(entry.value)
            ..remove('_client_task_id');
          fixture.transport.respond(
            requestId: 'submit-1',
            kind: 'event',
            type: 'execution_submitted',
            payload: <String, Object?>{
              'work_id': 'work-1',
              'client_task_id': entry.value['_client_task_id'] ?? 'task-1',
              'submission': submission,
            },
          );

          await expectLater(
            operation,
            throwsA(
              isA<EngineGatewayException>()
                  .having(
                    (error) => error.kind,
                    'failure kind',
                    EngineGatewayFailureKind.protocol,
                  )
                  .having((error) => error.requestId, 'request id', 'submit-1'),
            ),
            reason: entry.key,
          );
        }
      },
    );

    test('preserves a worker rejection as EngineWorkerException', () async {
      final fixture = await _connectedGateway(<String>[
        'hello-1',
        'submit-1',
        'shutdown-1',
      ]);
      addTearDown(fixture.dispose);

      final operation = fixture.gateway.submitExecution(_executionRequest());
      await _pump();
      fixture.transport.respond(
        requestId: 'submit-1',
        kind: 'response',
        type: 'accepted',
        payload: _accepted('work-1'),
      );
      final expectation = expectLater(
        operation,
        throwsA(
          isA<EngineWorkerException>()
              .having((error) => error.code, 'worker code', 'RUNTIME_FAILURE')
              .having(
                (error) => error.engineCode,
                'engine code',
                'ENGINE_EXECUTION_CHAIN_NOT_READY',
              )
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
      );
      fixture.transport.respond(
        requestId: 'submit-1',
        kind: 'event',
        type: 'work_failed',
        payload: <String, Object?>{
          'work_id': 'work-1',
          'error': <String, Object?>{
            'code': 'RUNTIME_FAILURE',
            'engine_code': 'ENGINE_EXECUTION_CHAIN_NOT_READY',
            'message': 'media execution pipeline is not ready',
            'retryable': false,
          },
        },
      );
      await expectation;
    });
  });
}

Future<_GatewayFixture> _connectedGateway(List<String> requestIds) async {
  final transport = _GatewayFakeTransport();
  final ids = Queue<String>.of(requestIds);
  final gateway = LocalFEngineGateway(
    executablePath: '/unused/framelean-engine',
    snapshotDirectory: '/unused/snapshots',
    clientVersion: '1.3.0',
    launchTransport:
        ({required executablePath, required snapshotDirectory}) async {
          expect(executablePath, '/unused/framelean-engine');
          expect(snapshotDirectory, '/unused/snapshots');
          return transport;
        },
    createRequestId: ids.removeFirst,
  );
  final connection = gateway.connect();
  await _pump();
  expect(
    (transport.lastRequest['command']! as Map<String, Object?>)['type'],
    'hello',
  );
  transport.respond(
    requestId: 'hello-1',
    kind: 'response',
    type: 'hello',
    payload: <String, Object?>{
      'negotiated_protocol_version': 1,
      'engine_version': '0.1.0',
      'heartbeat_timeout_ms': 15000,
      'resumed': false,
    },
  );
  expect((await connection).sessionId, 'session-1');
  return _GatewayFixture(gateway, transport);
}

final class _GatewayFixture {
  const _GatewayFixture(this.gateway, this.transport);

  final LocalFEngineGateway gateway;
  final _GatewayFakeTransport transport;

  Future<void> dispose() async {
    transport.autoCompleteShutdown = true;
    await gateway.close();
    await transport.dispose();
  }
}

final class _GatewayFakeTransport implements FEngineTransport {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final Completer<int> _exitCompleter = Completer<int>();
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
  int _nextSequence = 1;
  bool autoCompleteShutdown = false;

  Map<String, Object?> get lastRequest => requests.last;

  @override
  Stream<List<int>> get stdoutBytes => _stdoutController.stream;

  @override
  Stream<List<int>> get stderrBytes => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  Future<void> write(Uint8List bytes) async {
    final decoder = FEngineFrameDecoder();
    final request = decoder.add(bytes).single;
    decoder.close();
    requests.add(request);

    final command = request['command']! as Map<String, Object?>;
    if (autoCompleteShutdown && command['type'] == 'shutdown') {
      scheduleMicrotask(() {
        final requestId = request['request_id']! as String;
        respond(
          requestId: requestId,
          kind: 'response',
          type: 'shutdown_accepted',
        );
        respond(requestId: requestId, kind: 'event', type: 'shutdown_complete');
        completeExit(0);
      });
    }
  }

  @override
  Future<void> closeInput() async {}

  @override
  bool terminate() {
    completeExit(-15);
    return true;
  }

  void respond({
    required String requestId,
    required String kind,
    required String type,
    Map<String, Object?>? payload,
  }) {
    final outputPayload = <String, Object?>{'type': type};
    if (payload != null) {
      outputPayload['payload'] = payload;
    }
    _stdoutController.add(
      FEngineFrameCodec.encode(<String, Object?>{
        'protocol_version': 1,
        'session_id': 'session-1',
        'sequence': _nextSequence++,
        'request_id': requestId,
        'output': <String, Object?>{'kind': kind, 'payload': outputPayload},
      }),
    );
  }

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

Map<String, Object?> _analysisResponse() {
  return <String, Object?>{
    'schema_version': 'framelean.analyze-media.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 1,
    'task_mode': 'video_compress',
    'media_analysis_status': 'complete',
    'configuration_status': 'unavailable',
    'media': <String, Object?>{},
    'source_fingerprint': <String, Object?>{},
    'requirements': <String, Object?>{},
    'environment_summary': <String, Object?>{},
    'engine_backend_summary': <String, Object?>{},
    'capabilities': <String, Object?>{},
    'configuration_options': <String, Object?>{},
    'recommendation': <String, Object?>{},
    'presets': <Object?>[],
    'custom_target_size': <String, Object?>{},
    'warnings': <Object?>[],
    'error': null,
  };
}

Map<String, Object?> _failedAnalysisResponse() {
  return <String, Object?>{
    'schema_version': 'framelean.analyze-media.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 1,
    'task_mode': 'video_compress',
    'media_analysis_status': 'failed',
    'configuration_status': 'not_evaluated',
    'media': null,
    'source_fingerprint': null,
    'requirements': null,
    'environment_summary': null,
    'engine_backend_summary': null,
    'capabilities': null,
    'configuration_options': null,
    'recommendation': null,
    'presets': <Object?>[],
    'custom_target_size': null,
    'warnings': <Object?>[],
    'error': <String, Object?>{
      'code': 'MEDIA_INVALID_FORMAT',
      'message': 'invalid input',
      'retryable': false,
    },
  };
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

EngineExecutionRequest _executionRequest() {
  return const EngineExecutionRequest(
    clientTaskId: 'task-1',
    analysisId: 'analysis-1',
    expectedRevision: 1,
    selection: <String, Object?>{
      'mode': 'preset',
      'selection': <String, Object?>{
        'preset_id': 'balanced',
        'candidate_id': 'candidate-1',
        'overrides': <String, Object?>{},
      },
    },
    requestedOutputPath: '/media/output.mp4',
    collisionPolicy: EngineOutputCollisionPolicy.failIfExists,
  );
}
