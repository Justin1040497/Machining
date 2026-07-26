import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

void main() {
  test(
    'rebuilds analysis, execution, resume, and user-pause projections',
    () async {
      final tasks = <MediaTask>[
        _task('analysis'),
        _task('waiting').copyWith(status: TaskStatus.ready),
        _task('preempted').copyWith(status: TaskStatus.ready),
        _task('paused').copyWith(status: TaskStatus.ready),
      ];
      final taskRepository = _TaskRepository(tasks);
      final projections = _ProjectionRepository(<EngineAnalysisProjection>[
        _projection('waiting', executionId: 'execution-waiting'),
        _projection('preempted', executionId: 'execution-preempted'),
        _projection('paused', executionId: 'execution-paused'),
      ]);
      final gateway = _Gateway(
        EngineStateSnapshot(
          analysisQueueRevision: 4,
          activeAnalysis: const EngineAnalysisQueueEntrySnapshot(
            workId: 'work-analysis',
            clientTaskId: 'analysis',
            queuePosition: 0,
          ),
          analysisQueue: const <EngineAnalysisQueueEntrySnapshot>[],
          executionLane: EngineExecutionLaneSnapshot(
            queueRevision: 9,
            active: null,
            normalWaiting: <EngineScheduledExecution>[
              _execution('execution-waiting', EngineExecutionState.queued),
            ],
            resumeStack: <EngineScheduledExecution>[
              _execution(
                'execution-preempted',
                EngineExecutionState.preempted,
                pauseReason: EngineExecutionPauseReason.preemption,
              ),
            ],
            userPaused: <EngineScheduledExecution>[
              _execution(
                'execution-paused',
                EngineExecutionState.paused,
                pauseReason: EngineExecutionPauseReason.user,
              ),
            ],
          ),
          lastSequence: 20,
        ),
      );
      final coordinator = EngineLifecycleCoordinator(
        gateway: gateway,
        taskRepository: taskRepository,
        projectionRepository: projections,
        now: () => DateTime.fromMillisecondsSinceEpoch(100),
      );
      addTearDown(coordinator.close);

      await coordinator.start();

      expect(taskRepository['analysis'].status, TaskStatus.analyzing);
      expect(taskRepository['waiting'].status, TaskStatus.executionQueued);
      expect(taskRepository['preempted'].status, TaskStatus.preempted);
      expect(taskRepository['paused'].status, TaskStatus.paused);
      expect(projections['waiting']!.executionQueueRevision, 9);
      expect(projections['waiting']!.lastEventSequence, 21);
    },
  );

  test('applies a terminal event once by global sequence', () async {
    final taskRepository = _TaskRepository(<MediaTask>[
      _task('task').copyWith(status: TaskStatus.executionQueued),
    ]);
    final projections = _ProjectionRepository(<EngineAnalysisProjection>[
      _projection('task', executionId: 'execution-1'),
    ]);
    final gateway = _Gateway(
      EngineStateSnapshot(
        analysisQueueRevision: 0,
        analysisQueue: const <EngineAnalysisQueueEntrySnapshot>[],
        executionLane: EngineExecutionLaneSnapshot(
          queueRevision: 1,
          active: _execution('execution-1', EngineExecutionState.running),
          normalWaiting: const <EngineScheduledExecution>[],
          resumeStack: const <EngineScheduledExecution>[],
        ),
        lastSequence: 3,
      ),
    );
    final coordinator = EngineLifecycleCoordinator(
      gateway: gateway,
      taskRepository: taskRepository,
      projectionRepository: projections,
      now: () => DateTime.fromMillisecondsSinceEpoch(200),
    );
    addTearDown(coordinator.close);
    await coordinator.start();

    gateway.add(
      const EngineWorkEvent(
        requestId: 'execution-event-execution-1',
        workId: null,
        sequence: 5,
        type: EngineWorkEventType.executionCompleted,
        clientTaskId: 'task',
        executionId: 'execution-1',
        executionState: EngineExecutionState.completed,
        outputPath: '/output.wav',
      ),
    );
    gateway.add(
      const EngineWorkEvent(
        requestId: 'execution-event-execution-1',
        workId: null,
        sequence: 5,
        type: EngineWorkEventType.executionFailed,
        clientTaskId: 'task',
        executionId: 'execution-1',
        executionState: EngineExecutionState.failed,
        message: 'duplicate terminal event',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await coordinator.close();

    expect(taskRepository['task'].status, TaskStatus.completed);
    expect(taskRepository['task'].outputPath, '/output.wav');
    expect(projections['task']!.lastEventSequence, 5);
  });

  test(
    'recovers a terminal execution completed while Client was offline',
    () async {
      final taskRepository = _TaskRepository(<MediaTask>[
        _task('task').copyWith(status: TaskStatus.running),
      ]);
      final projections = _ProjectionRepository(<EngineAnalysisProjection>[
        _projection('task', executionId: 'execution-1'),
      ]);
      final gateway = _Gateway(
        const EngineStateSnapshot(
          analysisQueueRevision: 0,
          analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
          executionLane: EngineExecutionLaneSnapshot(
            queueRevision: 2,
            active: null,
            normalWaiting: <EngineScheduledExecution>[],
            resumeStack: <EngineScheduledExecution>[],
          ),
          terminalExecutions: <EngineTerminalExecutionSnapshot>[
            EngineTerminalExecutionSnapshot(
              executionId: 'execution-1',
              clientTaskId: 'task',
              state: EngineExecutionState.completed,
              outputPath: '/recovered.wav',
            ),
          ],
          lastSequence: 7,
        ),
      );
      final coordinator = EngineLifecycleCoordinator(
        gateway: gateway,
        taskRepository: taskRepository,
        projectionRepository: projections,
        now: () => DateTime.fromMillisecondsSinceEpoch(300),
      );
      addTearDown(coordinator.close);

      await coordinator.start();

      expect(taskRepository['task'].status, TaskStatus.completed);
      expect(taskRepository['task'].outputPath, '/recovered.wav');
      expect(
        projections['task']!.executionState,
        EngineExecutionState.completed.name,
      );
    },
  );

  test(
    'recovers an analysis Snapshot completed while Client was offline',
    () async {
      final taskRepository = _TaskRepository(<MediaTask>[
        _task('task').markAnalysisQueued().markAnalyzing(),
      ]);
      final projections = _ProjectionRepository(<EngineAnalysisProjection>[
        EngineAnalysisProjection(
          taskId: 'task',
          clientFileId: 'task',
          engineSessionId: 'session',
          analysisRequestId: 'analysis-request',
          lastEventSequence: 1,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ]);
      final gateway = _Gateway(
        const EngineStateSnapshot(
          analysisQueueRevision: 1,
          analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
          terminalAnalyses: <EngineTerminalAnalysisSnapshot>[
            EngineTerminalAnalysisSnapshot(
              workId: 'analysis-work',
              clientTaskId: 'task',
              clientFileId: 'task',
              analysisId: 'analysis-1',
              analysisRevision: 3,
              succeeded: true,
            ),
          ],
          executionLane: EngineExecutionLaneSnapshot(
            queueRevision: 0,
            active: null,
            normalWaiting: <EngineScheduledExecution>[],
            resumeStack: <EngineScheduledExecution>[],
          ),
          lastSequence: 4,
        ),
        analysisSnapshot: _analysisSnapshot(),
      );
      final coordinator = EngineLifecycleCoordinator(
        gateway: gateway,
        taskRepository: taskRepository,
        projectionRepository: projections,
      );
      addTearDown(coordinator.close);

      await coordinator.start();

      expect(taskRepository['task'].status, TaskStatus.ready);
      expect(projections['task']!.analysisId, 'analysis-1');
      expect(projections['task']!.revision, 3);
      expect(projections['task']!.snapshotJson, isNotEmpty);
    },
  );

  test(
    'rebuilds from an authoritative snapshot after a sequence gap',
    () async {
      final taskRepository = _TaskRepository(<MediaTask>[_task('task')]);
      final projections = _ProjectionRepository(
        const <EngineAnalysisProjection>[],
      );
      final gateway = _Gateway(
        const EngineStateSnapshot(
          analysisQueueRevision: 0,
          analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
          executionLane: EngineExecutionLaneSnapshot(
            queueRevision: 0,
            active: null,
            normalWaiting: <EngineScheduledExecution>[],
            resumeStack: <EngineScheduledExecution>[],
          ),
          lastSequence: 4,
        ),
      );
      final coordinator = EngineLifecycleCoordinator(
        gateway: gateway,
        taskRepository: taskRepository,
        projectionRepository: projections,
      );
      addTearDown(coordinator.close);
      await coordinator.start();

      gateway.add(
        const EngineWorkEvent(
          requestId: 'gap',
          workId: null,
          sequence: 8,
          type: EngineWorkEventType.sequenceGap,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await coordinator.close();

      expect(gateway.snapshotRequests, 2);
    },
  );

  test('accepts a lower sequence from a new engine session', () async {
    final taskRepository = _TaskRepository(<MediaTask>[_task('task')]);
    final projections = _ProjectionRepository(<EngineAnalysisProjection>[
      EngineAnalysisProjection(
        taskId: 'task',
        clientFileId: 'task',
        engineSessionId: 'old-session',
        lastEventSequence: 99,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ]);
    final gateway = _Gateway(
      const EngineStateSnapshot(
        analysisQueueRevision: 2,
        activeAnalysis: EngineAnalysisQueueEntrySnapshot(
          workId: 'work-task',
          clientTaskId: 'task',
          queuePosition: 0,
        ),
        analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
        executionLane: EngineExecutionLaneSnapshot(
          queueRevision: 0,
          active: null,
          normalWaiting: <EngineScheduledExecution>[],
          resumeStack: <EngineScheduledExecution>[],
        ),
        lastSequence: 1,
      ),
      sessionId: 'new-session',
    );
    final coordinator = EngineLifecycleCoordinator(
      gateway: gateway,
      taskRepository: taskRepository,
      projectionRepository: projections,
    );
    addTearDown(coordinator.close);

    await coordinator.start();

    expect(taskRepository['task'].status, TaskStatus.analyzing);
    expect(projections['task']!.engineSessionId, 'new-session');
    expect(projections['task']!.lastEventSequence, 2);
  });

  test('projects asynchronous batch execution submission', () async {
    final taskRepository = _TaskRepository(<MediaTask>[
      _task('task').copyWith(status: TaskStatus.ready),
    ]);
    final projections = _ProjectionRepository(<EngineAnalysisProjection>[
      _projection('task'),
    ]);
    final gateway = _Gateway(
      const EngineStateSnapshot(
        analysisQueueRevision: 0,
        analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
        executionLane: EngineExecutionLaneSnapshot(
          queueRevision: 0,
          active: null,
          normalWaiting: <EngineScheduledExecution>[],
          resumeStack: <EngineScheduledExecution>[],
        ),
        lastSequence: 0,
      ),
    );
    final coordinator = EngineLifecycleCoordinator(
      gateway: gateway,
      taskRepository: taskRepository,
      projectionRepository: projections,
    );
    addTearDown(coordinator.close);
    await coordinator.start();

    gateway.add(
      const EngineWorkEvent(
        requestId: 'batch-child:work-2',
        workId: 'work-2',
        sequence: 2,
        type: EngineWorkEventType.executionSubmitted,
        sessionId: 'session',
        clientTaskId: 'task',
        executionId: 'execution-1',
        executionState: EngineExecutionState.queued,
        queuePosition: 1,
        queueRevision: 3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await coordinator.close();

    expect(taskRepository['task'].status, TaskStatus.executionQueued);
    expect(projections['task']!.executionId, 'execution-1');
    expect(projections['task']!.executionQueuePosition, 1);
    expect(projections['task']!.executionQueueRevision, 3);
  });

  test('marks nonterminal work missing from a new authoritative snapshot as '
      'recoverable failure', () async {
    final taskRepository = _TaskRepository(<MediaTask>[
      _task('analysis').markAnalysisQueued(),
      _task('execution').copyWith(status: TaskStatus.running),
    ]);
    final projections = _ProjectionRepository(<EngineAnalysisProjection>[
      EngineAnalysisProjection(
        taskId: 'analysis',
        clientFileId: 'analysis',
        engineSessionId: 'old-session',
        analysisRequestId: 'analysis-request',
        analysisWorkId: 'work-analysis',
        lastEventSequence: 40,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      EngineAnalysisProjection(
        taskId: 'execution',
        clientFileId: 'execution',
        engineSessionId: 'old-session',
        executionId: 'execution-old',
        executionState: EngineExecutionState.running.name,
        lastEventSequence: 40,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ]);
    final gateway = _Gateway(
      const EngineStateSnapshot(
        analysisQueueRevision: 0,
        analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
        executionLane: EngineExecutionLaneSnapshot(
          queueRevision: 0,
          active: null,
          normalWaiting: <EngineScheduledExecution>[],
          resumeStack: <EngineScheduledExecution>[],
        ),
        lastSequence: 0,
      ),
      sessionId: 'new-session',
    );
    final coordinator = EngineLifecycleCoordinator(
      gateway: gateway,
      taskRepository: taskRepository,
      projectionRepository: projections,
      now: () => DateTime.fromMillisecondsSinceEpoch(500),
    );
    addTearDown(coordinator.close);

    await coordinator.start();

    expect(taskRepository['analysis'].status, TaskStatus.analysisFailed);
    expect(
      taskRepository['analysis'].failure?.stage,
      TaskFailureStage.recovery,
    );
    expect(taskRepository['execution'].status, TaskStatus.executionFailed);
    expect(
      taskRepository['execution'].failure?.stage,
      TaskFailureStage.recovery,
    );
    expect(projections['analysis']!.analysisWorkId, isNull);
    expect(projections['execution']!.executionId, isNull);
    expect(projections['execution']!.executionState, isNull);
    expect(projections['analysis']!.engineSessionId, 'new-session');
    expect(projections['execution']!.engineSessionId, 'new-session');
  });
}

MediaTask _task(String id) {
  return MediaTask.draft(
    inputPath: '/$id.wav',
    fileName: '$id.wav',
    mediaKind: MediaKind.audio,
    sortOrder: 0,
  ).copyWith(id: id);
}

EngineAnalysisProjection _projection(String taskId, {String? executionId}) {
  return EngineAnalysisProjection(
    taskId: taskId,
    clientFileId: taskId,
    engineSessionId: 'session',
    executionId: executionId,
    executionState: executionId == null
        ? null
        : EngineExecutionState.queued.name,
    lastEventSequence: 0,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

EngineScheduledExecution _execution(
  String id,
  EngineExecutionState state, {
  EngineExecutionPauseReason? pauseReason,
}) {
  return EngineScheduledExecution(
    executionId: id,
    state: state,
    pauseReason: pauseReason,
    preemptedByExecutionId: null,
    checkpoint: null,
  );
}

final class _Gateway implements EngineLifecycleGateway {
  _Gateway(this.snapshot, {this.sessionId = 'session', this.analysisSnapshot});

  final EngineStateSnapshot snapshot;
  final String sessionId;
  final EngineAnalysisSnapshotDocument? analysisSnapshot;
  final StreamController<EngineWorkEvent> controller =
      StreamController<EngineWorkEvent>.broadcast();
  int snapshotRequests = 0;

  void add(EngineWorkEvent event) => controller.add(event);

  @override
  Stream<EngineWorkEvent> get events => controller.stream;

  @override
  Future<EngineConnectionInfo> connect() async => EngineConnectionInfo(
    sessionId: sessionId,
    protocolVersion: 1,
    engineVersion: 'test',
    heartbeatTimeout: const Duration(seconds: 10),
    resumed: false,
  );

  @override
  Future<EngineOperationResult<EngineStateSnapshot>> getEngineSnapshot() async {
    snapshotRequests += 1;
    return EngineOperationResult(
      sessionId: sessionId,
      requestId: 'snapshot',
      workId: 'snapshot-work',
      sequence: snapshot.lastSequence + 1,
      value: snapshot,
    );
  }

  @override
  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>>
  getAnalysisSnapshot(
    String analysisId, {
    EngineWorkPriority priority = EngineWorkPriority.foreground,
  }) async {
    final value = analysisSnapshot;
    if (value == null) {
      throw StateError('analysis Snapshot was not configured');
    }
    return EngineOperationResult(
      sessionId: sessionId,
      requestId: 'analysis-snapshot',
      workId: 'analysis-snapshot-work',
      sequence: snapshot.lastSequence + 2,
      value: value,
    );
  }

  @override
  Future<void> close() => controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EngineAnalysisSnapshotDocument _analysisSnapshot() {
  return EngineAnalysisSnapshotDocument.fromJson(<String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 3,
    'decision_model_revision': 1,
    'estimator_model_revision': 1,
    'task_mode': 'audio_compress',
    'media': <String, Object?>{},
    'source_fingerprint': <String, Object?>{},
    'requirements': <String, Object?>{},
    'environment_summary': <String, Object?>{},
    'engine_backend_summary': <String, Object?>{},
    'capabilities': <String, Object?>{
      'available': false,
      'execution_chains': <Object?>[],
    },
    'configuration_options': <String, Object?>{
      'candidate_ids': <Object?>[],
      'containers': <Object?>[],
      'video_codecs': <Object?>[],
      'video_profiles': <Object?>[],
      'audio_codecs': <Object?>[],
      'video_encoders': <Object?>[],
      'audio_encoders': <Object?>[],
      'pixel_formats': <Object?>[],
      'bit_depths': <Object?>[],
      'hdr_modes': <Object?>[],
      'preserves_hdr': <Object?>[],
      'requires_tone_mapping': <Object?>[],
    },
    'recommendation': <String, Object?>{
      'status': 'unavailable',
      'configuration': null,
      'estimate': null,
      'reasons': <Object?>[],
    },
    'presets': <Object?>[],
    'custom_target_size': <String, Object?>{
      'available': false,
      'unavailable_reason': 'ENGINE_EXECUTION_CHAIN_NOT_READY',
      'minimum_bytes': null,
      'maximum_bytes': null,
      'default_bytes': null,
      'step_bytes': null,
      'display_unit': 'bytes',
    },
    'warnings': <Object?>[],
    'validity': <String, Object?>{
      'status': 'valid',
      'reason_code': null,
      'message': null,
    },
  });
}

final class _TaskRepository implements MediaTaskRepository {
  _TaskRepository(List<MediaTask> tasks)
    : values = <String, MediaTask>{for (final task in tasks) task.id: task};

  final Map<String, MediaTask> values;

  MediaTask operator [](String id) => values[id]!;

  @override
  Future<List<MediaTask>> loadAllTasks() async => values.values.toList();

  @override
  Future<MediaTask?> loadTaskById(String taskId) async => values[taskId];

  @override
  Future<void> saveTask(MediaTask task) async => values[task.id] = task;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
