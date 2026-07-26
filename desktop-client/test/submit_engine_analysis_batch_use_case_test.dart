import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

void main() {
  test(
    'submits one ordered batch and persists authoritative positions',
    () async {
      final tasks = <MediaTask>[
        _task('video-1', MediaKind.video),
        _task('video-2', MediaKind.video),
        _task('audio-1', MediaKind.audio),
      ];
      final repository = _TaskRepository(tasks);
      final projections = _ProjectionRepository();
      final gateway = _BatchGateway();

      final accepted = await SubmitEngineAnalysisBatchUseCase(
        repository: repository,
        projectionRepository: projections,
        readEngineGateway: () async => gateway,
        now: () => DateTime.fromMillisecondsSinceEpoch(100),
      ).call(['video-1', 'video-2', 'audio-1']);

      expect(accepted, ['video-1', 'video-2', 'audio-1']);
      expect(gateway.requests.map((request) => request.clientTaskId), accepted);
      expect(
        repository.tasks.every(
          (task) => task.status == TaskStatus.analysisQueued,
        ),
        isTrue,
      );
      expect(projections['video-1']?.analysisQueuePosition, 1);
      expect(projections['video-2']?.analysisQueuePosition, 2);
      expect(projections['audio-1']?.analysisQueuePosition, 3);
      expect(projections['audio-1']?.analysisQueueRevision, 9);
    },
  );
}

MediaTask _task(String id, MediaKind kind) {
  return MediaTask.draft(
        inputPath: '/tmp/$id.wav',
        fileName: '$id.wav',
        mediaKind: kind,
        sortOrder: 0,
      )
      .copyWith(id: id)
      .withSourceFileFingerprint(
        const SourceFileFingerprint(fileSize: 100, lastModifiedAt: 1),
      );
}

final class _TaskRepository implements MediaTaskRepository {
  _TaskRepository(List<MediaTask> tasks) : tasks = List<MediaTask>.of(tasks);

  List<MediaTask> tasks;

  @override
  Future<List<MediaTask>> loadAllTasks() async => List<MediaTask>.of(tasks);

  @override
  Future<MediaTask?> loadTaskById(String id) async {
    for (final task in tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    tasks = [
      for (final current in tasks) current.id == task.id ? task : current,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ProjectionRepository
    implements EngineAnalysisProjectionRepository {
  final Map<String, EngineAnalysisProjection> values = {};

  EngineAnalysisProjection? operator [](String taskId) => values[taskId];

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async =>
      values[taskId];

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    values[projection.taskId] = projection;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _BatchGateway implements EngineBatchGateway {
  final List<EngineAnalysisRequest> requests = [];

  @override
  Stream<EngineWorkEvent> get events => const Stream.empty();

  @override
  Future<EngineConnectionInfo> connect() async => const EngineConnectionInfo(
    sessionId: 'session-1',
    protocolVersion: 1,
    engineVersion: 'test',
    heartbeatTimeout: Duration(seconds: 5),
    resumed: false,
  );

  @override
  Future<EngineOperationResult<EngineBatchSubmission>> submitAnalysisBatch(
    List<EngineAnalysisRequest> requests,
  ) async {
    this.requests.addAll(requests);
    return EngineOperationResult(
      sessionId: 'session-1',
      requestId: 'batch-1',
      workId: 'work-1',
      sequence: 20,
      value: EngineBatchSubmission(
        items: <EngineBatchSubmissionItem>[
          for (var index = 0; index < requests.length; index++)
            EngineBatchSubmissionItem(
              clientTaskId: requests[index].clientTaskId,
              childRequestId: 'child-$index',
              workId: 'work-${index + 1}',
              queueKind: EngineQueueKind.analysis,
              queuePosition: index + 1,
              queueRevision: 9,
            ),
        ],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
