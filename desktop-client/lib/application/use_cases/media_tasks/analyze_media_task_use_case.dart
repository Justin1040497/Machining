import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/engine/engine_media_display_projection_mapper.dart';
import 'package:framelean/application/services/engine/engine_task_mode_mapper.dart';
import 'package:framelean/domain/library.dart';
import 'package:uuid/uuid.dart';

class AnalyzeMediaTaskUseCase {
  AnalyzeMediaTaskUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
    required this.readEngineGateway,
    this.displayProjectionMapper = const EngineMediaDisplayProjectionMapper(),
    this.now = DateTime.now,
    String Function()? createRequestId,
  }) : createRequestId = createRequestId ?? const Uuid().v4;

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;
  final Future<EngineGateway> Function() readEngineGateway;
  final EngineMediaDisplayProjectionMapper displayProjectionMapper;
  final DateTime Function() now;
  final String Function() createRequestId;

  Future<MediaTask?> call(String taskId, {bool forceReanalysis = false}) async {
    final loadedTask = await repository.loadTaskById(taskId);
    if (loadedTask == null ||
        (loadedTask.status != TaskStatus.awaitAnalysis &&
            loadedTask.status != TaskStatus.analysisQueued &&
            loadedTask.status != TaskStatus.analyzing)) {
      return loadedTask;
    }
    var task = loadedTask;

    try {
      final engineGateway = await _loadEngineGateway();
      final connection = await engineGateway.connect();
      if (!forceReanalysis) {
        final reusable = await _loadReusableSnapshot(task, engineGateway);
        if (reusable != null) {
          return _commitSnapshot(task, reusable);
        }
      }

      final currentTask = await _clearConfigurationForNewAnalysis(task);
      if (currentTask == null) {
        return null;
      }
      if (!_isSameAnalysisAttempt(task, currentTask)) {
        return currentTask;
      }
      task = currentTask;
      final previousProjection = await analysisProjectionRepository
          .loadByTaskId(task.id);
      final analysisRequestId = forceReanalysis
          ? createRequestId()
          : previousProjection?.analysisRequestId ?? createRequestId();
      await analysisProjectionRepository.deleteByTaskId(task.id);
      final fingerprint = task.sourceFileFingerprint;
      if (fingerprint == null) {
        return _markFailure(
          task.id,
          expectedTask: task,
          code: TaskFailureCode.analysisFailed,
          message: '缺少源文件信息，请重新导入或重新选择文件。',
          technicalSummary: 'Client source fingerprint is missing',
          retryable: true,
        );
      }
      await analysisProjectionRepository.upsert(
        EngineAnalysisProjection(
          taskId: task.id,
          clientFileId: task.id,
          engineSessionId: connection.sessionId,
          analysisRequestId: analysisRequestId,
          analysisWorkId: previousProjection?.analysisWorkId,
          analysisQueuePosition: previousProjection?.analysisQueuePosition,
          analysisQueueRevision: previousProjection?.analysisQueueRevision,
          lastEventSequence: previousProjection?.lastEventSequence ?? 0,
          updatedAt: now(),
        ),
      );

      final analysis = await engineGateway.analyze(
        EngineAnalysisRequest(
          clientTaskId: task.id,
          clientFileId: task.id,
          source: EngineSourceFacts(
            path: task.inputPath,
            fileSizeBytes: fingerprint.fileSize,
            // Client currently persists millisecond precision. Supplying a
            // fabricated nanosecond value would make FLL reject valid files.
            modifiedTimeUnixNanos: null,
          ),
          taskMode: engineTaskModeForMediaTask(task),
          forceReanalysis: forceReanalysis,
          requestId: analysisRequestId,
        ),
      );
      final response = analysis.value.analysis;
      final completedSnapshot = analysis.value.snapshot;
      if (!response.hasSnapshot || completedSnapshot == null) {
        final failed = await _markAnalysisDocumentFailure(task, response);
        await _deleteProjectionIfRequestMatches(task.id, analysisRequestId);
        return failed;
      }
      await analysisProjectionRepository.upsert(
        EngineAnalysisProjection(
          taskId: task.id,
          clientFileId: task.id,
          engineSessionId: analysis.sessionId,
          analysisId: response.analysisId,
          revision: response.analysisRevision,
          analysisWorkId: analysis.workId,
          analysisRequestId: analysisRequestId,
          analysisQueuePosition: analysis.queuePosition,
          analysisQueueRevision: analysis.queueRevision,
          lastEventSequence: analysis.sequence,
          updatedAt: now(),
        ),
      );

      final snapshot = EngineOperationResult<EngineAnalysisSnapshotDocument>(
        sessionId: analysis.sessionId,
        requestId: analysis.requestId,
        workId: analysis.workId,
        sequence: analysis.sequence,
        value: completedSnapshot,
        queueKind: analysis.queueKind,
        queuePosition: analysis.queuePosition,
        queueRevision: analysis.queueRevision,
      );
      _validateAnalysisPair(response, snapshot.value, snapshot.requestId);
      return _commitSnapshot(
        task,
        snapshot,
        attemptRequestId: analysisRequestId,
      );
    } on EngineWorkerException catch (error) {
      return _markEngineFailure(task.id, error, expectedTask: task);
    } on EngineGatewayException catch (error) {
      return _markFailure(
        task.id,
        expectedTask: task,
        code:
            error.kind == EngineGatewayFailureKind.connection ||
                error.kind == EngineGatewayFailureKind.closed
            ? TaskFailureCode.analysisRuntimeUnavailable
            : TaskFailureCode.analysisFailed,
        message:
            error.kind == EngineGatewayFailureKind.connection ||
                error.kind == EngineGatewayFailureKind.closed
            ? '媒体引擎暂时不可用，请稍后重试。'
            : '媒体引擎返回了无法识别的分析结果。',
        technicalSummary: error.toString(),
        retryable:
            error.kind == EngineGatewayFailureKind.connection ||
            error.kind == EngineGatewayFailureKind.closed,
      );
    } on Object catch (error) {
      return _markFailure(
        task.id,
        expectedTask: task,
        code: TaskFailureCode.analysisFailed,
        message: '媒体分析失败，请确认文件可以正常读取后重试。',
        technicalSummary: error.toString(),
        retryable: true,
      );
    }
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

  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>?>
  _loadReusableSnapshot(MediaTask task, EngineGateway engineGateway) async {
    final projection = await analysisProjectionRepository.loadByTaskId(task.id);
    final analysisId = projection?.analysisId;
    if (projection == null ||
        projection.clientFileId != task.id ||
        analysisId == null ||
        analysisId.isEmpty) {
      return null;
    }

    try {
      final result = await engineGateway.getAnalysisSnapshot(analysisId);
      final snapshot = result.value;
      if (snapshot.analysisId != analysisId ||
          snapshot.taskMode != engineTaskModeForMediaTask(task)) {
        await analysisProjectionRepository.deleteByTaskId(task.id);
        return null;
      }
      if (!snapshot.validity.isValid) {
        await _saveProjection(task, result);
        return null;
      }
      return result;
    } on EngineWorkerException catch (error) {
      if (error.engineCode == 'ANALYSIS_SNAPSHOT_EXPIRED' ||
          error.engineCode == 'ANALYSIS_SOURCE_CHANGED') {
        await analysisProjectionRepository.deleteByTaskId(task.id);
        return null;
      }
      rethrow;
    }
  }

  Future<MediaTask?> _commitSnapshot(
    MediaTask submittedTask,
    EngineOperationResult<EngineAnalysisSnapshotDocument> result, {
    String? attemptRequestId,
  }) async {
    final latestTask = await repository.loadTaskById(submittedTask.id);
    if (latestTask == null) {
      return null;
    }
    if (!_isSameAnalysisAttempt(submittedTask, latestTask)) {
      if (attemptRequestId != null) {
        await _deleteProjectionIfRequestMatches(
          submittedTask.id,
          attemptRequestId,
        );
      }
      return latestTask;
    }

    await _saveProjection(latestTask, result);
    if (!result.value.validity.isValid) {
      return _markFailure(
        latestTask.id,
        expectedTask: latestTask,
        code: TaskFailureCode.sourceUnavailable,
        message: '源文件已发生变化，请重新分析。',
        technicalSummary:
            result.value.validity.message ??
            result.value.validity.reasonCode ??
            'Analysis snapshot is invalid',
        retryable: true,
      );
    }

    final displayProjection = displayProjectionMapper.map(result.value);
    final reference = latestTask.config.engineConfiguration;
    final config =
        reference != null &&
            reference.analysisId == result.value.analysisId &&
            reference.analysisRevision == result.value.analysisRevision
        ? latestTask.config
        : latestTask.config.copyWith(engineConfiguration: null);
    final updatedTask = latestTask
        .copyWith(config: config)
        .withAnalysisResult(displayProjection)
        .markAnalysisReady();
    await repository.saveTask(updatedTask);
    return updatedTask;
  }

  Future<void> _deleteProjectionIfRequestMatches(
    String taskId,
    String requestId,
  ) async {
    final projection = await analysisProjectionRepository.loadByTaskId(taskId);
    if (projection?.analysisRequestId == requestId) {
      await analysisProjectionRepository.deleteByTaskId(taskId);
    }
  }

  Future<void> _saveProjection(
    MediaTask task,
    EngineOperationResult<EngineAnalysisSnapshotDocument> result,
  ) async {
    final snapshot = result.value;
    final existing = await analysisProjectionRepository.loadByTaskId(task.id);
    return analysisProjectionRepository.upsert(
      EngineAnalysisProjection(
        taskId: task.id,
        clientFileId: task.id,
        engineSessionId: result.sessionId,
        analysisId: snapshot.analysisId,
        revision: snapshot.analysisRevision,
        schemaVersion: snapshot.schemaVersion,
        snapshotJson: jsonEncode(snapshot.raw),
        validityStatus: snapshot.validity.status.name,
        analysisWorkId: existing?.analysisWorkId,
        analysisRequestId: existing?.analysisRequestId,
        analysisQueuePosition: existing?.analysisQueuePosition,
        analysisQueueRevision: existing?.analysisQueueRevision,
        lastEventSequence: result.sequence,
        updatedAt: now(),
      ),
    );
  }

  Future<MediaTask?> _clearConfigurationForNewAnalysis(
    MediaTask submittedTask,
  ) async {
    if (submittedTask.config.engineConfiguration == null) {
      return submittedTask;
    }
    final latestTask = await repository.loadTaskById(submittedTask.id);
    if (latestTask == null) {
      return null;
    }
    if (!_isSameAnalysisAttempt(submittedTask, latestTask)) {
      return latestTask;
    }
    if (latestTask.config.engineConfiguration == null) {
      return latestTask;
    }

    final updatedTask = latestTask.copyWith(
      config: latestTask.config.copyWith(engineConfiguration: null),
    );
    await repository.saveTask(updatedTask);
    return updatedTask;
  }

  void _validateAnalysisPair(
    EngineAnalysisResponseDocument response,
    EngineAnalysisSnapshotDocument snapshot,
    String requestId,
  ) {
    if (response.analysisId != snapshot.analysisId ||
        response.analysisRevision != snapshot.analysisRevision ||
        response.taskMode != snapshot.taskMode) {
      throw EngineGatewayException(
        kind: EngineGatewayFailureKind.protocol,
        message: 'analysis response and snapshot identity do not match',
        requestId: requestId,
      );
    }
  }

  Future<MediaTask?> _markAnalysisDocumentFailure(
    MediaTask expectedTask,
    EngineAnalysisResponseDocument response,
  ) {
    final errorCode = response.errorCode;
    return _markFailure(
      expectedTask.id,
      expectedTask: expectedTask,
      code: _taskFailureCode(errorCode),
      message: _userMessage(errorCode),
      technicalSummary:
          response.errorMessage ?? errorCode ?? 'FLL analysis failed',
      retryable: response.errorRetryable ?? true,
      sourceMissing: errorCode == 'MEDIA_FILE_NOT_FOUND',
    );
  }

  Future<MediaTask?> _markEngineFailure(
    String taskId,
    EngineWorkerException error, {
    required MediaTask expectedTask,
  }) {
    return _markFailure(
      taskId,
      expectedTask: expectedTask,
      code: _taskFailureCode(error.engineCode),
      message: _userMessage(error.engineCode),
      technicalSummary: error.toString(),
      retryable: error.retryable,
      sourceMissing: error.engineCode == 'MEDIA_FILE_NOT_FOUND',
    );
  }

  Future<MediaTask?> _markFailure(
    String taskId, {
    required MediaTask expectedTask,
    required TaskFailureCode code,
    required String message,
    required String technicalSummary,
    required bool retryable,
    bool sourceMissing = false,
  }) async {
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return null;
    }
    if (!_isSameAnalysisAttempt(expectedTask, task)) {
      return task;
    }
    if (sourceMissing) {
      final missingTask = task.markMissingSource();
      await repository.saveTask(missingTask);
      return missingTask;
    }
    final occurredAt = now().millisecondsSinceEpoch;
    final updatedTask = task.markAnalysisFailed(
      TaskFailure(
        stage: TaskFailureStage.analysis,
        code: code,
        userMessage: message,
        technicalSummary: technicalSummary,
        occurredAt: occurredAt,
        retryable: retryable,
      ),
    );
    await repository.saveTask(updatedTask);
    return updatedTask;
  }

  bool _isSameAnalysisAttempt(MediaTask submitted, MediaTask latest) {
    if ((latest.status != TaskStatus.awaitAnalysis &&
            latest.status != TaskStatus.analysisQueued &&
            latest.status != TaskStatus.analyzing) ||
        latest.inputPath != submitted.inputPath ||
        latest.mediaKind != submitted.mediaKind ||
        latest.purpose != submitted.purpose) {
      return false;
    }
    final submittedFingerprint = submitted.sourceFileFingerprint;
    final latestFingerprint = latest.sourceFileFingerprint;
    if (submittedFingerprint == null || latestFingerprint == null) {
      return submittedFingerprint == null && latestFingerprint == null;
    }
    return submittedFingerprint.isSameAs(latestFingerprint);
  }

  TaskFailureCode _taskFailureCode(String? engineCode) {
    return switch (engineCode) {
      'MEDIA_FILE_NOT_FOUND' ||
      'MEDIA_PERMISSION_DENIED' ||
      'ANALYSIS_SOURCE_CHANGED' => TaskFailureCode.sourceUnavailable,
      'MEDIA_INVALID_FORMAT' => TaskFailureCode.corruptMedia,
      'NATIVE_LIBRARY_UNAVAILABLE' =>
        TaskFailureCode.analysisRuntimeUnavailable,
      _ => TaskFailureCode.analysisFailed,
    };
  }

  String _userMessage(String? engineCode) {
    return switch (engineCode) {
      'MEDIA_FILE_NOT_FOUND' => '源文件不存在，请重新选择文件。',
      'MEDIA_PERMISSION_DENIED' => '无法读取源文件，请检查文件权限。',
      'ANALYSIS_SOURCE_CHANGED' => '源文件已发生变化，请重新分析。',
      'MEDIA_INVALID_FORMAT' => '文件格式无效或文件已经损坏。',
      'NATIVE_LIBRARY_UNAVAILABLE' => '媒体引擎缺少必要的本机组件。',
      _ => '媒体分析失败，请确认文件可以正常读取后重试。',
    };
  }
}
