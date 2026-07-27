import 'dart:async';
import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/engine/engine_media_display_projection_mapper.dart';
import 'package:framelean/application/services/engine/engine_task_mode_mapper.dart';
import 'package:framelean/domain/library.dart';

/// Projects FEngine's sequenced authoritative lifecycle into local product
/// tasks. Product ordering remains Client-owned; execution ownership does not.
final class EngineLifecycleCoordinator {
  EngineLifecycleCoordinator({
    required this.gateway,
    required this.taskRepository,
    required this.projectionRepository,
    DateTime Function()? now,
    this.onProjectionChanged,
    this.onAnalysisRecovered,
  }) : now = now ?? DateTime.now;

  final EngineLifecycleGateway gateway;
  final MediaTaskRepository taskRepository;
  final EngineAnalysisProjectionRepository projectionRepository;
  final DateTime Function() now;
  final FutureOr<void> Function(String taskId)? onProjectionChanged;
  final FutureOr<void> Function(String taskId)? onAnalysisRecovered;

  StreamSubscription<EngineWorkEvent>? _subscription;
  Future<void> _serial = Future<void>.value();

  Future<void> start() async {
    if (_subscription != null) {
      return;
    }
    await gateway.connect();
    _subscription = gateway.events.listen((event) {
      _serial = _serial.then((_) async {
        if (event.type == EngineWorkEventType.sequenceGap) {
          await _applySnapshot(await gateway.getEngineSnapshot());
          return;
        }
        await _applyEvent(event);
      });
    });
    await reconcile();
  }

  Future<void> reconcile() async {
    final result = await gateway.getEngineSnapshot();
    _serial = _serial.then((_) => _applySnapshot(result));
    await _serial;
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _serial;
  }

  Future<void> _applyEvent(EngineWorkEvent event) async {
    final taskId = event.clientTaskId;
    if (taskId == null || taskId.isEmpty) {
      return;
    }
    final task = await taskRepository.loadTaskById(taskId);
    if (task == null) {
      return;
    }
    final projection = await projectionRepository.loadByTaskId(taskId);
    if (projection == null ||
        ((event.sessionId == null ||
                event.sessionId == projection.engineSessionId) &&
            event.sequence <= projection.lastEventSequence)) {
      return;
    }

    var updated = task;
    switch (event.type) {
      case EngineWorkEventType.queued:
        if (event.queueKind == EngineQueueKind.analysis) {
          updated = task.markAnalysisQueued();
        }
      case EngineWorkEventType.started:
        if (event.queueKind == EngineQueueKind.analysis) {
          updated = task.status == TaskStatus.awaitAnalysis
              ? task.markAnalysisQueued().markAnalyzing()
              : task.markAnalyzing();
        }
      case EngineWorkEventType.executionStarted:
        updated = task.copyWith(
          status: TaskStatus.running,
          startedAt: task.startedAt ?? now().millisecondsSinceEpoch,
          clearFailure: true,
        );
      case EngineWorkEventType.executionProgress:
        final durationUs = task.analysisResult?.durationMs == null
            ? null
            : task.analysisResult!.durationMs! * 1000;
        final mediaTimeUs = event.progress?.mediaTimeUs;
        updated = task
            .copyWith(status: TaskStatus.running)
            .withProgress(
              durationUs == null || durationUs <= 0 || mediaTimeUs == null
                  ? task.progress
                  : mediaTimeUs / durationUs,
            );
      case EngineWorkEventType.executionPaused:
        updated = event.pauseReason == EngineExecutionPauseReason.preemption
            ? task.markPreempted()
            : task.markPaused();
      case EngineWorkEventType.executionResumed:
        updated = task.markResuming();
      case EngineWorkEventType.executionStateChanged:
        updated = switch (event.executionState) {
          EngineExecutionState.preempting => task.markPreempting(),
          EngineExecutionState.preempted => task.markPreempted(),
          EngineExecutionState.resuming => task.markResuming(),
          EngineExecutionState.pauseRequested => task.copyWith(
            status: TaskStatus.running,
          ),
          EngineExecutionState.paused => task.markPaused(),
          EngineExecutionState.running => task.copyWith(
            status: TaskStatus.running,
          ),
          _ => task,
        };
      case EngineWorkEventType.warning:
      case EngineWorkEventType.sequenceGap:
        break;
      case EngineWorkEventType.executionSubmitted:
        updated = task.markExecutionQueued();
      case EngineWorkEventType.executionCompleted:
        updated = task
            .copyWith(outputPath: event.outputPath)
            .markCompleted(completedAt: now().millisecondsSinceEpoch);
      case EngineWorkEventType.executionFailed:
        updated = task.markFailed(
          TaskFailure(
            stage: TaskFailureStage.processing,
            code: TaskFailureCode.processExitedAbnormally,
            userMessage: '媒体执行失败，请检查任务日志后重试。',
            technicalSummary: [
              event.engineCode,
              event.message,
            ].whereType<String>().join(': '),
            occurredAt: now().millisecondsSinceEpoch,
            retryable: true,
          ),
        );
      case EngineWorkEventType.executionCancelled:
        updated = task.markCancelled();
      case EngineWorkEventType.completed:
      case EngineWorkEventType.failed:
      case EngineWorkEventType.snapshot:
      case EngineWorkEventType.queueOrderApplied:
      case EngineWorkEventType.queueOrderConflict:
        break;
    }
    if (updated.status != task.status || updated.progress != task.progress) {
      await taskRepository.saveTask(updated);
    }
    await projectionRepository.upsert(
      projection.copyWith(
        engineSessionId: event.sessionId,
        analysisWorkId: event.queueKind == EngineQueueKind.analysis
            ? event.workId
            : null,
        analysisQueuePosition: event.queueKind == EngineQueueKind.analysis
            ? event.queuePosition
            : null,
        analysisQueueRevision: event.queueKind == EngineQueueKind.analysis
            ? event.queueRevision
            : null,
        executionId: event.executionId,
        executionQueuePosition:
            event.queueKind == EngineQueueKind.execution ||
                event.type == EngineWorkEventType.executionSubmitted
            ? event.queuePosition
            : null,
        executionQueueRevision:
            event.queueKind == EngineQueueKind.execution ||
                event.type == EngineWorkEventType.executionSubmitted
            ? event.queueRevision
            : null,
        executionState: event.executionState?.name,
        pauseReason: event.pauseReason?.name,
        clearPauseReason:
            event.type == EngineWorkEventType.executionStarted ||
            event.type == EngineWorkEventType.executionResumed,
        preemptedByExecutionId: event.preemptedByExecutionId,
        clearPreemptedByExecutionId:
            event.type == EngineWorkEventType.executionStarted ||
            event.type == EngineWorkEventType.executionResumed,
        resumeDepth: event.resumeDepth,
        mediaTimeUs: event.progress?.mediaTimeUs,
        processedBytes: event.progress?.processedBytes,
        lastEventSequence: event.sequence,
        updatedAt: now(),
      ),
    );
    await onProjectionChanged?.call(taskId);
  }

  Future<void> _applySnapshot(
    EngineOperationResult<EngineStateSnapshot> result,
  ) async {
    final snapshot = result.value;
    final tasks = await taskRepository.loadAllTasks();
    final analysisWaiting = {
      for (final entry in snapshot.analysisQueue) entry.clientTaskId: entry,
    };
    final activeAnalysis = snapshot.activeAnalysis;
    final terminalAnalyses = {
      for (final entry in snapshot.terminalAnalyses) entry.clientTaskId: entry,
    };
    final scheduled =
        <String, ({EngineScheduledExecution entry, TaskStatus status})>{
          for (final entry in snapshot.executionLane.activeExecutions)
            entry.executionId: (entry: entry, status: TaskStatus.running),
          for (final entry in snapshot.executionLane.normalWaiting)
            entry.executionId: (
              entry: entry,
              status: TaskStatus.executionQueued,
            ),
          for (final entry in snapshot.executionLane.videoResumeStack)
            entry.executionId: (entry: entry, status: TaskStatus.preempted),
          for (final entry in snapshot.executionLane.auxiliaryResumeStack)
            entry.executionId: (entry: entry, status: TaskStatus.preempted),
          for (final entry in snapshot.executionLane.userPaused)
            entry.executionId: (entry: entry, status: TaskStatus.paused),
        };
    final terminalExecutions = {
      for (final entry in snapshot.terminalExecutions) entry.executionId: entry,
    };

    for (final task in tasks) {
      final waiting = analysisWaiting[task.id];
      final isActiveAnalysis = activeAnalysis?.clientTaskId == task.id;
      final terminalAnalysis = terminalAnalyses[task.id];
      var projection = await projectionRepository.loadByTaskId(task.id);
      if (projection == null && (waiting != null || isActiveAnalysis)) {
        projection = EngineAnalysisProjection(
          taskId: task.id,
          clientFileId: task.id,
          engineSessionId: result.sessionId,
          lastEventSequence: 0,
          updatedAt: now(),
        );
      }
      if (projection == null ||
          (result.sessionId == projection.engineSessionId &&
              result.sequence < projection.lastEventSequence)) {
        continue;
      }
      final authoritativeProjection = projection;
      var updated = task;
      final missingProjectedAnalysis =
          !isActiveAnalysis &&
          waiting == null &&
          terminalAnalysis == null &&
          authoritativeProjection.analysisRequestId != null &&
          (task.status == TaskStatus.analysisQueued ||
              task.status == TaskStatus.analyzing);
      if (isActiveAnalysis) {
        updated = task.status == TaskStatus.awaitAnalysis
            ? task.markAnalysisQueued().markAnalyzing()
            : task.markAnalyzing();
      } else if (waiting != null && task.status == TaskStatus.awaitAnalysis) {
        updated = task.markAnalysisQueued();
      } else if (terminalAnalysis != null &&
          (task.status == TaskStatus.analysisQueued ||
              task.status == TaskStatus.analyzing)) {
        if (terminalAnalysis.succeeded) {
          await _recoverCompletedAnalysis(
            task,
            authoritativeProjection,
            terminalAnalysis,
          );
          continue;
        }
        updated = task.markAnalysisFailed(
          TaskFailure(
            stage: TaskFailureStage.analysis,
            code: TaskFailureCode.analysisFailed,
            userMessage: '媒体分析失败，请确认文件可以正常读取后重试。',
            technicalSummary: [
              terminalAnalysis.engineCode,
              terminalAnalysis.message,
            ].whereType<String>().join(': '),
            occurredAt: now().millisecondsSinceEpoch,
            retryable: true,
          ),
        );
      } else if (missingProjectedAnalysis) {
        updated = task.markAnalysisFailed(
          TaskFailure(
            stage: TaskFailureStage.recovery,
            code: TaskFailureCode.applicationInterrupted,
            userMessage: '引擎中已不存在该分析，请重试分析。',
            technicalSummary:
                'Analysis ${authoritativeProjection.analysisWorkId ?? authoritativeProjection.analysisRequestId} was absent from the authoritative snapshot',
            occurredAt: now().millisecondsSinceEpoch,
            retryable: true,
          ),
        );
      }

      final execution = authoritativeProjection.executionId == null
          ? null
          : scheduled[authoritativeProjection.executionId!];
      final terminalExecution = authoritativeProjection.executionId == null
          ? null
          : terminalExecutions[authoritativeProjection.executionId!];
      final missingProjectedExecution =
          execution == null &&
          terminalExecution == null &&
          _isProjectedExecutionNonTerminal(
            authoritativeProjection.executionState,
          );
      if (execution != null) {
        updated = updated.copyWith(status: execution.status);
      } else if (terminalExecution != null) {
        updated = switch (terminalExecution.state) {
          EngineExecutionState.completed =>
            updated
                .copyWith(outputPath: terminalExecution.outputPath)
                .markCompleted(completedAt: now().millisecondsSinceEpoch),
          EngineExecutionState.failed => updated.markFailed(
            TaskFailure(
              stage: TaskFailureStage.processing,
              code: TaskFailureCode.processExitedAbnormally,
              userMessage: '媒体执行失败，请检查任务日志后重试。',
              technicalSummary: [
                terminalExecution.engineCode,
                terminalExecution.message,
              ].whereType<String>().join(': '),
              occurredAt: now().millisecondsSinceEpoch,
              retryable: true,
            ),
          ),
          EngineExecutionState.cancelled => updated.markCancelled(),
          _ => updated,
        };
      } else if (missingProjectedExecution) {
        updated = updated.markFailed(
          TaskFailure(
            stage: TaskFailureStage.recovery,
            code: TaskFailureCode.applicationInterrupted,
            userMessage: '引擎中已不存在该执行，请重新开始任务。',
            technicalSummary:
                'Execution ${authoritativeProjection.executionId} was absent from the authoritative snapshot',
            occurredAt: now().millisecondsSinceEpoch,
            retryable: true,
          ),
        );
      }
      if (updated.status != task.status) {
        await taskRepository.saveTask(updated);
      }

      final scheduledEntry = execution?.entry;
      final executionId = authoritativeProjection.executionId;
      final normalWaitingIndex = executionId == null
          ? -1
          : snapshot.executionLane.normalWaiting.indexWhere(
              (entry) => entry.executionId == executionId,
            );
      final resumeStack =
          scheduledEntry?.resourcePool == EngineExecutionResourcePool.video
          ? snapshot.executionLane.videoResumeStack
          : snapshot.executionLane.auxiliaryResumeStack;
      final resumeStackIndex = executionId == null
          ? -1
          : resumeStack.indexWhere((entry) => entry.executionId == executionId);
      final isActiveExecution =
          executionId != null &&
          snapshot.executionLane.activeExecutions.any(
            (entry) => entry.executionId == executionId,
          );
      await projectionRepository.upsert(
        authoritativeProjection.copyWith(
          engineSessionId: result.sessionId,
          analysisWorkId: isActiveAnalysis
              ? activeAnalysis?.workId
              : waiting?.workId,
          clearAnalysisWorkId: !isActiveAnalysis && waiting == null,
          analysisQueuePosition: isActiveAnalysis ? 0 : waiting?.queuePosition,
          clearAnalysisQueuePosition: !isActiveAnalysis && waiting == null,
          analysisQueueRevision: snapshot.analysisQueueRevision,
          executionId: scheduledEntry?.executionId,
          clearExecutionId: missingProjectedExecution,
          executionQueuePosition: isActiveExecution
              ? 0
              : normalWaitingIndex >= 0
              ? normalWaitingIndex + 1
              : null,
          clearExecutionQueuePosition:
              !isActiveExecution && normalWaitingIndex < 0,
          executionQueueRevision: snapshot.executionLane.queueRevision,
          executionState:
              terminalExecution?.state.name ?? scheduledEntry?.state.name,
          clearExecutionState: missingProjectedExecution,
          pauseReason: scheduledEntry?.pauseReason?.name,
          clearPauseReason:
              scheduledEntry == null || scheduledEntry.pauseReason == null,
          preemptedByExecutionId: scheduledEntry?.preemptedByExecutionId,
          clearPreemptedByExecutionId:
              scheduledEntry == null ||
              scheduledEntry.preemptedByExecutionId == null,
          resumeDepth: resumeStackIndex < 0
              ? 0
              : resumeStack.length - resumeStackIndex,
          lastEventSequence: result.sequence,
          updatedAt: now(),
        ),
      );
      await onProjectionChanged?.call(task.id);
    }
  }

  Future<void> _recoverCompletedAnalysis(
    MediaTask task,
    EngineAnalysisProjection projection,
    EngineTerminalAnalysisSnapshot terminal,
  ) async {
    try {
      final result = await gateway.getAnalysisSnapshot(terminal.analysisId);
      final snapshot = result.value;
      if (snapshot.analysisId != terminal.analysisId ||
          snapshot.analysisRevision != terminal.analysisRevision ||
          snapshot.taskMode != engineTaskModeForMediaTask(task) ||
          !snapshot.validity.isValid) {
        throw const EngineGatewayException(
          kind: EngineGatewayFailureKind.protocol,
          message: 'terminal analysis and recovered Snapshot do not match',
        );
      }
      final updated = task
          .withAnalysisResult(
            const EngineMediaDisplayProjectionMapper().map(snapshot),
          )
          .markAnalysisReady();
      await taskRepository.saveTask(updated);
      await projectionRepository.upsert(
        EngineAnalysisProjection(
          taskId: task.id,
          clientFileId: terminal.clientFileId,
          engineSessionId: result.sessionId,
          analysisId: snapshot.analysisId,
          revision: snapshot.analysisRevision,
          schemaVersion: snapshot.schemaVersion,
          snapshotJson: jsonEncode(snapshot.raw),
          validityStatus: snapshot.validity.status.name,
          analysisWorkId: terminal.workId,
          analysisRequestId: projection.analysisRequestId,
          analysisQueueRevision: projection.analysisQueueRevision,
          executionId: projection.executionId,
          executionRequestId: projection.executionRequestId,
          executionQueueRevision: projection.executionQueueRevision,
          executionState: projection.executionState,
          lastEventSequence: result.sequence,
          updatedAt: now(),
        ),
      );
      await onAnalysisRecovered?.call(task.id);
      await onProjectionChanged?.call(task.id);
    } on Object catch (error) {
      await taskRepository.saveTask(
        task.markAnalysisFailed(
          TaskFailure(
            stage: TaskFailureStage.recovery,
            code: TaskFailureCode.applicationInterrupted,
            userMessage: '分析已结束，但恢复配置快照失败，请重试分析。',
            technicalSummary: error.toString(),
            occurredAt: now().millisecondsSinceEpoch,
            retryable: true,
          ),
        ),
      );
      await onProjectionChanged?.call(task.id);
    }
  }

  bool _isProjectedExecutionNonTerminal(String? state) {
    return state != null &&
        state != EngineExecutionState.completed.name &&
        state != EngineExecutionState.failed.name &&
        state != EngineExecutionState.cancelled.name;
  }
}
