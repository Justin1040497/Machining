import 'package:drift/drift.dart';

class EngineAnalysisProjectionRows extends Table {
  TextColumn get taskId => text().named('task_id')();
  TextColumn get clientFileId => text().named('client_file_id')();
  TextColumn get engineSessionId => text().named('engine_session_id')();
  TextColumn get analysisId => text().named('analysis_id').nullable()();
  IntColumn get revision => integer().nullable()();
  TextColumn get schemaVersion => text().named('schema_version').nullable()();
  TextColumn get snapshotJson => text().named('snapshot_json').nullable()();
  TextColumn get validityStatus => text().named('validity_status').nullable()();
  TextColumn get analysisWorkId =>
      text().named('analysis_work_id').nullable()();
  TextColumn get analysisRequestId =>
      text().named('analysis_request_id').nullable()();
  IntColumn get analysisQueuePosition =>
      integer().named('analysis_queue_position').nullable()();
  IntColumn get analysisQueueRevision =>
      integer().named('analysis_queue_revision').nullable()();
  TextColumn get executionId => text().named('execution_id').nullable()();
  TextColumn get executionRequestId =>
      text().named('execution_request_id').nullable()();
  IntColumn get executionQueuePosition =>
      integer().named('execution_queue_position').nullable()();
  IntColumn get executionQueueRevision =>
      integer().named('execution_queue_revision').nullable()();
  TextColumn get executionState => text().named('execution_state').nullable()();
  TextColumn get pauseReason => text().named('pause_reason').nullable()();
  TextColumn get preemptedByExecutionId =>
      text().named('preempted_by_execution_id').nullable()();
  IntColumn get resumeDepth => integer().named('resume_depth').nullable()();
  IntColumn get mediaTimeUs => integer().named('media_time_us').nullable()();
  IntColumn get processedBytes =>
      integer().named('processed_bytes').nullable()();
  IntColumn get lastEventSequence =>
      integer().named('last_event_sequence').withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  String get tableName => 'engine_analysis_projections';

  @override
  Set<Column> get primaryKey => {taskId};
}
