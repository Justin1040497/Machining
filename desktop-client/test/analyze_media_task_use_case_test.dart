import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/use_cases/media_tasks/analyze_media_task_use_case.dart';
import 'package:framelean/domain/library.dart';

void main() {
  group('AnalyzeMediaTaskUseCase', () {
    test(
      'persists runtime unavailable when the engine gateway cannot load',
      () async {
        final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
        final projectionRepository = _FakeAnalysisProjectionRepository();
        final now = DateTime.fromMillisecondsSinceEpoch(1234);
        final useCase = AnalyzeMediaTaskUseCase(
          repository: repository,
          analysisProjectionRepository: projectionRepository,
          readEngineGateway: () async {
            throw StateError('FrameLean Engine executable is not installed');
          },
          now: () => now,
        );

        final result = await useCase.call('task-1');

        expect(repository.savedStatuses, [TaskStatus.analysisFailed]);
        expect(result?.status, TaskStatus.analysisFailed);
        expect(result?.failure?.stage, TaskFailureStage.analysis);
        expect(
          result?.failure?.code,
          TaskFailureCode.analysisRuntimeUnavailable,
        );
        expect(result?.failure?.retryable, isTrue);
        expect(result?.failure?.occurredAt, now.millisecondsSinceEpoch);
        expect(
          result?.failure?.technicalSummary,
          contains('FrameLean Engine executable is not installed'),
        );
        expect(projectionRepository.deleteByTaskIdCallCount, 0);
      },
    );

    test('commits a new snapshot and saves its engine projection', () async {
      final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
      final projectionRepository = _FakeAnalysisProjectionRepository();
      final gateway = _FakeEngineGateway(
        analysisResults: [
          _operation(
            _analysisResponse(),
            requestId: 'analyze-request',
            sequence: 10,
          ),
        ],
        snapshotResults: [
          _operation(_snapshot(), requestId: 'snapshot-request', sequence: 11),
        ],
      );

      final result = await _useCase(
        repository,
        projectionRepository,
        gateway,
      ).call('task-1');

      expect(result?.status, TaskStatus.pending);
      expect(result?.analysisResult, isNotNull);
      expect(gateway.analyzeRequests, hasLength(1));
      expect(gateway.snapshotRequests, isEmpty);
      expect(projectionRepository.upserts, isNotEmpty);
      final projection = projectionRepository.upserts.last;
      expect(projection.engineSessionId, 'session-1');
      expect(projection.analysisId, 'analysis-1');
      expect(projection.revision, 1);
      expect(projection.lastEventSequence, 10);
      expect(repository.savedStatuses, [TaskStatus.ready]);
    });

    test(
      'clears a stale configuration before committing a new analysis',
      () async {
        final repository = _FakeMediaTaskRepository(
          _awaitingAnalysisTask(
            engineConfiguration: _engineReference(analysisId: 'analysis-old'),
          ),
        );
        final projectionRepository = _FakeAnalysisProjectionRepository();
        final gateway = _FakeEngineGateway(
          analysisResults: [_operation(_analysisResponse())],
          snapshotResults: [_operation(_snapshot())],
        );

        final result = await _useCase(
          repository,
          projectionRepository,
          gateway,
        ).call('task-1');

        expect(result?.config.engineConfiguration, isNull);
        expect(repository.savedStatuses, [
          TaskStatus.awaitAnalysis,
          TaskStatus.ready,
        ]);
      },
    );

    test(
      'reuses a valid projection without submitting a new analysis',
      () async {
        final reference = _engineReference();
        final repository = _FakeMediaTaskRepository(
          _awaitingAnalysisTask(engineConfiguration: reference),
        );
        final projectionRepository = _FakeAnalysisProjectionRepository(
          projection: _projection(),
        );
        final gateway = _FakeEngineGateway(
          analysisResults: const [],
          snapshotResults: [
            _operation(
              _snapshot(),
              requestId: 'snapshot-request',
              sequence: 20,
            ),
          ],
        );

        final result = await _useCase(
          repository,
          projectionRepository,
          gateway,
        ).call('task-1');

        expect(result?.status, TaskStatus.pending);
        expect(gateway.analyzeRequests, isEmpty);
        expect(gateway.snapshotRequests, ['analysis-1']);
        expect(projectionRepository.deleteByTaskIdCallCount, 0);
        expect(projectionRepository.upserts, hasLength(1));
        expect(projectionRepository.upserts.single.lastEventSequence, 20);
        expect(result?.config.engineConfiguration, same(reference));
      },
    );

    test('re-analyzes after an invalid reusable snapshot', () async {
      final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
      final projectionRepository = _FakeAnalysisProjectionRepository(
        projection: _projection(),
      );
      final gateway = _FakeEngineGateway(
        analysisResults: [_operation(_analysisResponse(), sequence: 30)],
        snapshotResults: [
          _operation(
            _snapshot(validity: EngineSnapshotValidityStatus.invalid),
            sequence: 29,
          ),
          _operation(_snapshot(), sequence: 31),
        ],
      );

      final result = await _useCase(
        repository,
        projectionRepository,
        gateway,
      ).call('task-1');

      expect(result?.status, TaskStatus.pending);
      expect(gateway.analyzeRequests, hasLength(1));
      expect(gateway.snapshotRequests, ['analysis-1']);
      expect(projectionRepository.deleteByTaskIdCallCount, 1);
      expect(projectionRepository.upserts.length, greaterThanOrEqualTo(2));
      expect(projectionRepository.upserts.first.validityStatus, 'invalid');
      expect(projectionRepository.upserts.last.validityStatus, 'valid');
    });

    test('re-analyzes after the engine reports an expired snapshot', () async {
      final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
      final projectionRepository = _FakeAnalysisProjectionRepository(
        projection: _projection(),
      );
      final gateway = _FakeEngineGateway(
        analysisResults: [_operation(_analysisResponse(), sequence: 40)],
        snapshotResults: [
          const EngineWorkerException(
            code: 'ANALYSIS_SNAPSHOT_EXPIRED',
            engineCode: 'ANALYSIS_SNAPSHOT_EXPIRED',
            retryable: true,
            message: 'snapshot expired',
            requestId: 'snapshot-request-old',
          ),
          _operation(_snapshot(), sequence: 41),
        ],
      );

      final result = await _useCase(
        repository,
        projectionRepository,
        gateway,
      ).call('task-1');

      expect(result?.status, TaskStatus.pending);
      expect(gateway.analyzeRequests, hasLength(1));
      expect(gateway.snapshotRequests, ['analysis-1']);
      expect(
        projectionRepository.deleteByTaskIdCallCount,
        greaterThanOrEqualTo(1),
      );
      expect(projectionRepository.upserts, isNotEmpty);
      expect(projectionRepository.upserts.last.validityStatus, 'valid');
    });

    test('maps a failed FLL analysis result to task failure', () async {
      final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
      final projectionRepository = _FakeAnalysisProjectionRepository();
      final gateway = _FakeEngineGateway(
        analysisResults: [
          _operation(
            _analysisResponse(
              status: EngineMediaAnalysisStatus.failed,
              errorCode: 'MEDIA_INVALID_FORMAT',
              errorMessage: 'cannot decode input',
              errorRetryable: false,
            ),
            sequence: 50,
          ),
        ],
        snapshotResults: const [],
      );

      final result = await _useCase(
        repository,
        projectionRepository,
        gateway,
      ).call('task-1');

      expect(result?.status, TaskStatus.analysisFailed);
      expect(result?.failure?.code, TaskFailureCode.corruptMedia);
      expect(result?.failure?.stage, TaskFailureStage.analysis);
      expect(result?.failure?.retryable, isFalse);
      expect(result?.failure?.userMessage, '文件格式无效或文件已经损坏。');
      expect(gateway.snapshotRequests, isEmpty);
      expect(projectionRepository.upserts, isNotEmpty);
    });

    test('commits a partial analysis when it includes a snapshot', () async {
      final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
      final projectionRepository = _FakeAnalysisProjectionRepository();
      final gateway = _FakeEngineGateway(
        analysisResults: [
          _operation(
            _analysisResponse(status: EngineMediaAnalysisStatus.partial),
            sequence: 60,
          ),
        ],
        snapshotResults: [_operation(_snapshot(), sequence: 61)],
      );

      final result = await _useCase(
        repository,
        projectionRepository,
        gateway,
      ).call('task-1');

      expect(result?.status, TaskStatus.pending);
      expect(result?.analysisResult, isNotNull);
      expect(gateway.analyzeRequests, hasLength(1));
      expect(gateway.snapshotRequests, isEmpty);
      expect(projectionRepository.upserts, isNotEmpty);
      expect(projectionRepository.upserts.last.validityStatus, 'valid');
    });

    test(
      'fails without saving a projection when response and snapshot identities differ',
      () async {
        final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
        final projectionRepository = _FakeAnalysisProjectionRepository();
        final gateway = _FakeEngineGateway(
          analysisResults: [_operation(_analysisResponse(), sequence: 70)],
          snapshotResults: [
            _operation(_snapshot(analysisId: 'analysis-other'), sequence: 71),
          ],
        );

        final result = await _useCase(
          repository,
          projectionRepository,
          gateway,
        ).call('task-1');

        expect(result?.status, TaskStatus.analysisFailed);
        expect(result?.failure?.code, TaskFailureCode.analysisFailed);
        expect(result?.failure?.stage, TaskFailureStage.analysis);
        expect(projectionRepository.upserts, isNotEmpty);
        expect(projectionRepository.upserts.last.snapshotJson, isNull);
      },
    );

    test(
      'does not commit a result after the source task is replaced',
      () async {
        final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
        repository.replacementOnSecondLoad = _awaitingAnalysisTask(
          inputPath: '/videos/replacement.mp4',
          fileSize: 2048,
        );
        final projectionRepository = _FakeAnalysisProjectionRepository();
        final gateway = _FakeEngineGateway(
          analysisResults: [_operation(_analysisResponse(), sequence: 80)],
          snapshotResults: [_operation(_snapshot(), sequence: 81)],
        );

        final result = await _useCase(
          repository,
          projectionRepository,
          gateway,
        ).call('task-1');

        expect(result?.inputPath, '/videos/replacement.mp4');
        expect(result?.status, TaskStatus.awaitingAnalysis);
        expect(projectionRepository.projection, isNull);
        expect(projectionRepository.deleteByTaskIdCallCount, 2);
        expect(repository.savedStatuses, isEmpty);
      },
    );

    test(
      'does not mark a replacement task failed when an old analysis fails',
      () async {
        final repository = _FakeMediaTaskRepository(_awaitingAnalysisTask());
        repository.replacementOnSecondLoad = _awaitingAnalysisTask(
          inputPath: '/videos/replacement.mp4',
          fileSize: 2048,
        );
        final projectionRepository = _FakeAnalysisProjectionRepository();
        final gateway = _FakeEngineGateway(
          analysisResults: [
            _operation(
              _analysisResponse(
                status: EngineMediaAnalysisStatus.failed,
                errorCode: 'MEDIA_INVALID_FORMAT',
                errorMessage: 'cannot decode input',
                errorRetryable: false,
              ),
              sequence: 90,
            ),
          ],
          snapshotResults: const [],
        );

        final result = await _useCase(
          repository,
          projectionRepository,
          gateway,
        ).call('task-1');

        expect(result?.inputPath, '/videos/replacement.mp4');
        expect(result?.status, TaskStatus.awaitingAnalysis);
        expect(result?.failure, isNull);
        expect(repository.savedStatuses, isEmpty);
      },
    );
  });
}

AnalyzeMediaTaskUseCase _useCase(
  _FakeMediaTaskRepository repository,
  _FakeAnalysisProjectionRepository projectionRepository,
  _FakeEngineGateway gateway,
) {
  return AnalyzeMediaTaskUseCase(
    repository: repository,
    analysisProjectionRepository: projectionRepository,
    readEngineGateway: () async => gateway,
    now: () => DateTime.fromMillisecondsSinceEpoch(1234),
  );
}

MediaTask _awaitingAnalysisTask({
  String id = 'task-1',
  String inputPath = '/videos/input.mp4',
  int fileSize = 1024,
  EngineConfigurationReference? engineConfiguration,
}) {
  return MediaTask(
    id: id,
    inputPath: inputPath,
    fileName: inputPath.split('/').last,
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.awaitingAnalysis,
    config: MediaTaskConfig.initialVideo().copyWith(
      engineConfiguration: engineConfiguration,
    ),
    progress: 0,
    sortOrder: 0,
    sourceFileFingerprint: SourceFileFingerprint(
      fileSize: fileSize,
      lastModifiedAt: 123,
    ),
    createdAt: 1,
  );
}

EngineConfigurationReference _engineReference({
  String analysisId = 'analysis-1',
}) {
  return EngineConfigurationReference(
    analysisId: analysisId,
    analysisRevision: 1,
    candidateId: 'candidate-1',
    selectionMode: 'preset',
    selectionJson:
        '{"mode":"preset","selection":{"preset_id":"balanced","candidate_id":"candidate-1"}}',
  );
}

EngineAnalysisProjection _projection({
  String analysisId = 'analysis-1',
  int revision = 1,
}) {
  return EngineAnalysisProjection(
    taskId: 'task-1',
    clientFileId: 'task-1',
    engineSessionId: 'session-old',
    analysisId: analysisId,
    revision: revision,
    schemaVersion: 'framelean.analysis-snapshot.v1',
    snapshotJson: '{}',
    validityStatus: 'valid',
    lastEventSequence: 4,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );
}

EngineOperationResult<T> _operation<T>(
  T value, {
  String sessionId = 'session-1',
  String requestId = 'request-1',
  String workId = 'work-1',
  int sequence = 10,
}) {
  return EngineOperationResult<T>(
    sessionId: sessionId,
    requestId: requestId,
    workId: workId,
    sequence: sequence,
    value: value,
  );
}

EngineAnalysisResponseDocument _analysisResponse({
  EngineMediaAnalysisStatus status = EngineMediaAnalysisStatus.complete,
  String analysisId = 'analysis-1',
  int analysisRevision = 1,
  EngineTaskMode taskMode = EngineTaskMode.videoCompress,
  String? errorCode,
  String? errorMessage,
  bool? errorRetryable,
}) {
  final statusName = switch (status) {
    EngineMediaAnalysisStatus.complete => 'complete',
    EngineMediaAnalysisStatus.partial => 'partial',
    EngineMediaAnalysisStatus.failed => 'failed',
  };
  final json = <String, Object?>{
    'schema_version': 'framelean.analyze-media.v1',
    'analysis_id': analysisId,
    'analysis_revision': analysisRevision,
    'task_mode': _taskModeName(taskMode),
    'media_analysis_status': statusName,
    'configuration_status': status == EngineMediaAnalysisStatus.failed
        ? 'not_evaluated'
        : 'available',
    'presets': <Object?>[],
    'warnings': <Object?>[],
    'error': errorCode == null
        ? null
        : <String, Object?>{
            'code': errorCode,
            'message': errorMessage,
            'retryable': errorRetryable,
          },
  };
  if (status == EngineMediaAnalysisStatus.failed) {
    json.addAll({
      'media': null,
      'source_fingerprint': null,
      'requirements': null,
      'environment_summary': null,
      'engine_backend_summary': null,
      'capabilities': null,
      'configuration_options': null,
      'recommendation': null,
    });
  } else {
    json.addAll({
      'media': <String, Object?>{},
      'source_fingerprint': <String, Object?>{},
      'requirements': <String, Object?>{},
      'environment_summary': <String, Object?>{},
      'engine_backend_summary': <String, Object?>{},
      'capabilities': <String, Object?>{},
      'configuration_options': <String, Object?>{},
      'recommendation': <String, Object?>{},
    });
  }
  return EngineAnalysisResponseDocument.fromJson(json);
}

EngineAnalysisSnapshotDocument _snapshot({
  String analysisId = 'analysis-1',
  int analysisRevision = 1,
  EngineTaskMode taskMode = EngineTaskMode.videoCompress,
  EngineSnapshotValidityStatus validity = EngineSnapshotValidityStatus.valid,
}) {
  final candidate = _candidate();
  final configuration = _configuration();
  final estimate = _estimate();
  return EngineAnalysisSnapshotDocument.fromJson(<String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': analysisId,
    'analysis_revision': analysisRevision,
    'decision_model_revision': 1,
    'estimator_model_revision': 1,
    'task_mode': _taskModeName(taskMode),
    'media': <String, Object?>{},
    'source_fingerprint': <String, Object?>{},
    'requirements': <String, Object?>{},
    'environment_summary': <String, Object?>{},
    'engine_backend_summary': <String, Object?>{},
    'capabilities': <String, Object?>{
      'available': true,
      'execution_chains': <Object?>[candidate],
    },
    'configuration_options': <String, Object?>{
      'candidate_ids': <Object?>['candidate-1'],
      'containers': <Object?>[
        <String, Object?>{
          'value': 'mp4',
          'candidate_ids': <Object?>['candidate-1'],
        },
      ],
      'video_codecs': <Object?>[],
      'video_profiles': <Object?>[],
      'audio_codecs': <Object?>[],
      'video_encoders': <Object?>[],
      'audio_encoders': <Object?>[],
      'pixel_formats': <Object?>[],
      'bit_depths': <Object?>[],
      'hdr_modes': <Object?>[],
      'preserves_hdr': <Object?>[],
      'requires_tone_mapping': <Object?>[],
    },
    'recommendation': <String, Object?>{
      'status': 'complete',
      'configuration': configuration,
      'reasons': <Object?>['balanced'],
      'estimate': estimate,
    },
    'presets': <Object?>[
      <String, Object?>{
        'id': 'balanced',
        'display_name': 'Balanced',
        'description': 'Balanced output',
        'applicable': true,
        'unavailable_reason': null,
        'policy_version': 1,
        'policy': <String, Object?>{},
        'candidate': candidate,
        'configuration': configuration,
        'estimate': estimate,
        'risks': <Object?>[],
      },
    ],
    'custom_target_size': <String, Object?>{
      'available': false,
      'unavailable_reason': 'ENGINE_EXECUTION_CHAIN_NOT_READY',
      'minimum_bytes': null,
      'maximum_bytes': null,
      'default_bytes': null,
      'step_bytes': null,
      'display_unit': 'bytes',
    },
    'warnings': <Object?>[],
    'validity': <String, Object?>{
      'status': validity == EngineSnapshotValidityStatus.valid
          ? 'valid'
          : 'invalid',
      'reason_code': validity == EngineSnapshotValidityStatus.valid
          ? null
          : 'ANALYSIS_SOURCE_CHANGED',
      'message': validity == EngineSnapshotValidityStatus.valid
          ? null
          : 'source changed',
    },
  });
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

Map<String, Object?> _candidate() {
  return <String, Object?>{
    'id': 'candidate-1',
    'demuxer': 'mov',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'processors': <Object?>[],
    'muxer': 'mp4',
    'output_container': 'mp4',
    'output_hdr_mode': 'preserve',
    'preserves_hdr': false,
    'requires_tone_mapping': false,
    'video_encoder': 'libx264',
    'audio_encoder': 'aac',
    'output_video_codec': 'h264',
    'output_video_profile': null,
    'output_audio_codec': 'aac',
    'output_pixel_format': 'yuv420p',
    'output_bit_depth': 8,
  };
}

Map<String, Object?> _configuration() {
  return <String, Object?>{
    'selection_source': 'recommendation',
    'execution_chain_id': 'candidate-1',
    'container': 'mp4',
    'demuxer_backend': 'mov',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'processors': <Object?>[],
    'muxer_backend': 'mp4',
    'output_hdr_mode': 'preserve',
    'preserves_hdr': false,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _estimate() {
  return <String, Object?>{
    'expected_bytes': 800,
    'minimum_bytes': 700,
    'maximum_bytes': 900,
    'confidence': 'medium',
    'basis': <Object?>['fixture'],
  };
}

final class _FakeEngineGateway implements EngineGateway {
  _FakeEngineGateway({
    required List<EngineOperationResult<EngineAnalysisResponseDocument>>
    analysisResults,
    required List<Object> snapshotResults,
  }) : _analysisResults = [...analysisResults],
       _snapshotResults = [...snapshotResults];

  final List<EngineOperationResult<EngineAnalysisResponseDocument>>
  _analysisResults;
  final List<Object> _snapshotResults;
  final List<EngineAnalysisRequest> analyzeRequests = [];
  final List<String> snapshotRequests = [];
  final StreamController<EngineWorkEvent> _events =
      StreamController<EngineWorkEvent>.broadcast();

  @override
  Stream<EngineWorkEvent> get events => _events.stream;

  @override
  Future<EngineConnectionInfo> connect() async {
    return const EngineConnectionInfo(
      sessionId: 'session-1',
      protocolVersion: 1,
      engineVersion: 'test',
      heartbeatTimeout: Duration(seconds: 5),
      resumed: false,
    );
  }

  @override
  Future<EngineOperationResult<EngineAnalysisCompletionDocument>> analyze(
    EngineAnalysisRequest request,
  ) async {
    analyzeRequests.add(request);
    if (_analysisResults.isEmpty) {
      throw StateError('No analysis fixture available');
    }
    final result = _analysisResults.removeAt(0);
    final queuedSequence = result.sequence > 2 ? result.sequence - 2 : 1;
    _events.add(
      EngineWorkEvent(
        requestId: result.requestId,
        workId: result.workId,
        sequence: queuedSequence,
        type: EngineWorkEventType.queued,
        sessionId: result.sessionId,
        clientTaskId: request.clientTaskId,
        queueKind: EngineQueueKind.analysis,
        queuePosition: 1,
        queueRevision: 1,
      ),
    );
    _events.add(
      EngineWorkEvent(
        requestId: result.requestId,
        workId: result.workId,
        sequence: queuedSequence + 1,
        type: EngineWorkEventType.started,
        sessionId: result.sessionId,
        clientTaskId: request.clientTaskId,
        queueKind: EngineQueueKind.analysis,
        queuePosition: 0,
        queueRevision: 2,
      ),
    );
    EngineAnalysisSnapshotDocument? snapshot;
    if (result.value.hasSnapshot && _snapshotResults.isNotEmpty) {
      final snapshotResult = _snapshotResults.removeAt(0);
      if (snapshotResult
          is EngineOperationResult<EngineAnalysisSnapshotDocument>) {
        snapshot = snapshotResult.value;
      } else {
        throw snapshotResult;
      }
    }
    return EngineOperationResult(
      sessionId: result.sessionId,
      requestId: result.requestId,
      workId: result.workId,
      sequence: result.sequence,
      value: EngineAnalysisCompletionDocument(
        analysis: result.value,
        snapshot: snapshot,
      ),
      queueKind: result.queueKind,
      queuePosition: result.queuePosition,
      queueRevision: result.queueRevision,
    );
  }

  @override
  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>>
  getAnalysisSnapshot(
    String analysisId, {
    EngineWorkPriority priority = EngineWorkPriority.foreground,
  }) async {
    snapshotRequests.add(analysisId);
    if (_snapshotResults.isEmpty) {
      throw StateError('No snapshot fixture available');
    }
    final outcome = _snapshotResults.removeAt(0);
    if (outcome is EngineOperationResult<EngineAnalysisSnapshotDocument>) {
      return outcome;
    }
    throw outcome;
  }

  @override
  Future<EngineOperationResult<EngineExecutionSubmission>> submitExecution(
    EngineExecutionRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> ping() async {}

  @override
  Future<void> close() async {}
}

final class _FakeMediaTaskRepository implements MediaTaskRepository {
  _FakeMediaTaskRepository(this.task);

  MediaTask? task;
  MediaTask? replacementOnSecondLoad;
  int loadTaskByIdCallCount = 0;
  final List<TaskStatus> savedStatuses = [];

  @override
  Future<void> deleteTaskById(String taskId) async {
    if (task?.id == taskId) {
      task = null;
    }
  }

  @override
  Future<void> insertTasks(List<MediaTask> tasks) async {
    if (tasks.isNotEmpty) {
      task = tasks.last;
    }
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async {
    final current = task;
    return current == null ? const [] : [current];
  }

  @override
  Future<MediaTask?> loadTaskById(String taskId) async {
    loadTaskByIdCallCount += 1;
    if (loadTaskByIdCallCount == 2 && replacementOnSecondLoad != null) {
      task = replacementOnSecondLoad;
      replacementOnSecondLoad = null;
    }
    return task?.id == taskId ? task : null;
  }

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    final current = task;
    return current != null && taskIds.contains(current.id)
        ? [current]
        : const [];
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    task = tasks.isEmpty ? null : tasks.last;
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    this.task = task;
    savedStatuses.add(task.status);
  }

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {}

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {}
}

final class _FakeAnalysisProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _FakeAnalysisProjectionRepository({this.projection});

  EngineAnalysisProjection? projection;
  final List<EngineAnalysisProjection> upserts = [];
  int deleteByTaskIdCallCount = 0;

  @override
  Future<void> deleteAll() async {
    projection = null;
  }

  @override
  Future<void> deleteByTaskId(String taskId) async {
    deleteByTaskIdCallCount += 1;
    if (projection?.taskId == taskId) {
      projection = null;
    }
  }

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    return projection?.taskId == taskId ? projection : null;
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    this.projection = projection;
    upserts.add(projection);
  }
}
