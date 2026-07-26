import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/library.dart';

final class SaveEngineTaskConfigurationException implements Exception {
  const SaveEngineTaskConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persists the user's opaque selection against an immutable analysis revision.
///
/// Selection editing is a Client concern. FLL validates and resolves the same
/// selection exactly once when `SubmitExecution` crosses the process boundary;
/// there is deliberately no independent `ResolveConfiguration` request here.
final class SaveEngineTaskConfigurationUseCase {
  const SaveEngineTaskConfigurationUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
  });

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;

  Future<MediaTask?> call({
    required String taskId,
    required String analysisId,
    required int analysisRevision,
    required EngineConfigurationSelection selection,
  }) async {
    if (taskId.trim().isEmpty ||
        analysisId.trim().isEmpty ||
        analysisRevision < 0 ||
        selection.candidateId.trim().isEmpty) {
      throw const SaveEngineTaskConfigurationException('引擎配置引用无效。');
    }

    final submittedTask = await repository.loadTaskById(taskId);
    if (submittedTask == null) {
      return null;
    }
    if (!submittedTask.canStartExecution) {
      throw const SaveEngineTaskConfigurationException('只有等待开始的任务可以修改引擎配置。');
    }
    final submittedProjection = await analysisProjectionRepository.loadByTaskId(
      taskId,
    );
    if (!_matchesAnalysis(
      submittedProjection,
      taskId: taskId,
      analysisId: analysisId,
      analysisRevision: analysisRevision,
    )) {
      throw const SaveEngineTaskConfigurationException(
        '任务的分析结果已失效，请重新打开配置或重新分析。',
      );
    }

    final latestTask = await repository.loadTaskById(taskId);
    final latestProjection = await analysisProjectionRepository.loadByTaskId(
      taskId,
    );
    if (latestTask == null) {
      return null;
    }
    if (!_sameTaskGeneration(submittedTask, latestTask) ||
        !_sameProjectionGeneration(submittedProjection!, latestProjection)) {
      return latestTask;
    }

    final reference = EngineConfigurationReference(
      analysisId: analysisId,
      analysisRevision: analysisRevision,
      candidateId: selection.candidateId,
      selectionMode: engineConfigurationSelectionMode(selection),
      selectionJson: jsonEncode(engineConfigurationSelectionToJson(selection)),
    );
    final updated = latestTask.copyWith(
      config: latestTask.config.copyWith(engineConfiguration: reference),
    );
    await repository.saveTask(updated);
    return updated;
  }
}

bool _matchesAnalysis(
  EngineAnalysisProjection? projection, {
  required String taskId,
  required String analysisId,
  required int analysisRevision,
}) {
  return projection != null &&
      projection.taskId == taskId &&
      projection.clientFileId == taskId &&
      projection.analysisId == analysisId &&
      projection.revision == analysisRevision &&
      projection.validityStatus == 'valid';
}

bool _sameProjectionGeneration(
  EngineAnalysisProjection submitted,
  EngineAnalysisProjection? latest,
) {
  return latest != null &&
      latest.taskId == submitted.taskId &&
      latest.clientFileId == submitted.clientFileId &&
      latest.engineSessionId == submitted.engineSessionId &&
      latest.analysisId == submitted.analysisId &&
      latest.revision == submitted.revision &&
      latest.schemaVersion == submitted.schemaVersion &&
      latest.validityStatus == submitted.validityStatus &&
      latest.lastEventSequence == submitted.lastEventSequence &&
      latest.updatedAt == submitted.updatedAt;
}

bool _sameTaskGeneration(MediaTask submitted, MediaTask latest) {
  if (latest.id != submitted.id ||
      latest.inputPath != submitted.inputPath ||
      latest.mediaKind != submitted.mediaKind ||
      latest.purpose != submitted.purpose ||
      latest.status != submitted.status ||
      latest.analysisUpdatedAt != submitted.analysisUpdatedAt) {
    return false;
  }
  final submittedFingerprint = submitted.sourceFileFingerprint;
  final latestFingerprint = latest.sourceFileFingerprint;
  if (submittedFingerprint == null || latestFingerprint == null) {
    return submittedFingerprint == null && latestFingerprint == null;
  }
  return submittedFingerprint.isSameAs(latestFingerprint);
}
