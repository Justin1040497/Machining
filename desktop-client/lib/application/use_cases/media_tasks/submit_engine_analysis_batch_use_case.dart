import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/engine/engine_task_mode_mapper.dart';
import 'package:framelean/domain/library.dart';

/// Atomically establishes FEngine's authoritative analysis order for one
/// already-organized import batch.
final class SubmitEngineAnalysisBatchUseCase {
  const SubmitEngineAnalysisBatchUseCase({
    required this.repository,
    required this.projectionRepository,
    required this.readEngineGateway,
    this.now = DateTime.now,
  });

  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository projectionRepository;
  final Future<EngineLifecycleGateway> Function() readEngineGateway;
  final DateTime Function() now;

  Future<List<String>> call(Iterable<String> orderedTaskIds) async {
    final requests = <EngineAnalysisRequest>[];
    final tasks = <String, MediaTask>{};
    for (final taskId in orderedTaskIds) {
      if (tasks.containsKey(taskId)) {
        continue;
      }
      final task = await repository.loadTaskById(taskId);
      final fingerprint = task?.sourceFileFingerprint;
      if (task == null || !task.isAwaitingAnalysis || fingerprint == null) {
        continue;
      }
      tasks[taskId] = task;
      requests.add(
        EngineAnalysisRequest(
          clientTaskId: taskId,
          clientFileId: taskId,
          source: EngineSourceFacts(
            path: task.inputPath,
            fileSizeBytes: fingerprint.fileSize,
            modifiedTimeUnixNanos: null,
          ),
          taskMode: engineTaskModeForMediaTask(task),
        ),
      );
    }
    if (requests.isEmpty) {
      return const <String>[];
    }

    final gateway = await readEngineGateway();
    if (gateway is! EngineBatchGateway) {
      throw StateError('当前 FEngine gateway 不支持原子批量分析提交');
    }
    final connection = await gateway.connect();
    final result = await gateway.submitAnalysisBatch(requests);
    final acceptedIds = <String>[];
    for (final item in result.value.items) {
      final task = tasks[item.clientTaskId];
      if (task == null || item.queueKind != EngineQueueKind.analysis) {
        throw StateError('FEngine 返回了不属于本批次的分析队列条目');
      }
      acceptedIds.add(task.id);
      final latest = await repository.loadTaskById(task.id);
      if (latest != null && latest.status == TaskStatus.awaitAnalysis) {
        await repository.saveTask(latest.markAnalysisQueued());
      }
      final existing = await projectionRepository.loadByTaskId(task.id);
      await projectionRepository.upsert(
        (existing ??
                EngineAnalysisProjection(
                  taskId: task.id,
                  clientFileId: task.id,
                  engineSessionId: connection.sessionId,
                  lastEventSequence: 0,
                  updatedAt: now(),
                ))
            .copyWith(
              engineSessionId: connection.sessionId,
              analysisRequestId: item.childRequestId,
              analysisWorkId: item.workId,
              analysisQueuePosition: item.queuePosition,
              analysisQueueRevision: item.queueRevision,
              lastEventSequence: result.sequence,
              updatedAt: now(),
            ),
      );
    }
    if (acceptedIds.length != requests.length) {
      throw StateError('FEngine 批量分析回执缺少任务');
    }
    return acceptedIds;
  }
}
