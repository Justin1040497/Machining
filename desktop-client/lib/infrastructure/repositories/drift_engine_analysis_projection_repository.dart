import 'package:drift/drift.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/database/app_database.dart';

class DriftEngineAnalysisProjectionRepository
    implements EngineAnalysisProjectionRepository {
  DriftEngineAnalysisProjectionRepository(this.database);

  final AppDatabase database;

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    final row = await (database.select(
      database.engineAnalysisProjectionRows,
    )..where((table) => table.taskId.equals(taskId))).getSingleOrNull();
    return row?.toApplication();
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) {
    return database
        .into(database.engineAnalysisProjectionRows)
        .insertOnConflictUpdate(projection.toCompanion());
  }

  @override
  Future<void> deleteByTaskId(String taskId) {
    return (database.delete(
      database.engineAnalysisProjectionRows,
    )..where((table) => table.taskId.equals(taskId))).go();
  }

  @override
  Future<void> deleteAll() {
    return database.delete(database.engineAnalysisProjectionRows).go();
  }
}

extension EngineAnalysisProjectionRowMapper on EngineAnalysisProjectionRow {
  EngineAnalysisProjection toApplication() {
    return EngineAnalysisProjection(
      taskId: taskId,
      clientFileId: clientFileId,
      engineSessionId: engineSessionId,
      analysisId: analysisId,
      revision: revision,
      schemaVersion: schemaVersion,
      snapshotJson: snapshotJson,
      validityStatus: validityStatus,
      analysisWorkId: analysisWorkId,
      analysisRequestId: analysisRequestId,
      analysisQueuePosition: analysisQueuePosition,
      analysisQueueRevision: analysisQueueRevision,
      executionId: executionId,
      executionRequestId: executionRequestId,
      executionQueuePosition: executionQueuePosition,
      executionQueueRevision: executionQueueRevision,
      executionState: executionState,
      pauseReason: pauseReason,
      preemptedByExecutionId: preemptedByExecutionId,
      resumeDepth: resumeDepth,
      mediaTimeUs: mediaTimeUs,
      processedBytes: processedBytes,
      lastEventSequence: lastEventSequence,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }
}

extension EngineAnalysisProjectionMapper on EngineAnalysisProjection {
  EngineAnalysisProjectionRowsCompanion toCompanion() {
    return EngineAnalysisProjectionRowsCompanion(
      taskId: Value(taskId),
      clientFileId: Value(clientFileId),
      engineSessionId: Value(engineSessionId),
      analysisId: Value(analysisId),
      revision: Value(revision),
      schemaVersion: Value(schemaVersion),
      snapshotJson: Value(snapshotJson),
      validityStatus: Value(validityStatus),
      analysisWorkId: Value(analysisWorkId),
      analysisRequestId: Value(analysisRequestId),
      analysisQueuePosition: Value(analysisQueuePosition),
      analysisQueueRevision: Value(analysisQueueRevision),
      executionId: Value(executionId),
      executionRequestId: Value(executionRequestId),
      executionQueuePosition: Value(executionQueuePosition),
      executionQueueRevision: Value(executionQueueRevision),
      executionState: Value(executionState),
      pauseReason: Value(pauseReason),
      preemptedByExecutionId: Value(preemptedByExecutionId),
      resumeDepth: Value(resumeDepth),
      mediaTimeUs: Value(mediaTimeUs),
      processedBytes: Value(processedBytes),
      lastEventSequence: Value(lastEventSequence),
      updatedAt: Value(updatedAt.millisecondsSinceEpoch),
    );
  }
}
