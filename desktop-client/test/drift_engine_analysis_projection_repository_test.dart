import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_engine_analysis_projection_repository.dart';

void main() {
  group('DriftEngineAnalysisProjectionRepository', () {
    test('persists the engine snapshot as opaque JSON', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEngineAnalysisProjectionRepository(database);
      const snapshotJson =
          '{"schema_version":"1.0","presets":[{"future_field":true}]}';
      final projection = EngineAnalysisProjection(
        taskId: 'task-1',
        clientFileId: 'client-file-1',
        engineSessionId: 'session-1',
        analysisId: 'analysis-1',
        revision: 4,
        schemaVersion: '1.0',
        snapshotJson: snapshotJson,
        validityStatus: 'valid',
        lastEventSequence: 12,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1234),
      );

      await repository.upsert(projection);

      final restored = await repository.loadByTaskId('task-1');
      expect(restored, isNotNull);
      expect(restored!.taskId, projection.taskId);
      expect(restored.clientFileId, projection.clientFileId);
      expect(restored.engineSessionId, projection.engineSessionId);
      expect(restored.analysisId, projection.analysisId);
      expect(restored.revision, projection.revision);
      expect(restored.schemaVersion, projection.schemaVersion);
      expect(restored.snapshotJson, snapshotJson);
      expect(restored.validityStatus, projection.validityStatus);
      expect(restored.lastEventSequence, projection.lastEventSequence);
      expect(restored.updatedAt, projection.updatedAt);
    });

    test(
      'upsert can replace the source and clear stale analysis data',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = DriftEngineAnalysisProjectionRepository(database);

        await repository.upsert(
          EngineAnalysisProjection(
            taskId: 'task-1',
            clientFileId: 'client-file-old',
            engineSessionId: 'session-old',
            analysisId: 'analysis-old',
            revision: 3,
            schemaVersion: '1.0',
            snapshotJson: '{"analysis_id":"analysis-old"}',
            validityStatus: 'valid',
            lastEventSequence: 8,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        );
        await repository.upsert(
          EngineAnalysisProjection(
            taskId: 'task-1',
            clientFileId: 'client-file-new',
            engineSessionId: 'session-new',
            lastEventSequence: 0,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        );

        final restored = await repository.loadByTaskId('task-1');
        expect(restored, isNotNull);
        expect(restored!.clientFileId, 'client-file-new');
        expect(restored.analysisId, isNull);
        expect(restored.revision, isNull);
        expect(restored.schemaVersion, isNull);
        expect(restored.snapshotJson, isNull);
        expect(restored.validityStatus, isNull);
        expect(restored.lastEventSequence, 0);
        expect(restored.updatedAt.millisecondsSinceEpoch, 2000);
      },
    );

    test('deletes a projection by task id', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEngineAnalysisProjectionRepository(database);
      await repository.upsert(
        EngineAnalysisProjection(
          taskId: 'task-1',
          clientFileId: 'client-file-1',
          engineSessionId: 'session-1',
          lastEventSequence: 0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );

      await repository.deleteByTaskId('task-1');

      expect(await repository.loadByTaskId('task-1'), isNull);
    });

    test('deletes all projections', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEngineAnalysisProjectionRepository(database);
      await repository.upsert(
        EngineAnalysisProjection(
          taskId: 'task-1',
          clientFileId: 'client-file-1',
          engineSessionId: 'session-1',
          lastEventSequence: 0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      await repository.upsert(
        EngineAnalysisProjection(
          taskId: 'task-2',
          clientFileId: 'client-file-2',
          engineSessionId: 'session-2',
          lastEventSequence: 0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
      );

      await repository.deleteAll();

      expect(await repository.loadByTaskId('task-1'), isNull);
      expect(await repository.loadByTaskId('task-2'), isNull);
    });
  });
}
