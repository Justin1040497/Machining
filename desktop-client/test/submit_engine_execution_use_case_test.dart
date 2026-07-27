import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/use_cases/media_tasks/submit_engine_execution_use_case.dart';
import 'package:framelean/domain/library.dart';

void main() {
  group('SubmitEngineExecutionUseCase', () {
    test(
      'submits the persisted FLL selection without legacy config fallback',
      () async {
        final task = _readyTask();
        final repository = _MemoryMediaTaskRepository([task]);
        final gateway = _FakeEngineGateway(
          onSubmit: (request) async => _submissionOperation(),
        );
        final useCase = _useCase(
          repository: repository,
          gateway: gateway,
          task: task,
        );

        final result = await useCase(task.id);

        expect(result.outcome, EngineExecutionDispatchOutcome.submitted);
        expect(gateway.requests, hasLength(1));
        final request = gateway.requests.single;
        expect(request.clientTaskId, task.id);
        expect(request.analysisId, 'analysis-1');
        expect(request.expectedRevision, 4);
        expect(request.selection['mode'], 'manual');
        expect(
          (request.selection['selection']!
              as Map<String, Object?>)['candidate_id'],
          'candidate-1',
        );
        expect(request.requestedOutputPath, '/exports/custom-name.mp4');
        expect(
          request.collisionPolicy,
          EngineOutputCollisionPolicy.generateUnique,
        );
        expect(request.requestId, isNotEmpty);
        expect(repository.taskById(task.id).status, TaskStatus.executionQueued);
        expect(repository.taskById(task.id).outputPath, isNull);
      },
    );

    test('default output name cannot overwrite the source filename', () async {
      final baseTask = _readyTask();
      final task = baseTask.copyWith(
        config: baseTask.config.copyWith(outputFileName: ''),
      );
      final repository = _MemoryMediaTaskRepository([task]);
      final gateway = _FakeEngineGateway(
        onSubmit: (request) async => _submissionOperation(),
      );
      final useCase = _useCase(
        repository: repository,
        gateway: gateway,
        task: task,
      );

      final result = await useCase(task.id);

      expect(result.outcome, EngineExecutionDispatchOutcome.submitted);
      expect(
        gateway.requests.single.requestedOutputPath,
        '/exports/input_compressed.mp4',
      );
      expect(
        gateway.requests.single.requestedOutputPath,
        isNot('/exports/input.mp4'),
      );
    });

    test(
      'reuses the persisted request id after an unknown connection result',
      () async {
        final task = _readyTask();
        final repository = _MemoryMediaTaskRepository(<MediaTask>[task]);
        var attempts = 0;
        final gateway = _FakeEngineGateway(
          onSubmit: (_) async {
            attempts += 1;
            if (attempts == 1) {
              throw const EngineGatewayException(
                kind: EngineGatewayFailureKind.connection,
                message: 'connection closed before acknowledgement',
              );
            }
            return _submissionOperation();
          },
        );
        final useCase = _useCase(
          repository: repository,
          gateway: gateway,
          task: task,
        );

        final first = await useCase(task.id);
        await repository.saveTask(
          repository.taskById(task.id).markPendingForRetry(),
        );
        final second = await useCase(task.id);

        expect(first.outcome, EngineExecutionDispatchOutcome.failed);
        expect(second.outcome, EngineExecutionDispatchOutcome.submitted);
        expect(gateway.requests, hasLength(2));
        expect(gateway.requests.first.requestId, isNotEmpty);
        expect(
          gateway.requests.last.requestId,
          gateway.requests.first.requestId,
        );
      },
    );

    test(
      'projects the not-ready FLL boundary as a non-retryable failure',
      () async {
        final task = _readyTask();
        final repository = _MemoryMediaTaskRepository([task]);
        final notified = <MediaTask>[];
        final gateway = _FakeEngineGateway(
          onSubmit: (_) async => throw const EngineWorkerException(
            code: 'RUNTIME_FAILURE',
            engineCode: 'ENGINE_EXECUTION_CHAIN_NOT_READY',
            retryable: false,
            message: 'media execution pipeline is not ready',
            requestId: 'request-1',
          ),
        );
        final useCase = _useCase(
          repository: repository,
          gateway: gateway,
          task: task,
          onTaskFailed: notified.add,
        );

        final result = await useCase(task.id);

        expect(result.outcome, EngineExecutionDispatchOutcome.failed);
        final failed = repository.taskById(task.id);
        expect(failed.status, TaskStatus.failed);
        expect(
          failed.failure?.code,
          TaskFailureCode.engineExecutionUnavailable,
        );
        expect(failed.failure?.stage, TaskFailureStage.processStart);
        expect(failed.failure?.retryable, isFalse);
        expect(failed.failure?.recoveryAction, TaskRecoveryAction.none);
        expect(failed.outputPath, isNull);
        expect(failed.progress, 0);
        expect(notified.single.id, task.id);
      },
    );

    test(
      'does not overwrite a newer output configuration with stale failure',
      () async {
        final task = _readyTask();
        final repository = _MemoryMediaTaskRepository([task]);
        final gateway = _FakeEngineGateway(
          onSubmit: (_) async {
            await repository.saveTask(
              task.copyWith(
                config: task.config.copyWith(outputFileName: 'new-name'),
              ),
            );
            throw const EngineWorkerException(
              code: 'RUNTIME_FAILURE',
              engineCode: 'ENGINE_EXECUTION_CHAIN_NOT_READY',
              retryable: false,
              message: 'media execution pipeline is not ready',
              requestId: 'request-1',
            );
          },
        );
        final useCase = _useCase(
          repository: repository,
          gateway: gateway,
          task: task,
        );

        final result = await useCase(task.id);

        expect(result.outcome, EngineExecutionDispatchOutcome.stale);
        final latest = repository.taskById(task.id);
        expect(latest.status, TaskStatus.pending);
        expect(latest.config.outputFileName, 'new-name');
        expect(latest.failure, isNull);
      },
    );

    test(
      'forwards an opaque selection to FEngine without Client semantic validation',
      () async {
        final task = _readyTask(
          selectionJson: '{"mode":"manual","selection":null}',
        );
        final repository = _MemoryMediaTaskRepository([task]);
        final gateway = _FakeEngineGateway(
          onSubmit: (_) async => _submissionOperation(),
        );
        final useCase = _useCase(
          repository: repository,
          gateway: gateway,
          task: task,
        );

        final result = await useCase(task.id);

        expect(result.outcome, EngineExecutionDispatchOutcome.submitted);
        expect(gateway.requests, hasLength(1));
        expect(gateway.requests.single.selection, <String, Object?>{
          'mode': 'manual',
          'selection': null,
        });
      },
    );

    test('submits ready tasks through one atomic Engine batch', () async {
      final first = _readyTask(id: 'task-1');
      final second = _readyTask(id: 'task-2');
      final repository = _MemoryMediaTaskRepository(<MediaTask>[first, second]);
      final projections = _MemoryProjectionRepository.many(
        <EngineAnalysisProjection>[
          _projection(first.id),
          _projection(second.id),
        ],
      );
      final gateway = _FakeEngineGateway(
        onSubmit: (_) async => _submissionOperation(),
        onBatch: (requests) async => EngineOperationResult(
          sessionId: 'session-1',
          requestId: 'batch-1',
          workId: 'work-1',
          sequence: 8,
          value: EngineBatchSubmission(
            items: <EngineBatchSubmissionItem>[
              for (var index = 0; index < requests.length; index += 1)
                EngineBatchSubmissionItem(
                  clientTaskId: requests[index].clientTaskId,
                  childRequestId: 'batch-child:work-${index + 1}',
                  workId: 'work-${index + 1}',
                  queueKind: EngineQueueKind.control,
                  queuePosition: index + 1,
                  queueRevision: index + 1,
                ),
            ],
          ),
        ),
      );
      final useCase = SubmitEngineExecutionUseCase(
        repository: repository,
        analysisProjectionRepository: projections,
        settingsRepository: _MemorySettingsRepository(AppSettings.initial()),
        readEngineGateway: () async => gateway,
        nowMilliseconds: () => 123,
      );

      final results = await useCase.submitBatch(<String>[first.id, second.id]);

      expect(
        results.map((result) => result.outcome),
        everyElement(EngineExecutionDispatchOutcome.submitted),
      );
      expect(gateway.requests, isEmpty);
      expect(gateway.batchRequests, hasLength(1));
      expect(
        gateway.batchRequests.single.map((request) => request.clientTaskId),
        <String>['task-1', 'task-2'],
      );
      expect(repository.taskById(first.id).status, TaskStatus.executionQueued);
      expect(repository.taskById(second.id).status, TaskStatus.executionQueued);
      expect(
        (await projections.loadByTaskId(second.id))!.executionRequestId,
        'batch-child:work-2',
      );
    });
  });
}

SubmitEngineExecutionUseCase _useCase({
  required _MemoryMediaTaskRepository repository,
  required _FakeEngineGateway gateway,
  required MediaTask task,
  void Function(MediaTask task)? onTaskFailed,
}) {
  return SubmitEngineExecutionUseCase(
    repository: repository,
    analysisProjectionRepository: _MemoryProjectionRepository(
      _projection(task.id),
    ),
    settingsRepository: _MemorySettingsRepository(AppSettings.initial()),
    readEngineGateway: () async => gateway,
    onTaskFailed: onTaskFailed == null
        ? null
        : (task) async {
            onTaskFailed(task);
          },
    nowMilliseconds: () => 123,
  );
}

MediaTask _readyTask({String id = 'task-1', String? selectionJson}) {
  return MediaTask(
    id: id,
    inputPath: '/sources/input.mp4',
    fileName: 'input.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: MediaTaskConfig.initialVideo().copyWith(
      outputLocationMode: OutputLocationMode.custom,
      outputDirectory: '/exports',
      outputFileName: 'custom-name',
      engineConfiguration: EngineConfigurationReference(
        analysisId: 'analysis-1',
        analysisRevision: 4,
        candidateId: 'candidate-1',
        selectionMode: 'manual',
        selectionJson:
            selectionJson ??
            jsonEncode(<String, Object?>{
              'mode': 'manual',
              'selection': <String, Object?>{
                'candidate_id': 'candidate-1',
                'overrides': <String, Object?>{},
              },
            }),
      ),
    ),
    progress: 0,
    sortOrder: 0,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: MediaAnalysisResult(durationMs: 1000),
    analysisUpdatedAt: 1,
    createdAt: 1,
  );
}

EngineAnalysisProjection _projection(String taskId) {
  return EngineAnalysisProjection(
    taskId: taskId,
    clientFileId: taskId,
    engineSessionId: 'session-1',
    analysisId: 'analysis-1',
    revision: 4,
    schemaVersion: 'framelean.analysis-snapshot.v1',
    snapshotJson: jsonEncode(_snapshot()),
    validityStatus: 'valid',
    lastEventSequence: 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
}

Map<String, Object?> _snapshot() {
  final candidate = _candidate();
  final configuration = _configuration();
  final estimate = <String, Object?>{
    'expected_bytes': 100,
    'minimum_bytes': 80,
    'maximum_bytes': 120,
    'confidence': 'low',
    'basis': <Object?>['baseline'],
  };
  return <String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 4,
    'decision_model_revision': 1,
    'estimator_model_revision': 1,
    'task_mode': 'video_compress',
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
      'reasons': <Object?>[],
      'estimate': estimate,
      'resource_sample_unix_ms': 1,
    },
    'presets': <Object?>[],
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
      'status': 'valid',
      'reason_code': null,
      'message': null,
    },
  };
}

Map<String, Object?> _candidate() {
  return <String, Object?>{
    'id': 'candidate-1',
    'demuxer': 'demuxer-1',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'processors': <Object?>[],
    'video_encoder': 'video-encoder-1',
    'audio_encoder': 'audio-encoder-1',
    'muxer': 'muxer-1',
    'output_container': 'mp4',
    'output_video_codec': 'h264',
    'output_video_profile': null,
    'output_audio_codec': 'aac',
    'output_pixel_format': 'yuv420p',
    'output_bit_depth': 8,
    'output_hdr_mode': 'sdr',
    'preserves_hdr': false,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _configuration() {
  return <String, Object?>{
    'selection_source': 'manual',
    'selected_preset': null,
    'execution_chain_id': 'candidate-1',
    'container': 'mp4',
    'video_codec': 'h264',
    'video_profile': null,
    'audio_codec': 'aac',
    'demuxer_backend': 'demuxer-1',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'video_encoder_backend': 'video-encoder-1',
    'audio_encoder_backend': 'audio-encoder-1',
    'processors': <Object?>[],
    'muxer_backend': 'muxer-1',
    'output_pixel_format': 'yuv420p',
    'output_bit_depth': 8,
    'output_hdr_mode': 'sdr',
    'target_size': null,
    'target_video_bitrate': null,
    'target_audio_bitrate': null,
    'preserves_hdr': false,
    'requires_tone_mapping': false,
  };
}

EngineOperationResult<EngineExecutionSubmission> _submissionOperation() {
  return const EngineOperationResult(
    sessionId: 'session-1',
    requestId: 'request-1',
    workId: 'work-1',
    sequence: 1,
    value: EngineExecutionSubmission(
      executionId: 'execution-1',
      state: EngineExecutionState.queued,
    ),
  );
}

final class _FakeEngineGateway implements EngineBatchGateway {
  _FakeEngineGateway({required this.onSubmit, this.onBatch});

  final Future<EngineOperationResult<EngineExecutionSubmission>> Function(
    EngineExecutionRequest request,
  )
  onSubmit;
  final List<EngineExecutionRequest> requests = [];
  final Future<EngineOperationResult<EngineBatchSubmission>> Function(
    List<EngineExecutionRequest> requests,
  )?
  onBatch;
  final List<List<EngineExecutionRequest>> batchRequests = [];

  @override
  Stream<EngineWorkEvent> get events => const Stream.empty();

  @override
  Future<EngineOperationResult<EngineExecutionSubmission>> submitExecution(
    EngineExecutionRequest request,
  ) {
    requests.add(request);
    return onSubmit(request);
  }

  @override
  Future<EngineOperationResult<EngineBatchSubmission>> submitExecutionBatch(
    List<EngineExecutionRequest> requests,
  ) {
    batchRequests.add(List<EngineExecutionRequest>.of(requests));
    final handler = onBatch;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(requests);
  }

  @override
  Future<EngineOperationResult<EngineAnalysisCompletionDocument>> analyze(
    EngineAnalysisRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}

  @override
  Future<EngineConnectionInfo> connect() {
    throw UnimplementedError();
  }

  @override
  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>>
  getAnalysisSnapshot(
    String analysisId, {
    EngineWorkPriority priority = EngineWorkPriority.foreground,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> ping() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemoryProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _MemoryProjectionRepository(EngineAnalysisProjection projection)
    : values = <String, EngineAnalysisProjection>{
        projection.taskId: projection,
      };

  _MemoryProjectionRepository.many(Iterable<EngineAnalysisProjection> values)
    : values = <String, EngineAnalysisProjection>{
        for (final projection in values) projection.taskId: projection,
      };

  final Map<String, EngineAnalysisProjection> values;

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<void> deleteByTaskId(String taskId) async {
    values.remove(taskId);
  }

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    return values[taskId];
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    values[projection.taskId] = projection;
  }
}

final class _MemorySettingsRepository implements AppSettingsRepository {
  _MemorySettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}

final class _MemoryMediaTaskRepository implements MediaTaskRepository {
  _MemoryMediaTaskRepository(List<MediaTask> tasks)
    : tasks = <String, MediaTask>{for (final task in tasks) task.id: task};

  final Map<String, MediaTask> tasks;

  MediaTask taskById(String id) => tasks[id]!;

  @override
  Future<void> deleteTaskById(String taskId) async => tasks.remove(taskId);

  @override
  Future<void> insertTasks(List<MediaTask> newTasks) async {
    for (final task in newTasks) {
      tasks[task.id] = task;
    }
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async => tasks.values.toList();

  @override
  Future<MediaTask?> loadTaskById(String taskId) async => tasks[taskId];

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    return [for (final taskId in taskIds) ?tasks[taskId]];
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    this.tasks
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.id, task)));
  }

  @override
  Future<void> saveTask(MediaTask task) async => tasks[task.id] = task;

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {}

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {}
}
