import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_execution_output_planner.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/use_cases/media_tasks/load_engine_analysis_snapshot_use_case.dart';
import 'package:framelean/domain/library.dart';
import 'package:uuid/uuid.dart';

enum EngineExecutionDispatchOutcome {
  submitted,
  notFound,
  notReady,
  notEngineConfigured,
  alreadySubmitting,
  stale,
  failed,
}

final class EngineExecutionDispatchResult {
  const EngineExecutionDispatchResult({
    required this.outcome,
    this.task,
    this.submission,
    this.requestedOutputPath,
    this.message,
  });

  final EngineExecutionDispatchOutcome outcome;
  final MediaTask? task;
  final EngineExecutionSubmission? submission;
  final String? requestedOutputPath;
  final String? message;
}

abstract interface class EngineExecutionSubmitter {
  Future<EngineExecutionDispatchResult> call(
    String taskId, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  });
}

abstract interface class EngineExecutionBatchSubmitter {
  Future<List<EngineExecutionDispatchResult>> submitBatch(
    Iterable<String> taskIds, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  });
}

final class _PreparedEngineExecution {
  const _PreparedEngineExecution({
    required this.task,
    required this.projection,
    required this.request,
    required this.requestedOutputPath,
  });

  final MediaTask task;
  final EngineAnalysisProjection projection;
  final EngineExecutionRequest request;
  final String requestedOutputPath;
}

/// Validates and submits an Engine-configured product task.
///
/// FEngine owns the external work queue and FLL owns configuration validation,
/// Runtime Task creation, scheduling, and output publication. This use case
/// only projects submission failures back into the Client task model.
class SubmitEngineExecutionUseCase
    implements EngineExecutionSubmitter, EngineExecutionBatchSubmitter {
  SubmitEngineExecutionUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
    required this.settingsRepository,
    required this.readEngineGateway,
    this.outputPlanner = const EngineExecutionOutputPlanner(),
    this.onTaskFailed,
    int Function()? nowMilliseconds,
    String Function()? createRequestId,
  }) : nowMilliseconds =
           nowMilliseconds ?? (() => DateTime.now().millisecondsSinceEpoch),
       createRequestId = createRequestId ?? const Uuid().v4;

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;
  final AppSettingsRepository settingsRepository;
  final Future<EngineGateway> Function() readEngineGateway;
  final EngineExecutionOutputPlanner outputPlanner;
  final Future<void> Function(MediaTask task)? onTaskFailed;
  final int Function() nowMilliseconds;
  final String Function() createRequestId;
  final Set<String> _submittingTaskIds = <String>{};

  @override
  Future<EngineExecutionDispatchResult> call(
    String taskId, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  }) async {
    if (!_submittingTaskIds.add(taskId)) {
      return const EngineExecutionDispatchResult(
        outcome: EngineExecutionDispatchOutcome.alreadySubmitting,
        message: '任务正在提交到引擎',
      );
    }

    try {
      final preparation = await _prepare(taskId, priority);
      final earlyResult = preparation.result;
      if (earlyResult != null) {
        return earlyResult;
      }
      return _submitPrepared(preparation.prepared!);
    } finally {
      _submittingTaskIds.remove(taskId);
    }
  }

  @override
  Future<List<EngineExecutionDispatchResult>> submitBatch(
    Iterable<String> taskIds, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  }) async {
    final orderedIds = <String>[];
    final seen = <String>{};
    for (final taskId in taskIds) {
      if (seen.add(taskId)) {
        orderedIds.add(taskId);
      }
    }
    final reserved = <String>[];
    final results = <String, EngineExecutionDispatchResult>{};
    final prepared = <_PreparedEngineExecution>[];
    try {
      for (final taskId in orderedIds) {
        if (!_submittingTaskIds.add(taskId)) {
          results[taskId] = const EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.alreadySubmitting,
            message: '任务正在提交到引擎',
          );
          continue;
        }
        reserved.add(taskId);
        final preparation = await _prepare(taskId, priority);
        if (preparation.result case final result?) {
          results[taskId] = result;
        } else {
          prepared.add(preparation.prepared!);
        }
      }
      if (prepared.isEmpty) {
        return [for (final id in orderedIds) results[id]!];
      }

      for (final item in prepared) {
        await _markSubmitting(item);
      }
      try {
        final gateway = await readEngineGateway();
        if (gateway is! EngineBatchGateway) {
          throw const EngineGatewayException(
            kind: EngineGatewayFailureKind.protocol,
            message: '当前 FEngine gateway 不支持原子批量执行提交',
          );
        }
        final operation = await gateway.submitExecutionBatch(
          prepared.map((item) => item.request).toList(growable: false),
        );
        final receipts = {
          for (final item in operation.value.items) item.clientTaskId: item,
        };
        if (receipts.length != prepared.length ||
            prepared.any((item) => !receipts.containsKey(item.task.id))) {
          throw const EngineGatewayException(
            kind: EngineGatewayFailureKind.protocol,
            message: 'FEngine 批量执行回执与提交任务集合不一致',
          );
        }
        for (final item in prepared) {
          final receipt = receipts[item.task.id]!;
          final latest = await repository.loadTaskById(item.task.id);
          if (latest == null || !_sameExecutionGeneration(item.task, latest)) {
            results[item.task.id] = EngineExecutionDispatchResult(
              outcome: EngineExecutionDispatchOutcome.stale,
              task: latest,
              requestedOutputPath: item.requestedOutputPath,
              message: '任务或分析结果已发生变化，未覆盖 Client 最新状态',
            );
            continue;
          }
          final projection = await analysisProjectionRepository.loadByTaskId(
            item.task.id,
          );
          if (projection == null) {
            results[item.task.id] = await _recordFailure(
              originalTask: item.task,
              failure: _analysisUnavailableFailure(
                'Engine projection disappeared while accepting execution batch',
              ),
            );
            continue;
          }
          await analysisProjectionRepository.upsert(
            projection.copyWith(
              engineSessionId: operation.sessionId,
              executionRequestId: receipt.childRequestId,
              executionState: 'submitting',
              lastEventSequence: operation.sequence,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMilliseconds()),
            ),
          );
          final queuedTask = latest.markExecutionQueued();
          await repository.saveTask(queuedTask);
          results[item.task.id] = EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.submitted,
            task: queuedTask,
            requestedOutputPath: item.requestedOutputPath,
            message: '任务已作为原子批次提交到 FEngine',
          );
        }
      } on EngineWorkerException catch (error) {
        for (final item in prepared) {
          await _markSubmissionRejected(item.task.id);
          results[item.task.id] = await _recordFailure(
            originalTask: item.task,
            failure: _workerFailure(error),
          );
        }
      } on EngineGatewayException catch (error) {
        final definitive =
            error.kind != EngineGatewayFailureKind.connection &&
            error.kind != EngineGatewayFailureKind.closed;
        for (final item in prepared) {
          if (definitive) {
            await _markSubmissionRejected(item.task.id);
          }
          results[item.task.id] = await _recordFailure(
            originalTask: item.task,
            failure: _gatewayFailure(error),
          );
        }
      } on Object catch (error) {
        final failure = _gatewayFailure(
          EngineGatewayException(
            kind: EngineGatewayFailureKind.connection,
            message: error.toString(),
          ),
        );
        for (final item in prepared) {
          results[item.task.id] = await _recordFailure(
            originalTask: item.task,
            failure: failure,
          );
        }
      }
      return [for (final id in orderedIds) results[id]!];
    } finally {
      _submittingTaskIds.removeAll(reserved);
    }
  }

  Future<
    ({
      _PreparedEngineExecution? prepared,
      EngineExecutionDispatchResult? result,
    })
  >
  _prepare(String taskId, EngineWorkPriority priority) async {
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return (
        prepared: null,
        result: const EngineExecutionDispatchResult(
          outcome: EngineExecutionDispatchOutcome.notFound,
          message: '找不到任务',
        ),
      );
    }
    final reference = task.config.engineConfiguration;
    if (reference == null) {
      return (
        prepared: null,
        result: EngineExecutionDispatchResult(
          outcome: EngineExecutionDispatchOutcome.notEngineConfigured,
          task: task,
          message: '任务没有可提交的引擎配置',
        ),
      );
    }
    if (!task.canStartExecution) {
      return (
        prepared: null,
        result: EngineExecutionDispatchResult(
          outcome: EngineExecutionDispatchOutcome.notReady,
          task: task,
          message: '当前任务状态不允许提交到引擎',
        ),
      );
    }

    final snapshot = await LoadEngineAnalysisSnapshotUseCase(
      analysisProjectionRepository: analysisProjectionRepository,
    ).call(task);
    if (snapshot == null ||
        snapshot.analysisId != reference.analysisId ||
        snapshot.analysisRevision != reference.analysisRevision) {
      return (
        prepared: null,
        result: await _recordFailure(
          originalTask: task,
          failure: _analysisUnavailableFailure(
            'Engine AnalysisSnapshot 不存在、已失效或与任务 revision 不一致',
          ),
        ),
      );
    }
    final candidate = snapshot.executionCandidates[reference.candidateId];
    if (candidate == null) {
      return (
        prepared: null,
        result: await _recordFailure(
          originalTask: task,
          failure: _configurationFailure(
            '保存的 candidate_id 不属于当前 AnalysisSnapshot',
          ),
        ),
      );
    }
    late final EngineConfigurationSelection selection;
    try {
      selection = engineConfigurationSelectionFromEncoded(
        reference.selectionJson,
      );
    } on EngineConfigurationSelectionException catch (error) {
      return (
        prepared: null,
        result: await _recordFailure(
          originalTask: task,
          failure: _configurationFailure(error.toString()),
        ),
      );
    }
    if (selection.candidateId != reference.candidateId ||
        engineConfigurationSelectionMode(selection) !=
            reference.selectionMode) {
      return (
        prepared: null,
        result: await _recordFailure(
          originalTask: task,
          failure: _configurationFailure(
            '保存的 selection 与 candidate_id 或 selection_mode 不一致',
          ),
        ),
      );
    }
    late final String requestedOutputPath;
    try {
      requestedOutputPath = outputPlanner.buildRequestedPath(
        task: task,
        settings: await settingsRepository.loadSettings(),
        outputContainer: candidate.outputContainer,
      );
    } on EngineExecutionOutputPlanException catch (error) {
      return (
        prepared: null,
        result: await _recordFailure(
          originalTask: task,
          failure: _outputFailure(error.toString()),
        ),
      );
    }
    final projection = await analysisProjectionRepository.loadByTaskId(task.id);
    if (projection == null) {
      return (
        prepared: null,
        result: await _recordFailure(
          originalTask: task,
          failure: _analysisUnavailableFailure(
            'Engine projection disappeared before execution submission',
          ),
        ),
      );
    }
    final requestId = projection.executionState == 'submitting'
        ? projection.executionRequestId ?? createRequestId()
        : createRequestId();
    return (
      prepared: _PreparedEngineExecution(
        task: task,
        projection: projection,
        request: EngineExecutionRequest(
          clientTaskId: task.id,
          analysisId: reference.analysisId,
          expectedRevision: reference.analysisRevision,
          selection: selection,
          requestedOutputPath: requestedOutputPath,
          collisionPolicy: EngineOutputCollisionPolicy.generateUnique,
          priority: priority,
          requestId: requestId,
        ),
        requestedOutputPath: requestedOutputPath,
      ),
      result: null,
    );
  }

  Future<void> _markSubmitting(_PreparedEngineExecution item) {
    return analysisProjectionRepository.upsert(
      item.projection.copyWith(
        executionRequestId: item.request.requestId,
        executionState: 'submitting',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMilliseconds()),
      ),
    );
  }

  Future<EngineExecutionDispatchResult> _submitPrepared(
    _PreparedEngineExecution item,
  ) async {
    await _markSubmitting(item);
    try {
      final operation = await (await readEngineGateway()).submitExecution(
        item.request,
      );
      final latest = await repository.loadTaskById(item.task.id);
      if (latest == null || !_sameExecutionGeneration(item.task, latest)) {
        return EngineExecutionDispatchResult(
          outcome: EngineExecutionDispatchOutcome.stale,
          task: latest,
          submission: operation.value,
          requestedOutputPath: item.requestedOutputPath,
          message: '任务或分析结果已发生变化，未覆盖 Client 最新状态',
        );
      }
      final projection = await analysisProjectionRepository.loadByTaskId(
        item.task.id,
      );
      if (projection == null) {
        return _recordFailure(
          originalTask: item.task,
          failure: _analysisUnavailableFailure(
            'Engine projection disappeared while submitting execution',
          ),
        );
      }
      await analysisProjectionRepository.upsert(
        projection.copyWith(
          engineSessionId: operation.sessionId,
          executionId: operation.value.executionId,
          executionQueuePosition: operation.value.queuePosition,
          executionQueueRevision: operation.value.queueRevision,
          executionState: operation.value.state.name,
          lastEventSequence: operation.sequence,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMilliseconds()),
        ),
      );
      final queuedTask = latest.markExecutionQueued();
      await repository.saveTask(queuedTask);
      return EngineExecutionDispatchResult(
        outcome: EngineExecutionDispatchOutcome.submitted,
        task: queuedTask,
        submission: operation.value,
        requestedOutputPath: item.requestedOutputPath,
        message: '任务已提交到 FEngine',
      );
    } on EngineWorkerException catch (error) {
      await _markSubmissionRejected(item.task.id);
      return _recordFailure(
        originalTask: item.task,
        failure: _workerFailure(error),
      );
    } on EngineGatewayException catch (error) {
      if (error.kind != EngineGatewayFailureKind.connection &&
          error.kind != EngineGatewayFailureKind.closed) {
        await _markSubmissionRejected(item.task.id);
      }
      return _recordFailure(
        originalTask: item.task,
        failure: _gatewayFailure(error),
      );
    } on Object catch (error) {
      return _recordFailure(
        originalTask: item.task,
        failure: _gatewayFailure(
          EngineGatewayException(
            kind: EngineGatewayFailureKind.connection,
            message: error.toString(),
          ),
        ),
      );
    }
  }

  Future<void> _markSubmissionRejected(String taskId) async {
    final projection = await analysisProjectionRepository.loadByTaskId(taskId);
    if (projection == null) {
      return;
    }
    await analysisProjectionRepository.upsert(
      projection.copyWith(
        executionState: 'submission_rejected',
        clearExecutionRequestId: true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMilliseconds()),
      ),
    );
  }

  Future<EngineExecutionDispatchResult> _recordFailure({
    required MediaTask originalTask,
    required TaskFailure failure,
  }) async {
    final latest = await repository.loadTaskById(originalTask.id);
    if (latest == null) {
      return const EngineExecutionDispatchResult(
        outcome: EngineExecutionDispatchOutcome.notFound,
        message: '任务已被删除，未写入过期失败状态',
      );
    }
    if (!_sameExecutionGeneration(originalTask, latest)) {
      return EngineExecutionDispatchResult(
        outcome: EngineExecutionDispatchOutcome.stale,
        task: latest,
        message: '任务或分析结果已发生变化，未写入过期失败状态',
      );
    }

    final failedTask = latest.markFailed(failure);
    await repository.saveTask(failedTask);
    try {
      await onTaskFailed?.call(failedTask);
    } on Object {
      // Notification delivery is not part of the authoritative task result.
    }
    return EngineExecutionDispatchResult(
      outcome: EngineExecutionDispatchOutcome.failed,
      task: failedTask,
      message: failure.userMessage,
    );
  }

  TaskFailure _analysisUnavailableFailure(String technicalSummary) {
    return TaskFailure(
      stage: TaskFailureStage.analysis,
      code: TaskFailureCode.analysisRuntimeUnavailable,
      userMessage: '分析结果已失效，请重新分析后再开始。',
      technicalSummary: technicalSummary,
      occurredAt: nowMilliseconds(),
      retryable: true,
    );
  }

  TaskFailure _configurationFailure(String technicalSummary) {
    return TaskFailure(
      stage: TaskFailureStage.commandPlanning,
      code: TaskFailureCode.unsupportedConfiguration,
      userMessage: '引擎配置无效，请重新打开配置并保存。',
      technicalSummary: technicalSummary,
      occurredAt: nowMilliseconds(),
      retryable: false,
    );
  }

  TaskFailure _outputFailure(String technicalSummary) {
    return TaskFailure(
      stage: TaskFailureStage.outputPreflight,
      code: TaskFailureCode.invalidOutputPath,
      userMessage: '输出位置无法用于保存处理结果。',
      technicalSummary: technicalSummary,
      occurredAt: nowMilliseconds(),
      retryable: true,
    );
  }

  TaskFailure _workerFailure(EngineWorkerException error) {
    final code = error.engineCode;
    final technicalSummary = [?code, error.code, error.message].join(': ');
    return switch (code) {
      'ENGINE_EXECUTION_CHAIN_NOT_READY' => TaskFailure(
        stage: TaskFailureStage.processStart,
        code: TaskFailureCode.engineExecutionUnavailable,
        userMessage: 'FLL 媒体执行链尚未就绪，任务没有启动。',
        technicalSummary: technicalSummary,
        occurredAt: nowMilliseconds(),
        retryable: false,
      ),
      'ANALYSIS_SOURCE_CHANGED' => TaskFailure(
        stage: TaskFailureStage.analysis,
        code: TaskFailureCode.analysisFailed,
        userMessage: '源文件已发生变化，请重新分析后再开始。',
        technicalSummary: technicalSummary,
        occurredAt: nowMilliseconds(),
        retryable: true,
      ),
      'ANALYSIS_SNAPSHOT_EXPIRED' || 'ANALYSIS_REVISION_CONFLICT' =>
        _analysisUnavailableFailure(technicalSummary),
      'OUTPUT_CONTAINER_NOT_WRITABLE' => _outputFailure(technicalSummary),
      'INVALID_ARGUMENT' => TaskFailure(
        stage: TaskFailureStage.commandPlanning,
        code: TaskFailureCode.invalidOutputPath,
        userMessage: '引擎拒绝了执行请求中的输出参数。',
        technicalSummary: technicalSummary,
        occurredAt: nowMilliseconds(),
        retryable: false,
      ),
      _ => TaskFailure(
        stage: TaskFailureStage.processStart,
        code: TaskFailureCode.processStartFailed,
        userMessage: 'FEngine 未能接受该任务。',
        technicalSummary: technicalSummary,
        occurredAt: nowMilliseconds(),
        retryable: error.retryable,
      ),
    };
  }

  TaskFailure _gatewayFailure(EngineGatewayException error) {
    return TaskFailure(
      stage: TaskFailureStage.processStart,
      code: TaskFailureCode.processStartFailed,
      userMessage: '无法连接或调用 FEngine，任务没有启动。',
      technicalSummary: error.toString(),
      occurredAt: nowMilliseconds(),
      retryable: error.kind != EngineGatewayFailureKind.protocol,
    );
  }
}

bool _sameExecutionGeneration(MediaTask original, MediaTask latest) {
  if (original.inputPath != latest.inputPath ||
      original.mediaKind != latest.mediaKind ||
      original.purpose != latest.purpose ||
      original.status != latest.status ||
      original.analysisUpdatedAt != latest.analysisUpdatedAt ||
      !_sameSourceFingerprint(
        original.sourceFileFingerprint,
        latest.sourceFileFingerprint,
      ) ||
      original.config.outputLocationMode != latest.config.outputLocationMode ||
      original.config.outputDirectory != latest.config.outputDirectory ||
      original.config.outputFileName != latest.config.outputFileName) {
    return false;
  }
  final originalReference = original.config.engineConfiguration;
  final latestReference = latest.config.engineConfiguration;
  if (originalReference == null || latestReference == null) {
    return originalReference == latestReference;
  }
  return originalReference.analysisId == latestReference.analysisId &&
      originalReference.analysisRevision == latestReference.analysisRevision &&
      originalReference.candidateId == latestReference.candidateId &&
      originalReference.selectionMode == latestReference.selectionMode &&
      originalReference.selectionJson == latestReference.selectionJson;
}

bool _sameSourceFingerprint(
  SourceFileFingerprint? original,
  SourceFileFingerprint? latest,
) {
  if (original == null || latest == null) {
    return original == latest;
  }
  return original.isSameAs(latest);
}
