import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/engine/engine_task_folder_selection_planner.dart';
import 'package:framelean/application/services/engine/engine_task_mode_mapper.dart';
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
/// selection exactly once when `SubmitExecution` crosses the process boundary.
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

    final reference = _configurationReference(
      analysisId: analysisId,
      analysisRevision: analysisRevision,
      selection: selection,
    );
    final updated = latestTask.copyWith(
      config: latestTask.config.copyWith(engineConfiguration: reference),
    );
    await repository.saveTask(updated);
    return updated;
  }
}

/// Saves one folder choice as an independent snapshot-bound selection per task.
///
/// The folder remains a Client grouping concept; no folder identity or shared
/// candidate is sent across the Engine boundary.
final class SaveTaskFolderEngineConfigurationUseCase {
  const SaveTaskFolderEngineConfigurationUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
  });

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;

  Future<List<MediaTask>> call({
    required String folderId,
    required Map<String, EngineAnalysisSnapshotDocument> snapshots,
    required EngineConfigurationSelection selection,
  }) async {
    if (folderId.trim().isEmpty) {
      throw const SaveEngineTaskConfigurationException('任务夹标识无效。');
    }

    final submittedTasks = await repository.loadAllTasks();
    final configurableTasks = submittedTasks
        .where((task) => task.folderId == folderId && task.canStartExecution)
        .toList();
    if (configurableTasks.isEmpty) {
      throw const SaveEngineTaskConfigurationException(
        '任务夹中没有等待开始且分析有效的任务。',
      );
    }
    if (!_sameIds(configurableTasks.map((task) => task.id), snapshots.keys)) {
      throw const SaveEngineTaskConfigurationException(
        '任务夹任务或分析结果已发生变化，请重新打开配置。',
      );
    }

    final selections = EngineTaskFolderSelectionPlanner(
      snapshots,
    ).resolve(selection);
    final submittedProjections = <String, EngineAnalysisProjection>{};
    for (final task in configurableTasks) {
      final snapshot = snapshots[task.id]!;
      final projection = await analysisProjectionRepository.loadByTaskId(
        task.id,
      );
      if (snapshot.taskMode != engineTaskModeForMediaTask(task) ||
          !snapshot.validity.isValid ||
          !_matchesAnalysis(
            projection,
            taskId: task.id,
            analysisId: snapshot.analysisId,
            analysisRevision: snapshot.analysisRevision,
          )) {
        throw const SaveEngineTaskConfigurationException(
          '任务夹中的分析结果已失效，请重新分析后再配置。',
        );
      }
      submittedProjections[task.id] = projection!;
    }

    final latestTasks = await repository.loadTasksByIds(
      configurableTasks.map((task) => task.id),
    );
    final submittedById = {
      for (final task in configurableTasks) task.id: task,
    };
    if (!_sameIds(latestTasks.map((task) => task.id), submittedById.keys)) {
      throw const SaveEngineTaskConfigurationException(
        '任务夹任务已发生变化，配置未保存。',
      );
    }

    final updatedTasks = <MediaTask>[];
    for (final latestTask in latestTasks) {
      final submittedTask = submittedById[latestTask.id]!;
      final submittedProjection = submittedProjections[latestTask.id]!;
      final latestProjection = await analysisProjectionRepository.loadByTaskId(
        latestTask.id,
      );
      if (!_sameTaskGeneration(submittedTask, latestTask) ||
          !_sameProjectionGeneration(
            submittedProjection,
            latestProjection,
          )) {
        throw const SaveEngineTaskConfigurationException(
          '任务夹任务或分析结果已发生变化，配置未保存。',
        );
      }
      final snapshot = snapshots[latestTask.id]!;
      final taskSelection = selections[latestTask.id]!;
      updatedTasks.add(
        latestTask.copyWith(
          config: latestTask.config.copyWith(
            engineConfiguration: _configurationReference(
              analysisId: snapshot.analysisId,
              analysisRevision: snapshot.analysisRevision,
              selection: taskSelection,
            ),
          ),
        ),
      );
    }

    await repository.insertTasks(updatedTasks);
    return repository.loadAllTasks();
  }
}

EngineConfigurationReference _configurationReference({
  required String analysisId,
  required int analysisRevision,
  required EngineConfigurationSelection selection,
}) {
  return EngineConfigurationReference(
    analysisId: analysisId,
    analysisRevision: analysisRevision,
    candidateId: selection.candidateId,
    selectionMode: engineConfigurationSelectionMode(selection),
    selectionJson: jsonEncode(engineConfigurationSelectionToJson(selection)),
  );
}

bool _sameIds(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length &&
      leftSet.containsAll(rightSet) &&
      rightSet.containsAll(leftSet);
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
