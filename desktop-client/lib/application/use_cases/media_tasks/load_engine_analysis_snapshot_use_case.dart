import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/services/engine/engine_task_mode_mapper.dart';
import 'package:framelean/domain/library.dart';

class LoadEngineAnalysisSnapshotUseCase {
  const LoadEngineAnalysisSnapshotUseCase({
    required this.analysisProjectionRepository,
  });

  final EngineAnalysisProjectionRepository analysisProjectionRepository;

  Future<EngineAnalysisSnapshotDocument?> call(MediaTask task) async {
    final projection = await analysisProjectionRepository.loadByTaskId(task.id);
    if (projection == null ||
        projection.taskId != task.id ||
        projection.clientFileId != task.id ||
        projection.analysisId == null ||
        projection.revision == null ||
        projection.schemaVersion == null ||
        projection.snapshotJson == null ||
        projection.validityStatus == null) {
      return null;
    }

    final snapshot = _parseSnapshot(projection.snapshotJson!);
    if (snapshot == null ||
        snapshot.analysisId != projection.analysisId ||
        snapshot.analysisRevision != projection.revision ||
        snapshot.schemaVersion != projection.schemaVersion ||
        snapshot.taskMode != engineTaskModeForMediaTask(task) ||
        snapshot.validity.status.name != projection.validityStatus ||
        !snapshot.validity.isValid) {
      return null;
    }

    return snapshot;
  }

  EngineAnalysisSnapshotDocument? _parseSnapshot(String snapshotJson) {
    try {
      final decoded = jsonDecode(snapshotJson);
      if (decoded is! Map) {
        return null;
      }
      final json = <String, Object?>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        if (key is! String) {
          return null;
        }
        json[key] = entry.value;
      }
      return EngineAnalysisSnapshotDocument.fromJson(json);
    } on FormatException {
      return null;
    } on EngineDocumentException {
      return null;
    }
  }
}
