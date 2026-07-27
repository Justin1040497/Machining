import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

void main() {
  test(
    'uses authoritative revisions and retries once from conflict snapshot',
    () async {
      final first = _task('first', 1);
      final second = _task('second', 0);
      final initial = _snapshot(analysisRevision: 1, executionRevision: 2);
      final conflict = _snapshot(analysisRevision: 3, executionRevision: 4);
      final gateway = _Gateway(initial: initial, conflict: conflict);
      final projections = _ProjectionRepository(<EngineAnalysisProjection>[
        _projection(first.id),
        _projection(second.id),
      ]);

      final result = await ApplyEngineQueueOrderUseCase(
        gateway: gateway,
        projectionRepository: projections,
        orderRevisionStore: _RevisionStore(),
      ).call(tasks: <MediaTask>[second, first], folders: const <TaskFolder>[]);

      expect(gateway.calls, hasLength(2));
      expect(gateway.calls.first.analysisRevision, 1);
      expect(gateway.calls.first.executionRevision, 2);
      expect(gateway.calls.last.analysisRevision, 3);
      expect(gateway.calls.last.executionRevision, 4);
      expect(gateway.calls.last.taskIds, ['second', 'first']);
      expect(result.orderRevision, 7);
      expect(projections['second']!.analysisQueuePosition, 1);
      expect(projections['first']!.analysisQueuePosition, 2);
    },
  );
}

MediaTask _task(String id, int order) => MediaTask.draft(
  inputPath: '/$id.wav',
  fileName: '$id.wav',
  mediaKind: MediaKind.audio,
  sortOrder: order,
).copyWith(id: id, createdAt: order);

EngineAnalysisProjection _projection(String taskId) => EngineAnalysisProjection(
  taskId: taskId,
  clientFileId: taskId,
  engineSessionId: 'session',
  lastEventSequence: 0,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

EngineStateSnapshot _snapshot({
  required int analysisRevision,
  required int executionRevision,
}) {
  return EngineStateSnapshot(
    analysisQueueRevision: analysisRevision,
    analysisQueue: const <EngineAnalysisQueueEntrySnapshot>[
      EngineAnalysisQueueEntrySnapshot(
        workId: 'work-second',
        clientTaskId: 'second',
        queuePosition: 1,
      ),
      EngineAnalysisQueueEntrySnapshot(
        workId: 'work-first',
        clientTaskId: 'first',
        queuePosition: 2,
      ),
    ],
    executionLane: EngineExecutionLaneSnapshot(
      queueRevision: executionRevision,
      activeExecutions: const <EngineScheduledExecution>[],
      normalWaiting: const <EngineScheduledExecution>[],
      videoResumeStack: const <EngineScheduledExecution>[],
      auxiliaryResumeStack: const <EngineScheduledExecution>[],
    ),
    lastSequence: 0,
  );
}

typedef _Call = ({
  int analysisRevision,
  int executionRevision,
  List<String> taskIds,
});

final class _Gateway implements EngineLifecycleGateway {
  _Gateway({required this.initial, required this.conflict});

  final EngineStateSnapshot initial;
  final EngineStateSnapshot conflict;
  final List<_Call> calls = <_Call>[];
  final StreamController<EngineWorkEvent> controller =
      StreamController<EngineWorkEvent>.broadcast();

  @override
  Stream<EngineWorkEvent> get events => controller.stream;

  @override
  Future<EngineOperationResult<EngineStateSnapshot>>
  getEngineSnapshot() async => EngineOperationResult(
    sessionId: 'session',
    requestId: 'snapshot',
    workId: 'snapshot-work',
    sequence: 1,
    value: initial,
  );

  @override
  Future<EngineOperationResult<EngineQueueOrderOutcome>> applyQueueOrder({
    required int orderRevision,
    required int expectedAnalysisQueueRevision,
    required int expectedExecutionQueueRevision,
    required List<String> orderedTaskIds,
  }) async {
    calls.add((
      analysisRevision: expectedAnalysisQueueRevision,
      executionRevision: expectedExecutionQueueRevision,
      taskIds: orderedTaskIds,
    ));
    final outcome = calls.length == 1
        ? EngineQueueOrderConflict(
            orderRevision: orderRevision,
            snapshot: conflict,
          )
        : EngineQueueOrderApplied(
            orderRevision: orderRevision,
            analysisQueueRevision: 5,
            executionQueueRevision: 6,
            analysisPositions: const <EngineQueuePosition>[
              EngineQueuePosition(
                clientTaskId: 'second',
                workId: 'work-second',
                queuePosition: 1,
              ),
              EngineQueuePosition(
                clientTaskId: 'first',
                workId: 'work-first',
                queuePosition: 2,
              ),
            ],
            executionPositions: const <EngineQueuePosition>[],
          );
    return EngineOperationResult(
      sessionId: 'session',
      requestId: 'order-${calls.length}',
      workId: 'order-work-${calls.length}',
      sequence: calls.length + 1,
      value: outcome,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RevisionStore implements WorkbenchOrderRevisionStore {
  @override
  Future<int> nextRevision() async => 7;
}

final class _ProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _ProjectionRepository(List<EngineAnalysisProjection> projections)
    : values = <String, EngineAnalysisProjection>{
        for (final projection in projections) projection.taskId: projection,
      };

  final Map<String, EngineAnalysisProjection> values;

  EngineAnalysisProjection? operator [](String id) => values[id];

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async =>
      values[taskId];

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async =>
      values[projection.taskId] = projection;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
