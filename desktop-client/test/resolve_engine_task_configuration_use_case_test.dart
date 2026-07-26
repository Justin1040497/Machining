import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/use_cases/media_tasks/resolve_engine_task_configuration_use_case.dart';
import 'package:framelean/domain/library.dart';

void main() {
  group('ResolveEngineTaskConfigurationUseCase', () {
    test(
      'resolves through FEngine and persists only the selection reference',
      () async {
        final originalReference = _reference(candidateId: 'candidate-old');
        final task = _task(reference: originalReference);
        final repository = _FakeMediaTaskRepository(task);
        final projectionRepository = _FakeProjectionRepository(_projection());
        final gateway = _FakeEngineGateway(
          onResolve: (request) async => _operation(_resolution()),
        );
        final selection = EnginePresetSelection(
          presetId: 'balanced',
          candidateId: 'candidate-1',
          overrides: const EngineManualOverrides(
            videoCodec: 'h264',
            preservesHdr: true,
          ),
        );

        final result = await _useCase(repository, projectionRepository, gateway)
            .call(
              taskId: task.id,
              analysisId: 'analysis-1',
              analysisRevision: 4,
              candidateId: 'candidate-1',
              selection: selection,
            );

        expect(gateway.resolveRequests, hasLength(1));
        final request = gateway.resolveRequests.single;
        expect(request.analysisId, 'analysis-1');
        expect(request.expectedRevision, 4);
        expect(request.selection, same(selection));
        expect(repository.savedTasks, hasLength(1));
        expect(result, same(repository.savedTasks.single));
        expect(result?.config.outputFileName, 'output-name');

        final reference = result?.config.engineConfiguration;
        expect(reference?.analysisId, 'analysis-1');
        expect(reference?.analysisRevision, 4);
        expect(reference?.candidateId, 'candidate-1');
        expect(reference?.selectionMode, 'preset');
        expect(jsonDecode(reference!.selectionJson), {
          'mode': 'preset',
          'selection': {
            'preset_id': 'balanced',
            'candidate_id': 'candidate-1',
            'overrides': {'video_codec': 'h264', 'preserves_hdr': true},
          },
        });
      },
    );

    test(
      'does not overwrite the task when FLL reports no resolution',
      () async {
        final originalReference = _reference(candidateId: 'candidate-old');
        final task = _task(reference: originalReference);
        final repository = _FakeMediaTaskRepository(task);
        final gateway = _FakeEngineGateway(
          onResolve: (request) async => _operation(
            _resolution(status: 'unavailable', includeResolution: false),
          ),
        );

        await expectLater(
          _useCase(
            repository,
            _FakeProjectionRepository(_projection()),
            gateway,
          ).call(
            taskId: task.id,
            analysisId: 'analysis-1',
            analysisRevision: 4,
            candidateId: 'candidate-1',
            selection: const EngineManualConfigurationSelection(
              candidateId: 'candidate-1',
            ),
          ),
          throwsA(isA<ResolveEngineTaskConfigurationException>()),
        );

        expect(repository.savedTasks, isEmpty);
        expect(
          repository.task?.config.engineConfiguration,
          same(originalReference),
        );
      },
    );

    test('rejects a mismatched analysis response without saving', () async {
      final task = _task(reference: _reference());
      final repository = _FakeMediaTaskRepository(task);
      final gateway = _FakeEngineGateway(
        onResolve: (request) async => _operation(
          _resolution(analysisId: 'analysis-other'),
          requestId: 'resolve-request',
        ),
      );

      await expectLater(
        _useCase(
          repository,
          _FakeProjectionRepository(_projection()),
          gateway,
        ).call(
          taskId: task.id,
          analysisId: 'analysis-1',
          analysisRevision: 4,
          candidateId: 'candidate-1',
          selection: const EngineManualConfigurationSelection(
            candidateId: 'candidate-1',
          ),
        ),
        throwsA(
          isA<EngineGatewayException>()
              .having(
                (error) => error.kind,
                'kind',
                EngineGatewayFailureKind.protocol,
              )
              .having(
                (error) => error.requestId,
                'requestId',
                'resolve-request',
              ),
        ),
      );

      expect(repository.savedTasks, isEmpty);
    });

    test('rejects a mismatched resolved candidate without saving', () async {
      final task = _task(reference: _reference());
      final repository = _FakeMediaTaskRepository(task);
      final gateway = _FakeEngineGateway(
        onResolve: (request) async =>
            _operation(_resolution(candidateId: 'candidate-other')),
      );

      await expectLater(
        _useCase(
          repository,
          _FakeProjectionRepository(_projection()),
          gateway,
        ).call(
          taskId: task.id,
          analysisId: 'analysis-1',
          analysisRevision: 4,
          candidateId: 'candidate-1',
          selection: const EngineManualConfigurationSelection(
            candidateId: 'candidate-1',
          ),
        ),
        throwsA(
          isA<EngineGatewayException>().having(
            (error) => error.kind,
            'kind',
            EngineGatewayFailureKind.protocol,
          ),
        ),
      );

      expect(repository.savedTasks, isEmpty);
    });

    test(
      'does not call FEngine for a stale local analysis projection',
      () async {
        final task = _task(reference: _reference());
        final repository = _FakeMediaTaskRepository(task);
        final gateway = _FakeEngineGateway(
          onResolve: (request) async => _operation(_resolution()),
        );

        await expectLater(
          _useCase(
            repository,
            _FakeProjectionRepository(_projection(analysisId: 'analysis-new')),
            gateway,
          ).call(
            taskId: task.id,
            analysisId: 'analysis-1',
            analysisRevision: 4,
            candidateId: 'candidate-1',
            selection: const EngineManualConfigurationSelection(
              candidateId: 'candidate-1',
            ),
          ),
          throwsA(isA<ResolveEngineTaskConfigurationException>()),
        );

        expect(gateway.resolveRequests, isEmpty);
        expect(repository.savedTasks, isEmpty);
      },
    );

    test(
      'drops the response when the task is deleted while resolving',
      () async {
        final task = _task(reference: _reference());
        final repository = _FakeMediaTaskRepository(task);
        final projectionRepository = _FakeProjectionRepository(_projection());
        final gateway = _FakeEngineGateway(
          onResolve: (request) async {
            repository.task = null;
            return _operation(_resolution());
          },
        );

        final result = await _useCase(repository, projectionRepository, gateway)
            .call(
              taskId: task.id,
              analysisId: 'analysis-1',
              analysisRevision: 4,
              candidateId: 'candidate-1',
              selection: const EngineManualConfigurationSelection(
                candidateId: 'candidate-1',
              ),
            );

        expect(result, isNull);
        expect(repository.savedTasks, isEmpty);
      },
    );

    test(
      'drops the response when the source is replaced while resolving',
      () async {
        final originalReference = _reference(candidateId: 'candidate-old');
        final task = _task(reference: originalReference);
        final repository = _FakeMediaTaskRepository(task);
        final projectionRepository = _FakeProjectionRepository(_projection());
        late final MediaTask replacement;
        final gateway = _FakeEngineGateway(
          onResolve: (request) async {
            replacement = _task(
              inputPath: '/videos/replacement.mp4',
              fileSize: 2048,
              reference: null,
              analysisUpdatedAt: null,
            );
            repository.task = replacement;
            projectionRepository.projection = null;
            return _operation(_resolution());
          },
        );

        final result = await _useCase(repository, projectionRepository, gateway)
            .call(
              taskId: task.id,
              analysisId: 'analysis-1',
              analysisRevision: 4,
              candidateId: 'candidate-1',
              selection: const EngineManualConfigurationSelection(
                candidateId: 'candidate-1',
              ),
            );

        expect(result, same(replacement));
        expect(result?.config.engineConfiguration, isNull);
        expect(repository.savedTasks, isEmpty);
      },
    );

    test(
      'drops the response when a new analysis replaces the projection',
      () async {
        final originalReference = _reference(candidateId: 'candidate-old');
        final task = _task(reference: originalReference);
        final repository = _FakeMediaTaskRepository(task);
        final projectionRepository = _FakeProjectionRepository(_projection());
        final gateway = _FakeEngineGateway(
          onResolve: (request) async {
            projectionRepository.projection = _projection(
              analysisId: 'analysis-2',
              revision: 1,
              sequence: 15,
            );
            return _operation(_resolution());
          },
        );

        final result = await _useCase(repository, projectionRepository, gateway)
            .call(
              taskId: task.id,
              analysisId: 'analysis-1',
              analysisRevision: 4,
              candidateId: 'candidate-1',
              selection: const EngineManualConfigurationSelection(
                candidateId: 'candidate-1',
              ),
            );

        expect(result, same(task));
        expect(result?.config.engineConfiguration, same(originalReference));
        expect(repository.savedTasks, isEmpty);
      },
    );

    test('drops the response after reanalysis claims the task', () async {
      final originalReference = _reference(candidateId: 'candidate-old');
      final task = _task(reference: originalReference);
      final repository = _FakeMediaTaskRepository(task);
      final projectionRepository = _FakeProjectionRepository(_projection());
      final gateway = _FakeEngineGateway(
        onResolve: (request) async {
          repository.task = task.copyWith(status: TaskStatus.analyzing);
          return _operation(_resolution());
        },
      );

      final result = await _useCase(repository, projectionRepository, gateway)
          .call(
            taskId: task.id,
            analysisId: 'analysis-1',
            analysisRevision: 4,
            candidateId: 'candidate-1',
            selection: const EngineManualConfigurationSelection(
              candidateId: 'candidate-1',
            ),
          );

      expect(result?.status, TaskStatus.analyzing);
      expect(result?.config.engineConfiguration, same(originalReference));
      expect(repository.savedTasks, isEmpty);
    });

    test(
      'rejects a selection whose candidate differs before loading FEngine',
      () async {
        final task = _task();
        var gatewayLoadCount = 0;
        final useCase = ResolveEngineTaskConfigurationUseCase(
          repository: _FakeMediaTaskRepository(task),
          analysisProjectionRepository: _FakeProjectionRepository(
            _projection(),
          ),
          readEngineGateway: () async {
            gatewayLoadCount += 1;
            return _FakeEngineGateway(
              onResolve: (request) async => _operation(_resolution()),
            );
          },
        );

        await expectLater(
          useCase.call(
            taskId: task.id,
            analysisId: 'analysis-1',
            analysisRevision: 4,
            candidateId: 'candidate-1',
            selection: const EngineManualConfigurationSelection(
              candidateId: 'candidate-other',
            ),
          ),
          throwsArgumentError,
        );

        expect(gatewayLoadCount, 0);
      },
    );
  });
}

ResolveEngineTaskConfigurationUseCase _useCase(
  _FakeMediaTaskRepository repository,
  _FakeProjectionRepository projectionRepository,
  _FakeEngineGateway gateway,
) {
  return ResolveEngineTaskConfigurationUseCase(
    repository: repository,
    analysisProjectionRepository: projectionRepository,
    readEngineGateway: () async => gateway,
  );
}

MediaTask _task({
  String inputPath = '/videos/input.mp4',
  int fileSize = 1024,
  EngineConfigurationReference? reference,
  int? analysisUpdatedAt = 100,
}) {
  return MediaTask(
    id: 'task-1',
    inputPath: inputPath,
    fileName: inputPath.split('/').last,
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: MediaTaskConfig.initialVideo().copyWith(
      outputFileName: 'output-name',
      engineConfiguration: reference,
    ),
    progress: 0,
    sortOrder: 0,
    sourceFileFingerprint: SourceFileFingerprint(
      fileSize: fileSize,
      lastModifiedAt: 123,
    ),
    analysisResult: MediaAnalysisResult(durationMs: 1000),
    analysisUpdatedAt: analysisUpdatedAt,
    createdAt: 1,
  );
}

EngineConfigurationReference _reference({String candidateId = 'candidate-1'}) {
  return EngineConfigurationReference(
    analysisId: 'analysis-1',
    analysisRevision: 4,
    candidateId: candidateId,
    selectionMode: 'manual',
    selectionJson: '{"mode":"manual"}',
  );
}

EngineAnalysisProjection _projection({
  String analysisId = 'analysis-1',
  int revision = 4,
  int sequence = 10,
}) {
  return EngineAnalysisProjection(
    taskId: 'task-1',
    clientFileId: 'task-1',
    engineSessionId: 'session-1',
    analysisId: analysisId,
    revision: revision,
    schemaVersion: 'framelean.analysis-snapshot.v1',
    snapshotJson: '{}',
    validityStatus: 'valid',
    lastEventSequence: sequence,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(sequence),
  );
}

EngineConfigurationResolutionDocument _resolution({
  String analysisId = 'analysis-1',
  int analysisRevision = 4,
  String status = 'available',
  String candidateId = 'candidate-1',
  bool includeResolution = true,
}) {
  return EngineConfigurationResolutionDocument.fromJson(<String, Object?>{
    'schema_version': 'framelean.recalculate-configuration.v1',
    'analysis_id': analysisId,
    'analysis_revision': analysisRevision,
    'configuration_status': status,
    'resolved_configuration': includeResolution
        ? <String, Object?>{
            'selection_source': 'manual',
            'execution_chain_id': candidateId,
            'container': 'mp4',
            'demuxer_backend': 'mov',
            'video_decoders': <Object?>[],
            'audio_decoders': <Object?>[],
            'processors': <Object?>[],
            'muxer_backend': 'mp4',
            'output_hdr_mode': 'preserve',
            'preserves_hdr': true,
            'requires_tone_mapping': false,
          }
        : null,
  });
}

EngineOperationResult<EngineConfigurationResolutionDocument> _operation(
  EngineConfigurationResolutionDocument document, {
  String requestId = 'request-1',
}) {
  return EngineOperationResult(
    sessionId: 'session-1',
    requestId: requestId,
    workId: 'work-1',
    sequence: 11,
    value: document,
  );
}

final class _FakeEngineGateway implements EngineGateway {
  _FakeEngineGateway({required this.onResolve});

  final Future<EngineOperationResult<EngineConfigurationResolutionDocument>>
  Function(EngineConfigurationRequest request)
  onResolve;
  final List<EngineConfigurationRequest> resolveRequests = [];

  @override
  Stream<EngineWorkEvent> get events => const Stream.empty();

  @override
  Future<EngineOperationResult<EngineAnalysisResponseDocument>> analyze(
    EngineAnalysisRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}

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
  Future<EngineOperationResult<EngineConfigurationResolutionDocument>>
  resolveConfiguration(EngineConfigurationRequest request) {
    resolveRequests.add(request);
    return onResolve(request);
  }

  @override
  Future<EngineOperationResult<EngineExecutionSubmission>> submitExecution(
    EngineExecutionRequest request,
  ) {
    throw UnimplementedError();
  }
}

final class _FakeMediaTaskRepository implements MediaTaskRepository {
  _FakeMediaTaskRepository(this.task);

  MediaTask? task;
  final List<MediaTask> savedTasks = [];

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
    final current = task;
    return current?.id == taskId ? current : null;
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
    savedTasks.add(task);
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

final class _FakeProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _FakeProjectionRepository(this.projection);

  EngineAnalysisProjection? projection;

  @override
  Future<void> deleteAll() async {
    projection = null;
  }

  @override
  Future<void> deleteByTaskId(String taskId) async {
    if (projection?.taskId == taskId) {
      projection = null;
    }
  }

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    final current = projection;
    return current?.taskId == taskId ? current : null;
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    this.projection = projection;
  }
}
