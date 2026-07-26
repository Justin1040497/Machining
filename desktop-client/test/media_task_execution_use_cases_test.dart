import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/clear_media_tasks_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/delete_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_all_media_task_executions_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/pause_media_task_execution_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/retry_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_execution_queue_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/start_or_resume_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/submit_engine_execution_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/engine_configuration_reference.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/task_failure.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';

void main() {
  group('media task execution use cases', () {
    test(
      'start execution queue submits every task in stable workbench order',
      () async {
        final first = testTask(
          id: 'first',
          status: TaskStatus.pending,
        ).copyWith(sortOrder: 0);
        final second = testTask(
          id: 'second',
          status: TaskStatus.pending,
        ).copyWith(sortOrder: 1);
        final submitter = RecordingEngineExecutionSubmitter(
          const EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.notEngineConfigured,
            message: '任务没有可提交的引擎配置',
          ),
          results: {
            first.id: EngineExecutionDispatchResult(
              outcome: EngineExecutionDispatchOutcome.submitted,
              task: first,
              message: '任务已提交到 FEngine',
            ),
            second.id: EngineExecutionDispatchResult(
              outcome: EngineExecutionDispatchOutcome.notEngineConfigured,
              task: second,
              message: '任务没有可提交的引擎配置',
            ),
          },
        );

        final result = await StartExecutionQueueUseCase(
          executionCoordinator: MediaTaskExecutionCoordinator(
            repository: FakeMediaTaskRepository([second, first]),
            taskFolderRepository: FakeTaskFolderRepository(),
            submitEngineExecution: submitter,
          ),
        ).call(allowExtremeCompression: true);

        expect(result.outcome, FfmpegQueueStartOutcome.queued);
        expect(submitter.taskIds, [first.id, second.id]);
        expect(submitter.priorities, [
          EngineWorkPriority.normal,
          EngineWorkPriority.normal,
        ]);
        expect(result.message, contains('1 个任务已提交到 FEngine'));
        expect(result.message, contains('1 个任务缺少 FEngine 配置'));
        expect(result.message, contains(second.id));
      },
    );

    test(
      'start or resume returns an explicit invalid state without Engine config',
      () async {
        final task = testTask(id: 'task-1', status: TaskStatus.pending);
        final submitter = RecordingEngineExecutionSubmitter(
          EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.notEngineConfigured,
            task: task,
            message: '任务没有可提交的引擎配置',
          ),
        );

        final result = await StartOrResumeMediaTaskUseCase(
          executionCoordinator: MediaTaskExecutionCoordinator(
            repository: FakeMediaTaskRepository([task]),
            taskFolderRepository: FakeTaskFolderRepository(),
            submitEngineExecution: submitter,
          ),
        ).call('task-1', allowExtremeCompression: true);

        expect(result.outcome, FfmpegQueueStartOutcome.invalidTaskState);
        expect(result.task?.id, task.id);
        expect(submitter.taskIds, [task.id]);
        expect(submitter.priorities, [EngineWorkPriority.foreground]);
      },
    );

    test(
      'engine-configured task never falls back to the legacy runner',
      () async {
        final submitter = RecordingEngineExecutionSubmitter(
          const EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.failed,
            message: 'FLL media pipeline is not ready',
          ),
        );
        final task = testTask(id: 'engine', status: TaskStatus.pending).copyWith(
          analysisResult: MediaAnalysisResult(durationMs: 1000),
          analysisUpdatedAt: 1,
          config: MediaTaskConfig.initialVideo().copyWith(
            engineConfiguration: const EngineConfigurationReference(
              analysisId: 'analysis-1',
              analysisRevision: 1,
              candidateId: 'candidate-1',
              selectionMode: 'manual',
              selectionJson:
                  '{"mode":"manual","selection":{"candidate_id":"candidate-1"}}',
            ),
          ),
        );
        final coordinator = MediaTaskExecutionCoordinator(
          repository: FakeMediaTaskRepository([task]),
          taskFolderRepository: FakeTaskFolderRepository(),
          submitEngineExecution: submitter,
        );

        final result = await coordinator.startSingleTask(task.id);

        expect(result.outcome, FfmpegQueueStartOutcome.executionFailed);
        expect(submitter.taskIds, [task.id]);
      },
    );

    test(
      'workbench keeps dispatching later tasks after an Engine failure',
      () async {
        final engineTask = testTask(id: 'engine', status: TaskStatus.pending)
            .copyWith(
              analysisResult: MediaAnalysisResult(durationMs: 1000),
              analysisUpdatedAt: 1,
              config: MediaTaskConfig.initialVideo().copyWith(
                engineConfiguration: const EngineConfigurationReference(
                  analysisId: 'analysis-1',
                  analysisRevision: 1,
                  candidateId: 'candidate-1',
                  selectionMode: 'manual',
                  selectionJson:
                      '{"mode":"manual","selection":{"candidate_id":"candidate-1"}}',
                ),
              ),
            );
        final legacyTask = testTask(id: 'legacy', status: TaskStatus.pending)
            .copyWith(
              analysisResult: MediaAnalysisResult(durationMs: 1000),
              analysisUpdatedAt: 1,
            );
        final submitter = RecordingEngineExecutionSubmitter(
          const EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.failed,
            message: 'FLL media pipeline is not ready',
          ),
          results: {
            engineTask.id: EngineExecutionDispatchResult(
              outcome: EngineExecutionDispatchOutcome.failed,
              task: engineTask,
              message: 'FLL media pipeline is not ready',
            ),
            legacyTask.id: EngineExecutionDispatchResult(
              outcome: EngineExecutionDispatchOutcome.notEngineConfigured,
              task: legacyTask,
              message: '任务没有可提交的引擎配置',
            ),
          },
        );
        final coordinator = MediaTaskExecutionCoordinator(
          repository: FakeMediaTaskRepository([engineTask, legacyTask]),
          taskFolderRepository: FakeTaskFolderRepository(),
          submitEngineExecution: submitter,
        );

        final result = await coordinator.startWorkbenchQueue();

        expect(result.outcome, FfmpegQueueStartOutcome.executionFailed);
        expect(submitter.taskIds, [engineTask.id, legacyTask.id]);
        expect(result.message, contains('1 个任务提交失败'));
        expect(result.message, contains('1 个任务缺少 FEngine 配置'));
      },
    );

    test(
      'workbench reports unanalyzed Engine tasks instead of skipping them',
      () async {
        final task =
            testTask(
              id: 'awaiting-analysis',
              status: TaskStatus.awaitingAnalysis,
            ).copyWith(
              config: MediaTaskConfig.initialVideo().copyWith(
                engineConfiguration: const EngineConfigurationReference(
                  analysisId: 'analysis-1',
                  analysisRevision: 1,
                  candidateId: 'candidate-1',
                  selectionMode: 'manual',
                  selectionJson:
                      '{"mode":"manual","selection":{"candidate_id":"candidate-1"}}',
                ),
              ),
            );
        final submitter = RecordingEngineExecutionSubmitter(
          EngineExecutionDispatchResult(
            outcome: EngineExecutionDispatchOutcome.notReady,
            task: task,
            message: '当前任务状态不允许提交到引擎',
          ),
        );
        final coordinator = MediaTaskExecutionCoordinator(
          repository: FakeMediaTaskRepository([task]),
          taskFolderRepository: FakeTaskFolderRepository(),
          submitEngineExecution: submitter,
        );

        final result = await coordinator.startWorkbenchQueue();

        expect(submitter.taskIds, [task.id]);
        expect(result.outcome, FfmpegQueueStartOutcome.notReady);
        expect(result.message, contains('1 个任务尚未完成分析或已失效'));
        expect(result.message, contains(task.id));
        expect(result.message, contains('当前任务状态不允许提交到引擎'));
      },
    );

    test('retry rejects a non-retryable engine boundary failure', () async {
      final failedTask =
          testTask(id: 'engine-failed', status: TaskStatus.pending).markFailed(
            const TaskFailure(
              stage: TaskFailureStage.processStart,
              code: TaskFailureCode.engineExecutionUnavailable,
              userMessage: '当前版本尚未接通媒体执行链。',
              technicalSummary: 'ENGINE_EXECUTION_CHAIN_NOT_READY',
              occurredAt: 1,
              retryable: false,
            ),
          );
      final repository = FakeMediaTaskRepository([failedTask]);
      final useCase = RetryMediaTaskUseCase(
        repository: repository,
        settingsRepository: const UnusedAppSettingsRepository(),
        analysisProjectionRepository: FakeEngineAnalysisProjectionRepository(),
        sourceFileChecker: const UnusedSourceFileChecker(),
        fingerprintReader: const UnusedSourceFileFingerprintReader(),
      );

      await expectLater(
        useCase.call(failedTask.id),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('不支持直接重试'),
          ),
        ),
      );
      expect(repository.tasks.single.status, TaskStatus.failed);
      expect(
        repository.tasks.single.failure?.code,
        TaskFailureCode.engineExecutionUnavailable,
      );
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
      final analysisProjectionRepository =
          FakeEngineAnalysisProjectionRepository();

      final remainingTasks = await DeleteMediaTaskUseCase(
        repository: repository,
        analysisProjectionRepository: analysisProjectionRepository,
        queueRunner: runner,
      ).call('running');

      expect(runner.cancelledTaskIds, ['running']);
      expect(analysisProjectionRepository.deletedTaskIds, ['running']);
      expect(repository.tasks.map((task) => task.id), ['pending']);
      expect(remainingTasks.map((task) => task.id), ['pending']);
    });

    test('delete does not cancel a non-executing task', () async {
      final repository = FakeMediaTaskRepository([
        testTask(id: 'pending', status: TaskStatus.pending),
      ]);
      final runner = FakeFfmpegTaskQueueRunner();
      final analysisProjectionRepository =
          FakeEngineAnalysisProjectionRepository();

      await DeleteMediaTaskUseCase(
        repository: repository,
        analysisProjectionRepository: analysisProjectionRepository,
        queueRunner: runner,
      ).call('pending');

      expect(runner.cancelledTaskIds, isEmpty);
      expect(analysisProjectionRepository.deletedTaskIds, ['pending']);
      expect(repository.tasks, isEmpty);
    });

    test('clear cancels all executions before replacing tasks', () async {
      final repository = FakeMediaTaskRepository([
        testTask(id: 'task-1', status: TaskStatus.running),
      ]);
      final folderRepository = FakeTaskFolderRepository();
      final runner = FakeFfmpegTaskQueueRunner();
      final analysisProjectionRepository =
          FakeEngineAnalysisProjectionRepository();

      final remainingTasks = await ClearMediaTasksUseCase(
        repository: repository,
        analysisProjectionRepository: analysisProjectionRepository,
        taskFolderRepository: folderRepository,
        queueRunner: runner,
      ).call();

      expect(runner.cancelAllCallCount, 1);
      expect(analysisProjectionRepository.deleteAllCallCount, 1);
      expect(repository.tasks, isEmpty);
      expect(folderRepository.clearAllCallCount, 1);
      expect(remainingTasks, isEmpty);
    });
  });
}

class RecordingEngineExecutionSubmitter implements EngineExecutionSubmitter {
  RecordingEngineExecutionSubmitter(this.result, {this.results = const {}});

  final EngineExecutionDispatchResult result;
  final Map<String, EngineExecutionDispatchResult> results;
  final List<String> taskIds = [];
  final List<EngineWorkPriority> priorities = [];

  @override
  Future<EngineExecutionDispatchResult> call(
    String taskId, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  }) async {
    taskIds.add(taskId);
    priorities.add(priority);
    return results[taskId] ?? result;
  }
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
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final index = tasks.indexWhere((task) => task.id == update.taskId);
      if (index == -1) {
        continue;
      }

      tasks[index] = tasks[index].copyWith(sortOrder: update.sortOrder);
    }
  }

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final index = tasks.indexWhere((task) => task.id == update.taskId);
      if (index == -1) {
        continue;
      }

      tasks[index] = tasks[index].copyWith(
        folderSortOrder: update.folderSortOrder,
      );
    }
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

  @override
  Future<MediaTask?> loadTaskById(String taskId) async {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return null;
    }
    return tasks[index];
  }

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    final idSet = taskIds.toSet();
    return tasks.where((task) => idSet.contains(task.id)).toList();
  }

  @override
  Future<void> insertTasks(List<MediaTask> newTasks) async {
    for (final task in newTasks) {
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index == -1) {
        tasks.add(task);
      } else {
        tasks[index] = task;
      }
    }
  }
}

class FakeEngineAnalysisProjectionRepository
    implements EngineAnalysisProjectionRepository {
  final Map<String, EngineAnalysisProjection> projections = {};
  final List<String> deletedTaskIds = [];
  int deleteAllCallCount = 0;

  @override
  Future<void> deleteAll() async {
    deleteAllCallCount += 1;
    projections.clear();
  }

  @override
  Future<void> deleteByTaskId(String taskId) async {
    deletedTaskIds.add(taskId);
    projections.remove(taskId);
  }

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    return projections[taskId];
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    projections[projection.taskId] = projection;
  }
}

class FakeTaskFolderRepository implements TaskFolderRepository {
  int clearAllCallCount = 0;

  @override
  Future<void> clearAllFolders() async {
    clearAllCallCount += 1;
  }

  @override
  Future<void> deleteFolderById(String folderId) async {}

  @override
  Future<List<TaskFolder>> loadAllFolders() async => const [];

  @override
  Future<void> saveFolder(TaskFolder folder) async {}

  @override
  Future<void> updateFolderSortOrders(
    List<TaskFolderSortOrderUpdate> updates,
  ) async {}
}

class FakeFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  @override
  Future<void> dispose() async {}

  @override
  void requestQueueRefill() {}

  @override
  String? foregroundTaskId;

  @override
  Set<String> get runningTaskIds =>
      foregroundTaskId == null ? const {} : {foregroundTaskId!};

  @override
  int get activeExecutionCount => runningTaskIds.length;

  @override
  int get effectiveMaxConcurrentExecutions => 1;

  @override
  ExecutionScope get executionScope => const ExecutionScope.none();

  @override
  FfmpegQueueStatus queueStatus = FfmpegQueueStatus.idle;

  bool? startAllowExtremeCompression;
  bool? startOrResumeAllowExtremeCompression;
  String? startOrResumeTaskId;
  String? pausedTaskId;
  final List<String> cancelledTaskIds = [];
  int pauseAllCallCount = 0;
  int cancelAllCallCount = 0;
  int startWorkbenchCallCount = 0;

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
  Future<FfmpegQueueStartResult> pauseFolderQueue(String folderId) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
    );
  }

  @override
  Future<FfmpegQueueStatus> refreshStatus() async {
    return queueStatus;
  }

  @override
  Future<FfmpegQueueStartResult> startWorkbenchQueue({
    bool allowExtremeCompression = false,
  }) async {
    startWorkbenchCallCount += 1;
    startAllowExtremeCompression = allowExtremeCompression;
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.started,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startSingleTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) async {
    startOrResumeTaskId = taskId;
    startOrResumeAllowExtremeCompression = allowExtremeCompression;
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.resumed,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startFolderQueue(
    String folderId, {
    bool allowExtremeCompression = false,
  }) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.started,
    );
  }
}

class UnusedAppSettingsRepository implements AppSettingsRepository {
  const UnusedAppSettingsRepository();

  @override
  Future<AppSettings> loadSettings() {
    throw StateError('settings must not be read for a rejected retry');
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    throw StateError('settings must not be saved for a rejected retry');
  }
}

class UnusedSourceFileChecker implements SourceFileChecker {
  const UnusedSourceFileChecker();

  @override
  Future<bool> exists(String inputPath) {
    throw StateError('source must not be checked for a rejected retry');
  }
}

class UnusedSourceFileFingerprintReader implements SourceFileFingerprintReader {
  const UnusedSourceFileFingerprintReader();

  @override
  Future<SourceFileFingerprint> read(String inputPath) {
    throw StateError('fingerprint must not be read for a rejected retry');
  }
}
