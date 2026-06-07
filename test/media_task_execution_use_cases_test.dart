import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/use_cases/media_tasks/clear_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/delete_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_all_media_task_executions_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_media_task_execution_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_execution_queue_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_or_resume_media_task_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';

void main() {
  group('media task execution use cases', () {
    test('start execution queue delegates to the queue runner', () async {
      final runner = FakeFfmpegTaskQueueRunner();

      final result = await StartExecutionQueueUseCase(
        queueRunner: runner,
      ).call(allowExtremeCompression: true);

      expect(result.outcome, FfmpegQueueStartOutcome.started);
      expect(runner.startAllowExtremeCompression, true);
    });

    test('start or resume task delegates to the queue runner', () async {
      final runner = FakeFfmpegTaskQueueRunner();

      final result = await StartOrResumeMediaTaskUseCase(
        queueRunner: runner,
      ).call('task-1', allowExtremeCompression: true);

      expect(result.outcome, FfmpegQueueStartOutcome.resumed);
      expect(runner.startOrResumeTaskId, 'task-1');
      expect(runner.startOrResumeAllowExtremeCompression, true);
    });

    test('pause task delegates to the queue runner', () async {
      final runner = FakeFfmpegTaskQueueRunner();

      final result = await PauseMediaTaskExecutionUseCase(
        queueRunner: runner,
      ).call('task-1');

      expect(result.outcome, FfmpegQueueStartOutcome.paused);
      expect(runner.pausedTaskId, 'task-1');
    });

    test('pause all tasks delegates to the queue runner', () async {
      final runner = FakeFfmpegTaskQueueRunner();

      final result = await PauseAllMediaTaskExecutionsUseCase(
        queueRunner: runner,
      ).call();

      expect(result.outcome, FfmpegQueueStartOutcome.paused);
      expect(runner.pauseAllCallCount, 1);
    });

    test('delete cancels running task before deleting it', () async {
      final repository = FakeMediaTaskRepository([
        testTask(id: 'running', status: TaskStatus.running),
        testTask(id: 'pending', status: TaskStatus.pending),
      ]);
      final runner = FakeFfmpegTaskQueueRunner();

      final remainingTasks = await DeleteMediaTaskUseCase(
        repository: repository,
        queueRunner: runner,
      ).call('running');

      expect(runner.cancelledTaskIds, ['running']);
      expect(repository.tasks.map((task) => task.id), ['pending']);
      expect(remainingTasks.map((task) => task.id), ['pending']);
    });

    test('delete does not cancel a non-executing task', () async {
      final repository = FakeMediaTaskRepository([
        testTask(id: 'pending', status: TaskStatus.pending),
      ]);
      final runner = FakeFfmpegTaskQueueRunner();

      await DeleteMediaTaskUseCase(
        repository: repository,
        queueRunner: runner,
      ).call('pending');

      expect(runner.cancelledTaskIds, isEmpty);
      expect(repository.tasks, isEmpty);
    });

    test('clear cancels all executions before replacing tasks', () async {
      final repository = FakeMediaTaskRepository([
        testTask(id: 'task-1', status: TaskStatus.running),
      ]);
      final runner = FakeFfmpegTaskQueueRunner();

      final remainingTasks = await ClearMediaTasksUseCase(
        repository: repository,
        queueRunner: runner,
      ).call();

      expect(runner.cancelAllCallCount, 1);
      expect(repository.tasks, isEmpty);
      expect(remainingTasks, isEmpty);
    });
  });
}

MediaTask testTask({required String id, required TaskStatus status}) {
  return MediaTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
  );
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  final List<MediaTask> tasks;

  @override
  Future<void> deleteTaskById(String taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async {
    return [...tasks];
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    this.tasks
      ..clear()
      ..addAll(tasks);
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    final index = tasks.indexWhere((existingTask) {
      return existingTask.id == task.id;
    });
    if (index == -1) {
      tasks.add(task);
      return;
    }

    tasks[index] = task;
  }
}

class FakeFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  @override
  String? foregroundTaskId;

  @override
  FfmpegQueueStatus queueStatus = FfmpegQueueStatus.idle;

  bool? startAllowExtremeCompression;
  bool? startOrResumeAllowExtremeCompression;
  String? startOrResumeTaskId;
  String? pausedTaskId;
  final List<String> cancelledTaskIds = [];
  int pauseAllCallCount = 0;
  int cancelAllCallCount = 0;

  @override
  Future<void> cancelAllExecutions() async {
    cancelAllCallCount += 1;
  }

  @override
  Future<FfmpegQueueStartResult> cancelTask(String taskId) async {
    cancelledTaskIds.add(taskId);
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.cancelled,
    );
  }

  @override
  Future<FfmpegQueueStartResult> pauseTask(String taskId) async {
    pausedTaskId = taskId;
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
    );
  }

  @override
  Future<FfmpegQueueStartResult> pauseAllRunningTasks() async {
    pauseAllCallCount += 1;
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
    );
  }

  @override
  Future<FfmpegQueueStatus> refreshStatus() async {
    return queueStatus;
  }

  @override
  Future<FfmpegQueueStartResult> start({
    bool allowExtremeCompression = false,
  }) async {
    startAllowExtremeCompression = allowExtremeCompression;
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.started,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startOrResumeTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) async {
    startOrResumeTaskId = taskId;
    startOrResumeAllowExtremeCompression = allowExtremeCompression;
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.resumed,
    );
  }
}
