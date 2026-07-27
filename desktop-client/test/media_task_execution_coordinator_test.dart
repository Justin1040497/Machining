import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

void main() {
  test('pauseAll pauses every execution active in the snapshot', () async {
    final tasks = <MediaTask>[
      _runningTask(id: 'video', folderId: 'folder-1'),
      _runningTask(id: 'image', folderId: 'folder-1'),
    ];
    final gateway = _Gateway(<String>['execution-video', 'execution-image']);
    final coordinator = _coordinator(tasks: tasks, gateway: gateway);

    final result = await coordinator.pauseAll();

    expect(result.outcome, EngineQueueStartOutcome.paused);
    expect(gateway.pauseCalls, <String>['execution-video', 'execution-image']);
  });

  test(
    'pauseFolder pauses every active execution in that folder only',
    () async {
      final tasks = <MediaTask>[
        _runningTask(id: 'video', folderId: 'folder-1'),
        _runningTask(id: 'image', folderId: 'folder-1'),
        _runningTask(id: 'audio', folderId: 'folder-2'),
      ];
      final gateway = _Gateway(<String>[
        'execution-video',
        'execution-image',
        'execution-audio',
      ]);
      final coordinator = _coordinator(tasks: tasks, gateway: gateway);

      final result = await coordinator.pauseFolder('folder-1');

      expect(result.outcome, EngineQueueStartOutcome.paused);
      expect(gateway.pauseCalls, <String>[
        'execution-video',
        'execution-image',
      ]);
    },
  );
}

MediaTaskExecutionCoordinator _coordinator({
  required List<MediaTask> tasks,
  required _Gateway gateway,
}) {
  return MediaTaskExecutionCoordinator(
    repository: _MediaTaskRepository(tasks),
    taskFolderRepository: _TaskFolderRepository(),
    submitEngineExecution: _ExecutionSubmitter(),
    analysisProjectionRepository: _ProjectionRepository(<String, String>{
      for (final task in tasks) task.id: 'execution-${task.id}',
    }),
    readEngineGateway: () async => gateway,
  );
}

MediaTask _runningTask({required String id, required String folderId}) {
  return MediaTask.draft(
    inputPath: '/tmp/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: id == 'image'
        ? MediaKind.image
        : id == 'audio'
        ? MediaKind.audio
        : MediaKind.video,
    sortOrder: 0,
  ).copyWith(id: id, folderId: folderId, status: TaskStatus.running);
}

final class _Gateway implements EngineLifecycleGateway {
  _Gateway(this.activeExecutionIds);

  final List<String> activeExecutionIds;
  final List<String> pauseCalls = <String>[];

  @override
  Future<EngineOperationResult<EngineStateSnapshot>> getEngineSnapshot() async {
    return EngineOperationResult<EngineStateSnapshot>(
      sessionId: 'session-1',
      requestId: 'snapshot-1',
      workId: 'snapshot-work-1',
      sequence: 1,
      value: EngineStateSnapshot(
        analysisQueueRevision: 0,
        analysisQueue: const <EngineAnalysisQueueEntrySnapshot>[],
        executionLane: EngineExecutionLaneSnapshot(
          queueRevision: 1,
          activeExecutions: <EngineScheduledExecution>[
            for (final executionId in activeExecutionIds)
              EngineScheduledExecution(
                executionId: executionId,
                resourcePool: executionId.contains('video')
                    ? EngineExecutionResourcePool.video
                    : EngineExecutionResourcePool.auxiliary,
                state: EngineExecutionState.running,
                pauseReason: null,
                preemptedByExecutionId: null,
                checkpoint: null,
              ),
          ],
          normalWaiting: const <EngineScheduledExecution>[],
          videoResumeStack: const <EngineScheduledExecution>[],
          auxiliaryResumeStack: const <EngineScheduledExecution>[],
        ),
        lastSequence: 1,
      ),
    );
  }

  @override
  Future<EngineOperationResult<EngineExecutionState>> controlExecution(
    String executionId,
    EngineExecutionControlAction action,
  ) async {
    expect(action, EngineExecutionControlAction.pause);
    pauseCalls.add(executionId);
    return EngineOperationResult<EngineExecutionState>(
      sessionId: 'session-1',
      requestId: 'pause-${pauseCalls.length}',
      workId: 'pause-work-${pauseCalls.length}',
      sequence: pauseCalls.length + 1,
      value: EngineExecutionState.paused,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _ProjectionRepository(this.executionIdsByTaskId);

  final Map<String, String> executionIdsByTaskId;

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    final executionId = executionIdsByTaskId[taskId];
    if (executionId == null) {
      return null;
    }
    return EngineAnalysisProjection(
      taskId: taskId,
      clientFileId: 'file-$taskId',
      engineSessionId: 'session-1',
      executionId: executionId,
      lastEventSequence: 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MediaTaskRepository implements MediaTaskRepository {
  _MediaTaskRepository(this.tasks);

  final List<MediaTask> tasks;

  @override
  Future<List<MediaTask>> loadAllTasks() async => List<MediaTask>.of(tasks);

  @override
  Future<MediaTask?> loadTaskById(String taskId) async {
    return tasks.where((task) => task.id == taskId).firstOrNull;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TaskFolderRepository implements TaskFolderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ExecutionSubmitter implements EngineExecutionSubmitter {
  @override
  Future<EngineExecutionDispatchResult> call(
    String taskId, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  }) {
    throw UnimplementedError();
  }
}
