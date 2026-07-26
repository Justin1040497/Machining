import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/workbench_order_revision_store.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/engine/task_folder_queue_projection.dart';
import 'package:framelean/domain/library.dart';

final class ApplyEngineQueueOrderUseCase {
  const ApplyEngineQueueOrderUseCase({
    required this.gateway,
    required this.projectionRepository,
    required this.orderRevisionStore,
    this.queueProjection = const TaskFolderQueueProjection(),
  });

  final EngineLifecycleGateway gateway;
  final EngineAnalysisProjectionRepository projectionRepository;
  final WorkbenchOrderRevisionStore orderRevisionStore;
  final TaskFolderQueueProjection queueProjection;

  Future<EngineQueueOrderApplied> call({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
  }) async {
    final orderRevision = await orderRevisionStore.nextRevision();
    final productOrder = queueProjection.orderedTaskIds(tasks, folders);
    final initial = await gateway.getEngineSnapshot();
    var outcome = await _apply(
      orderRevision: orderRevision,
      orderedTaskIds: productOrder,
      snapshot: initial.value,
    );
    if (outcome is EngineQueueOrderConflict) {
      final waitingTaskIds = <String>{
        ...outcome.snapshot.analysisQueue.map((entry) => entry.clientTaskId),
      };
      final waitingExecutions = outcome.snapshot.executionLane.normalWaiting
          .map((entry) => entry.executionId)
          .toSet();
      for (final taskId in productOrder) {
        final projection = await projectionRepository.loadByTaskId(taskId);
        if (projection?.executionId case final executionId?
            when waitingExecutions.contains(executionId)) {
          waitingTaskIds.add(taskId);
        }
      }
      outcome = await _apply(
        orderRevision: orderRevision,
        orderedTaskIds: productOrder
            .where(waitingTaskIds.contains)
            .toList(growable: false),
        snapshot: outcome.snapshot,
      );
    }
    if (outcome is! EngineQueueOrderApplied) {
      throw StateError('队列 revision 冲突重试后仍未收敛');
    }
    await _persistPositions(outcome);
    return outcome;
  }

  Future<EngineQueueOrderOutcome> _apply({
    required int orderRevision,
    required List<String> orderedTaskIds,
    required EngineStateSnapshot snapshot,
  }) async {
    final result = await gateway.applyQueueOrder(
      orderRevision: orderRevision,
      expectedAnalysisQueueRevision: snapshot.analysisQueueRevision,
      expectedExecutionQueueRevision: snapshot.executionLane.queueRevision,
      orderedTaskIds: orderedTaskIds,
    );
    return result.value;
  }

  Future<void> _persistPositions(EngineQueueOrderApplied result) async {
    for (final position in result.analysisPositions) {
      final projection = await projectionRepository.loadByTaskId(
        position.clientTaskId,
      );
      if (projection != null) {
        await projectionRepository.upsert(
          projection.copyWith(
            analysisWorkId: position.workId,
            analysisQueuePosition: position.queuePosition,
            analysisQueueRevision: result.analysisQueueRevision,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    for (final position in result.executionPositions) {
      final projection = await projectionRepository.loadByTaskId(
        position.clientTaskId,
      );
      if (projection != null) {
        await projectionRepository.upsert(
          projection.copyWith(
            executionId: position.executionId,
            executionQueuePosition: position.queuePosition,
            executionQueueRevision: result.executionQueueRevision,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  }
}
