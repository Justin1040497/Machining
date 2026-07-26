import 'package:framelean/application/models/engine_analysis_projection.dart';

/// Persists the Client's local projection of an FEngine analysis snapshot.
abstract class EngineAnalysisProjectionRepository {
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId);

  Future<void> upsert(EngineAnalysisProjection projection);

  Future<void> deleteByTaskId(String taskId);

  Future<void> deleteAll();
}
