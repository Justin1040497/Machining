import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/use_cases/media_tasks/load_engine_analysis_snapshot_use_case.dart';
import 'package:framelean/domain/library.dart';

void main() {
  group('LoadEngineAnalysisSnapshotUseCase', () {
    test('returns a hard-validated matching valid snapshot', () async {
      final repository = _ProjectionRepository(_projection());
      final useCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: repository,
      );

      final snapshot = await useCase(_task());

      expect(snapshot, isNotNull);
      expect(snapshot!.analysisId, 'analysis-1');
      expect(snapshot.analysisRevision, 4);
      expect(snapshot.schemaVersion, 'framelean.analysis-snapshot.v1');
      expect(snapshot.validity.isValid, isTrue);
    });

    test('returns null when no complete snapshot projection exists', () async {
      final missingUseCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(null),
      );
      final incompleteUseCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(
          EngineAnalysisProjection(
            taskId: 'task-1',
            clientFileId: 'file-1',
            engineSessionId: 'session-1',
            lastEventSequence: 1,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
      );

      expect(await missingUseCase(_task()), isNull);
      expect(await incompleteUseCase(_task()), isNull);
    });

    test('returns null for malformed or structurally invalid JSON', () async {
      final malformedUseCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(
          _projection(snapshotJson: '{'),
        ),
      );
      final wrongRootUseCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(
          _projection(snapshotJson: '[]'),
        ),
      );
      final invalidDocumentUseCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(
          _projection(snapshotJson: '{"analysis_id":"analysis-1"}'),
        ),
      );

      expect(await malformedUseCase(_task()), isNull);
      expect(await wrongRootUseCase(_task()), isNull);
      expect(await invalidDocumentUseCase(_task()), isNull);
    });

    test(
      'rejects projection metadata that does not match the document',
      () async {
        final mismatches = <EngineAnalysisProjection>[
          _projection(taskId: 'task-other'),
          _projection(clientFileId: 'file-other'),
          _projection(analysisId: 'analysis-other'),
          _projection(revision: 5),
          _projection(schemaVersion: 'framelean.analysis-snapshot.v2'),
          _projection(validityStatus: 'invalid'),
        ];

        for (final projection in mismatches) {
          final useCase = LoadEngineAnalysisSnapshotUseCase(
            analysisProjectionRepository: _ProjectionRepository(projection),
          );

          expect(
            await useCase(_task()),
            isNull,
            reason: 'mismatched ${projection.toString()} must not be usable',
          );
        }
      },
    );

    test('rejects an invalid snapshot even when metadata matches', () async {
      final snapshot = _snapshot()
        ..['validity'] = <String, Object?>{
          'status': 'invalid',
          'reason_code': 'ANALYSIS_SOURCE_CHANGED',
          'message': 'source changed',
        };
      final useCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(
          _projection(
            snapshotJson: jsonEncode(snapshot),
            validityStatus: 'invalid',
          ),
        ),
      );

      expect(await useCase(_task()), isNull);
    });

    test('rejects a snapshot created for a different task mode', () async {
      final useCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(_projection()),
      );

      expect(await useCase(_task(purpose: TaskPurpose.conversion)), isNull);
    });

    test('propagates repository failures', () async {
      final failure = StateError('database unavailable');
      final useCase = LoadEngineAnalysisSnapshotUseCase(
        analysisProjectionRepository: _ProjectionRepository(
          null,
          loadFailure: failure,
        ),
      );

      expect(() => useCase(_task()), throwsA(same(failure)));
    });
  });
}

MediaTask _task({TaskPurpose purpose = TaskPurpose.compression}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/video/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    purpose: purpose,
    status: TaskStatus.pending,
    config: MediaTaskConfig.initialVideo(),
    progress: 0,
    sortOrder: 0,
  );
}

final class _ProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _ProjectionRepository(this.projection, {this.loadFailure});

  final EngineAnalysisProjection? projection;
  final Object? loadFailure;

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    final failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return projection;
  }

  @override
  Future<void> deleteAll() => throw UnimplementedError();

  @override
  Future<void> deleteByTaskId(String taskId) => throw UnimplementedError();

  @override
  Future<void> upsert(EngineAnalysisProjection projection) =>
      throw UnimplementedError();
}

EngineAnalysisProjection _projection({
  String taskId = 'task-1',
  String clientFileId = 'task-1',
  String analysisId = 'analysis-1',
  int revision = 4,
  String schemaVersion = 'framelean.analysis-snapshot.v1',
  String? snapshotJson,
  String validityStatus = 'valid',
}) {
  return EngineAnalysisProjection(
    taskId: taskId,
    clientFileId: clientFileId,
    engineSessionId: 'session-1',
    analysisId: analysisId,
    revision: revision,
    schemaVersion: schemaVersion,
    snapshotJson: snapshotJson ?? jsonEncode(_snapshot()),
    validityStatus: validityStatus,
    lastEventSequence: 7,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );
}

Map<String, Object?> _snapshot() {
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
      'available': false,
      'execution_chains': <Object?>[],
    },
    'configuration_options': <String, Object?>{
      'candidate_ids': <Object?>[],
      'containers': <Object?>[],
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
      'status': 'unavailable',
      'configuration': null,
      'estimate': null,
      'reasons': <Object?>['no executable candidate'],
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
