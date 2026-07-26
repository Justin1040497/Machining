import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/library.dart';

final class ResolveEngineTaskConfigurationException implements Exception {
  const ResolveEngineTaskConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves an FLL-owned selection and persists only its stable reference.
///
/// The Client never derives or copies the resolved media configuration. FLL
/// remains authoritative, while the reference lets execution resolve the same
/// selection against the same immutable analysis revision.
@Deprecated(
  'Compatibility-only protocol v1 flow; use SaveEngineTaskConfigurationUseCase.',
)
final class ResolveEngineTaskConfigurationUseCase {
  const ResolveEngineTaskConfigurationUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
    required this.readEngineGateway,
  });

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;
  final Future<EngineGateway> Function() readEngineGateway;

  Future<MediaTask?> call({
    required String taskId,
    required String analysisId,
    required int analysisRevision,
    required String candidateId,
    required EngineConfigurationSelection selection,
  }) async {
    _validateRequest(
      taskId: taskId,
      analysisId: analysisId,
      analysisRevision: analysisRevision,
      candidateId: candidateId,
      selection: selection,
    );

    final submittedTask = await repository.loadTaskById(taskId);
    if (submittedTask == null) {
      return null;
    }
    if (!submittedTask.canStartExecution) {
      throw const ResolveEngineTaskConfigurationException('只有等待开始的任务可以修改引擎配置。');
    }

    final submittedProjection = await analysisProjectionRepository.loadByTaskId(
      taskId,
    );
    if (!_matchesRequestedAnalysis(
      submittedProjection,
      taskId: taskId,
      analysisId: analysisId,
      analysisRevision: analysisRevision,
    )) {
      throw const ResolveEngineTaskConfigurationException(
        '任务的分析结果已失效，请重新打开配置或重新分析。',
      );
    }

    final gateway = await _loadEngineGateway();
    final result = await gateway.resolveConfiguration(
      EngineConfigurationRequest(
        analysisId: analysisId,
        expectedRevision: analysisRevision,
        selection: selection,
      ),
    );
    _validateResolution(
      result,
      analysisId: analysisId,
      analysisRevision: analysisRevision,
      candidateId: candidateId,
    );

    final latestTask = await repository.loadTaskById(taskId);
    if (latestTask == null) {
      return null;
    }
    final latestProjection = await analysisProjectionRepository.loadByTaskId(
      taskId,
    );
    if (!_isSameTaskGeneration(submittedTask, latestTask) ||
        !_isSameProjectionGeneration(submittedProjection!, latestProjection) ||
        !_matchesRequestedAnalysis(
          latestProjection,
          taskId: taskId,
          analysisId: analysisId,
          analysisRevision: analysisRevision,
        )) {
      return latestTask;
    }

    final reference = EngineConfigurationReference(
      analysisId: analysisId,
      analysisRevision: analysisRevision,
      candidateId: candidateId,
      selectionMode: engineConfigurationSelectionMode(selection),
      selectionJson: jsonEncode(engineConfigurationSelectionToJson(selection)),
    );
    final updatedTask = latestTask.copyWith(
      config: latestTask.config.copyWith(engineConfiguration: reference),
    );
    await repository.saveTask(updatedTask);
    return updatedTask;
  }

  Future<EngineGateway> _loadEngineGateway() async {
    try {
      return await readEngineGateway();
    } on EngineGatewayException {
      rethrow;
    } on Object catch (error) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.connection,
        message: 'Unable to initialize the media engine: $error',
      );
    }
  }

  void _validateRequest({
    required String taskId,
    required String analysisId,
    required int analysisRevision,
    required String candidateId,
    required EngineConfigurationSelection selection,
  }) {
    if (taskId.trim().isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', 'must not be empty');
    }
    if (analysisId.trim().isEmpty) {
      throw ArgumentError.value(analysisId, 'analysisId', 'must not be empty');
    }
    if (analysisRevision < 0) {
      throw ArgumentError.value(
        analysisRevision,
        'analysisRevision',
        'must not be negative',
      );
    }
    if (candidateId.trim().isEmpty) {
      throw ArgumentError.value(
        candidateId,
        'candidateId',
        'must not be empty',
      );
    }
    if (selection.candidateId != candidateId) {
      throw ArgumentError.value(
        selection.candidateId,
        'selection.candidateId',
        'must match candidateId',
      );
    }
  }

  void _validateResolution(
    EngineOperationResult<EngineConfigurationResolutionDocument> result, {
    required String analysisId,
    required int analysisRevision,
    required String candidateId,
  }) {
    final document = result.value;
    if (document.analysisId != analysisId ||
        document.analysisRevision != analysisRevision) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'configuration response analysis identity does not match',
        requestId: result.requestId,
      );
    }

    final resolved = document.resolvedConfiguration;
    if (document.configurationStatus != EngineConfigurationStatus.available ||
        resolved == null) {
      throw const ResolveEngineTaskConfigurationException(
        '媒体引擎未能生成可执行配置，请调整选项后重试。',
      );
    }
    if (resolved.executionChainId != candidateId) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'configuration response candidate does not match',
        requestId: result.requestId,
      );
    }
  }

  bool _matchesRequestedAnalysis(
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

  bool _isSameProjectionGeneration(
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

  bool _isSameTaskGeneration(MediaTask submitted, MediaTask latest) {
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
}
