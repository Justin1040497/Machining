import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';

void main() {
  group('DefaultFfmpegTaskQueueRunner', () {
    test('expanded execution order unfolds folders in top-level order', () {
      final firstFolder = taskFolder(id: 'folder-a', sortOrder: 0);
      final secondFolder = taskFolder(id: 'folder-b', sortOrder: 2);
      final firstFolderSecond = videoTask(
        id: 'folder-a-second',
        sortOrder: 8,
      ).copyWith(folderId: firstFolder.id, folderSortOrder: 1);
      final looseTask = videoTask(id: 'loose', sortOrder: 1);
      final firstFolderFirst = videoTask(
        id: 'folder-a-first',
        sortOrder: 9,
      ).copyWith(folderId: firstFolder.id, folderSortOrder: 0);
      final secondFolderTask = videoTask(
        id: 'folder-b-task',
        sortOrder: 10,
      ).copyWith(folderId: secondFolder.id, folderSortOrder: 0);
      final harness = QueueHarness(
        tasks: [
          looseTask,
          firstFolderSecond,
          secondFolderTask,
          firstFolderFirst,
        ],
        folders: [firstFolder, secondFolder],
      );

      final ordered = harness.runner.expandedExecutionOrder(
        harness.repository.tasks,
        harness.taskFolderRepository.folders,
      );

      expect(ordered.map((task) => task.id), [
        'folder-a-first',
        'folder-a-second',
        'loose',
        'folder-b-task',
      ]);
    });

    test('refreshStatus returns ready when pending tasks exist', () async {
      final harness = QueueHarness(tasks: [videoTask(sortOrder: 0)]);

      final status = await harness.runner.refreshStatus();

      expect(status, FfmpegQueueStatus.ready);
      expect(harness.runner.queueStatus, FfmpegQueueStatus.ready);
    });

    test(
      'start registers a foreground task without waiting for completion',
      () async {
        final task = videoTask(id: 'first', sortOrder: 0);
        final harness = QueueHarness(tasks: [task]);

        final result = await harness.runner.start();

        expect(result.outcome, FfmpegQueueStartOutcome.started);
        expect(result.task?.id, 'first');
        expect(harness.runner.foregroundTaskId, 'first');
        expect(harness.processStarter.starts, hasLength(1));
        expect(harness.processObserver.observedTaskIds, ['first']);
        expect(harness.repository.taskById('first').status, TaskStatus.running);
      },
    );

    test(
      'startOrResumeTask suspends current foreground and starts target task',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final secondTask = videoTask(id: 'second', sortOrder: 2);
        final harness = QueueHarness(tasks: [firstTask, secondTask]);

        await harness.runner.start();
        final result = await harness.runner.startOrResumeTask('second');

        expect(result.outcome, FfmpegQueueStartOutcome.started);
        expect(result.task?.id, 'second');
        expect(harness.runner.foregroundTaskId, 'second');
        expect(harness.repository.taskById('first').status, TaskStatus.paused);
        expect(
          harness.repository.taskById('second').status,
          TaskStatus.running,
        );
        expect(harness.processController.pauseCalls, ['first']);
        expect(harness.processStarter.starts, hasLength(2));
      },
    );

    test(
      'startOrResumeTask resumes a paused task and suspends foreground task',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final secondTask = videoTask(id: 'second', sortOrder: 2);
        final harness = QueueHarness(tasks: [firstTask, secondTask]);

        await harness.runner.start();
        await harness.runner.startOrResumeTask('second');
        final result = await harness.runner.startOrResumeTask('first');

        expect(result.outcome, FfmpegQueueStartOutcome.resumed);
        expect(result.task?.id, 'first');
        expect(harness.runner.foregroundTaskId, 'first');
        expect(harness.repository.taskById('first').status, TaskStatus.running);
        expect(harness.repository.taskById('second').status, TaskStatus.paused);
        expect(harness.processController.pauseCalls, ['first', 'second']);
        expect(harness.processController.resumeCalls, ['first']);
      },
    );

    test(
      'pauseTask suspends foreground task and continues next pending task',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final secondTask = videoTask(id: 'second', sortOrder: 2);
        final harness = QueueHarness(tasks: [firstTask, secondTask]);

        await harness.runner.start();
        final result = await harness.runner.pauseTask('first');

        expect(result.outcome, FfmpegQueueStartOutcome.paused);
        expect(result.task?.id, 'first');
        expect(harness.repository.taskById('first').status, TaskStatus.paused);
        expect(
          harness.repository.taskById('second').status,
          TaskStatus.running,
        );
        expect(harness.runner.foregroundTaskId, 'second');
        expect(harness.processController.pauseCalls, ['first']);
      },
    );

    test(
      'pauseAllRunningTasks suspends foreground task without continuing queue',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final secondTask = videoTask(id: 'second', sortOrder: 2);
        final harness = QueueHarness(tasks: [firstTask, secondTask]);

        await harness.runner.start();
        final result = await harness.runner.pauseAllRunningTasks();

        expect(result.outcome, FfmpegQueueStartOutcome.paused);
        expect(harness.repository.taskById('first').status, TaskStatus.paused);
        expect(
          harness.repository.taskById('second').status,
          TaskStatus.pending,
        );
        expect(harness.runner.foregroundTaskId, isNull);
        expect(harness.runner.queueStatus, FfmpegQueueStatus.ready);
        expect(harness.processController.pauseCalls, ['first']);
        expect(harness.processStarter.starts, hasLength(1));
      },
    );

    test('start chooses paused and pending tasks by queue order', () async {
      final pausedTask = videoTask(
        id: 'paused-first',
        sortOrder: 1,
      ).copyWith(status: TaskStatus.paused);
      final pendingTask = videoTask(id: 'pending-second', sortOrder: 2);
      final harness = QueueHarness(tasks: [pendingTask, pausedTask]);

      final result = await harness.runner.start();

      expect(result.outcome, FfmpegQueueStartOutcome.started);
      expect(result.task?.id, 'paused-first');
      expect(harness.runner.foregroundTaskId, 'paused-first');
      expect(
        harness.repository.taskById('paused-first').status,
        TaskStatus.running,
      );
      expect(
        harness.repository.taskById('pending-second').status,
        TaskStatus.pending,
      );
    });

    test('completion starts next task using the latest queue order', () async {
      final firstTask = videoTask(id: 'first', sortOrder: 1);
      final secondTask = videoTask(id: 'second', sortOrder: 2);
      final thirdTask = videoTask(id: 'third', sortOrder: 3);
      final harness = QueueHarness(tasks: [firstTask, secondTask, thirdTask]);

      await harness.runner.start();
      await harness.repository.saveTask(
        harness.repository.taskById('second').copyWith(sortOrder: 3),
      );
      await harness.repository.saveTask(
        harness.repository.taskById('third').copyWith(sortOrder: 2),
      );

      harness.processObserver.complete(
        'first',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForStartedProcesses(2);

      expect(harness.processStarter.starts.last.taskId, 'third');
      expect(harness.runner.foregroundTaskId, 'third');
      expect(harness.repository.taskById('third').status, TaskStatus.running);
      expect(harness.repository.taskById('second').status, TaskStatus.pending);
    });

    test('startOrResumeTask cuts in without changing queue order', () async {
      final firstTask = videoTask(id: 'first', sortOrder: 1);
      final secondTask = videoTask(id: 'second', sortOrder: 2);
      final thirdTask = videoTask(id: 'third', sortOrder: 3);
      final harness = QueueHarness(tasks: [firstTask, secondTask, thirdTask]);

      await harness.runner.start();
      final result = await harness.runner.startOrResumeTask('third');

      expect(result.outcome, FfmpegQueueStartOutcome.started);
      expect(result.task?.id, 'third');
      expect(harness.runner.foregroundTaskId, 'third');
      expect(harness.repository.taskById('first').status, TaskStatus.paused);
      expect(harness.repository.taskById('second').status, TaskStatus.pending);
      expect(harness.repository.taskById('third').status, TaskStatus.running);
      expect(harness.repository.taskById('first').sortOrder, 1);
      expect(harness.repository.taskById('second').sortOrder, 2);
      expect(harness.repository.taskById('third').sortOrder, 3);
      expect(harness.processController.pauseCalls, ['first']);
    });

    test(
      'startOrResumeTask does not interrupt foreground for invalid target',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final completedTask = videoTask(
          id: 'completed',
          sortOrder: 2,
        ).copyWith(status: TaskStatus.completed);
        final harness = QueueHarness(tasks: [firstTask, completedTask]);

        await harness.runner.start();
        final result = await harness.runner.startOrResumeTask('completed');

        expect(result.outcome, FfmpegQueueStartOutcome.invalidTaskState);
        expect(harness.runner.foregroundTaskId, 'first');
        expect(harness.repository.taskById('first').status, TaskStatus.running);
        expect(
          harness.repository.taskById('completed').status,
          TaskStatus.completed,
        );
        expect(harness.processController.pauseCalls, isEmpty);
        expect(harness.processStarter.starts, hasLength(1));
      },
    );

    test(
      'cancelTask kills paused task and removes it from execution contexts',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final secondTask = videoTask(id: 'second', sortOrder: 2);
        final harness = QueueHarness(tasks: [firstTask, secondTask]);

        await harness.runner.start();
        await harness.runner.startOrResumeTask('second');
        final result = await harness.runner.cancelTask('first');

        expect(result.outcome, FfmpegQueueStartOutcome.cancelled);
        expect(result.task?.id, 'first');
        expect(
          harness.repository.taskById('first').status,
          TaskStatus.cancelled,
        );
        expect(
          harness.repository.taskById('second').status,
          TaskStatus.running,
        );
        expect(harness.processController.pauseCalls, ['first']);
        expect(harness.processController.terminateCalls, ['first']);
      },
    );

    test(
      'cancelAllExecutions kills active processes and resets queue',
      () async {
        final firstTask = videoTask(id: 'first', sortOrder: 1);
        final secondTask = videoTask(id: 'second', sortOrder: 2);
        final harness = QueueHarness(tasks: [firstTask, secondTask]);

        await harness.runner.start();
        await harness.runner.startOrResumeTask('second');
        await harness.runner.cancelAllExecutions();

        expect(harness.runner.foregroundTaskId, isNull);
        expect(harness.runner.queueStatus, FfmpegQueueStatus.idle);
        expect(harness.processController.pauseCalls, ['first']);
        expect(harness.processController.terminateCalls, ['first', 'second']);
      },
    );

    test('background observation completion saves final state', () async {
      final task = videoTask(id: 'first', sortOrder: 0);
      final harness = QueueHarness(tasks: [task]);

      await harness.runner.start();
      harness.processObserver.complete(
        'first',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForTaskStatus('first', TaskStatus.completed);

      expect(harness.repository.taskById('first').status, TaskStatus.completed);
      expect(harness.completedNotifications, ['first']);
      expect(harness.failedNotifications, isEmpty);
      expect(harness.runner.foregroundTaskId, isNull);
      expect(harness.runner.queueStatus, FfmpegQueueStatus.idle);
    });

    test('background observation completion is handled while paused', () async {
      final task = videoTask(id: 'first', sortOrder: 0);
      final harness = QueueHarness(
        tasks: [task],
        continuousExecutionEnabled: false,
      );

      await harness.runner.start();
      await harness.runner.pauseTask('first');
      harness.processObserver.complete(
        'first',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForTaskStatus('first', TaskStatus.completed);

      expect(harness.repository.taskById('first').status, TaskStatus.completed);
      expect(harness.runner.foregroundTaskId, isNull);
      expect(harness.runner.queueStatus, FfmpegQueueStatus.idle);
    });

    test('runs multi-step command plan sequentially', () async {
      final task = videoTask(id: 'two-pass', sortOrder: 0);
      final harness = QueueHarness(
        tasks: [task],
        commandBuilder: FakeCommandBuilder(
          stepArgs: [
            ['-hide_banner', '-i', '/videos/two-pass.mp4', '-pass', '1'],
            [
              '-hide_banner',
              '-i',
              '/videos/two-pass.mp4',
              '-pass',
              '2',
              '/videos/two-pass.out.mp4',
            ],
          ],
        ),
      );

      await harness.runner.start();

      expect(harness.processStarter.starts, hasLength(1));
      expect(
        harness.processStarter.starts.first.args,
        containsAll(['-pass', '1']),
      );
      expect(
        harness.repository.taskById('two-pass').status,
        TaskStatus.running,
      );

      harness.processObserver.complete(
        'two-pass',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForStartedProcesses(2);

      expect(harness.processStarter.starts, hasLength(2));
      expect(
        harness.processStarter.starts.last.args,
        containsAll(['-pass', '2']),
      );
      expect(
        harness.repository.taskById('two-pass').status,
        TaskStatus.running,
      );

      harness.processObserver.complete(
        'two-pass',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForTaskStatus('two-pass', TaskStatus.completed);

      expect(
        harness.repository.taskById('two-pass').status,
        TaskStatus.completed,
      );
      expect(harness.runner.foregroundTaskId, isNull);
    });

    test('starts image fallback when source-format output is larger', () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-image-fallback-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.png')
        ..writeAsBytesSync(List<int>.filled(100, 1));
      final firstOutput = File('${tempDirectory.path}/source_compressed.png');
      final fallbackOutput = File(
        '${tempDirectory.path}/source_compressed.webp',
      );
      final task = imageTask(
        id: 'image-fallback',
        inputPath: source.path,
        sortOrder: 0,
      );
      final harness = QueueHarness(
        tasks: [task],
        commandBuilder: FakeCommandBuilder(
          plan: imageFallbackPlan(
            inputPath: source.path,
            firstOutputPath: firstOutput.path,
            fallbackOutputPath: fallbackOutput.path,
          ),
        ),
      );

      await harness.runner.start();
      firstOutput.writeAsBytesSync(List<int>.filled(120, 2));
      harness.processObserver.complete(
        'image-fallback',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForStartedProcesses(2);

      expect(await firstOutput.exists(), isFalse);
      expect(
        harness.repository.taskById('image-fallback').policyTags,
        contains(MediaTaskPolicyTag.imageFormatFallback),
      );
      expect(
        harness.repository.taskById('image-fallback').outputPath,
        fallbackOutput.path,
      );

      fallbackOutput.writeAsBytesSync(List<int>.filled(60, 3));
      harness.processObserver.complete(
        'image-fallback',
        const FfmpegProcessObservation.completed(),
      );
      await harness.waitForTaskStatus('image-fallback', TaskStatus.completed);

      final completedTask = harness.repository.taskById('image-fallback');
      expect(completedTask.outputPath, fallbackOutput.path);
      expect(
        completedTask.policyTags,
        contains(MediaTaskPolicyTag.imageFormatFallback),
      );
      expect(harness.completedNotifications, ['image-fallback']);
      expect(await fallbackOutput.exists(), isTrue);
    });

    test(
      'fails image task when fallback output is still not smaller',
      () async {
        final tempDirectory = Directory.systemTemp.createTempSync(
          'framelean-image-failure-test-',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });
        final source = File('${tempDirectory.path}/source.png')
          ..writeAsBytesSync(List<int>.filled(100, 1));
        final firstOutput = File('${tempDirectory.path}/source_compressed.png');
        final fallbackOutput = File(
          '${tempDirectory.path}/source_compressed.webp',
        );
        final task = imageTask(
          id: 'image-failure',
          inputPath: source.path,
          sortOrder: 0,
        );
        final harness = QueueHarness(
          tasks: [task],
          commandBuilder: FakeCommandBuilder(
            plan: imageFallbackPlan(
              inputPath: source.path,
              firstOutputPath: firstOutput.path,
              fallbackOutputPath: fallbackOutput.path,
            ),
          ),
        );

        await harness.runner.start();
        firstOutput.writeAsBytesSync(List<int>.filled(120, 2));
        harness.processObserver.complete(
          'image-failure',
          const FfmpegProcessObservation.completed(),
        );
        await harness.waitForStartedProcesses(2);

        fallbackOutput.writeAsBytesSync(List<int>.filled(110, 3));
        harness.processObserver.complete(
          'image-failure',
          const FfmpegProcessObservation.completed(),
        );
        await harness.waitForTaskStatus('image-failure', TaskStatus.failed);

        final failedTask = harness.repository.taskById('image-failure');
        expect(failedTask.outputPath, isNull);
        expect(failedTask.errorMessage, contains('图片未有效压缩'));
        expect(
          failedTask.policyTags,
          containsAll([
            MediaTaskPolicyTag.imageFormatFallback,
            MediaTaskPolicyTag.ineffectiveCompression,
          ]),
        );
        expect(harness.failedNotifications, ['image-failure']);
        expect(await firstOutput.exists(), isFalse);
        expect(await fallbackOutput.exists(), isFalse);
      },
    );

    test('start fails the task when FFmpeg is unavailable', () async {
      final task = videoTask(id: 'no-ffmpeg', sortOrder: 0);
      final harness = QueueHarness(
        tasks: [task],
        runtime: const ResolvedFfmpegRuntime(ffmpeg: null, ffprobe: null),
      );

      final result = await harness.runner.start();

      expect(result.outcome, FfmpegQueueStartOutcome.ffmpegUnavailable);
      expect(
        harness.repository.taskById('no-ffmpeg').status,
        TaskStatus.failed,
      );
      expect(
        harness.repository.taskById('no-ffmpeg').errorMessage,
        'FFmpeg 不可用',
      );
      expect(harness.failedNotifications, ['no-ffmpeg']);
    });

    test(
      'start keeps task pending when compression needs confirmation',
      () async {
        final task = videoTask(id: 'needs-confirmation', sortOrder: 0);
        final harness = QueueHarness(
          tasks: [task],
          commandBuilder: FakeCommandBuilder(
            error: CompressionConfirmationRequiredException('需要用户确认'),
          ),
        );

        final result = await harness.runner.start();

        expect(
          result.outcome,
          FfmpegQueueStartOutcome.compressionConfirmationRequired,
        );
        expect(
          harness.repository.taskById('needs-confirmation').status,
          TaskStatus.pending,
        );
        expect(harness.processStarter.starts, isEmpty);
      },
    );

    test('start forwards compression confirmation override', () async {
      final task = videoTask(id: 'confirmed', sortOrder: 0);
      final commandBuilder = FakeCommandBuilder();
      final harness = QueueHarness(
        tasks: [task],
        commandBuilder: commandBuilder,
      );

      final result = await harness.runner.start(allowExtremeCompression: true);

      expect(result.outcome, FfmpegQueueStartOutcome.started);
      expect(commandBuilder.allowExtremeCompressionValues, [true]);
    });

    test(
      'start builds command with prepared input while preserving original task',
      () async {
        final task = audioTask(id: 'ncm-task', inputPath: '/music/song.ncm');
        final preparer = FakeMediaInputPreparer('/tmp/framelean/song.flac');
        final harness = QueueHarness(
          tasks: [task],
          mediaInputPreparer: preparer,
        );

        final result = await harness.runner.start();

        expect(result.outcome, FfmpegQueueStartOutcome.started);
        expect(harness.processStarter.starts, hasLength(1));
        expect(
          harness.processStarter.starts.single.args,
          containsAllInOrder(['-i', '/tmp/framelean/song.flac']),
        );
        expect(
          harness.repository.taskById('ncm-task').inputPath,
          '/music/song.ncm',
        );
        expect(
          harness.repository.taskById('ncm-task').status,
          TaskStatus.running,
        );

        harness.processObserver.complete(
          'ncm-task',
          const FfmpegProcessObservation.completed(),
        );
        await harness.waitForTaskStatus('ncm-task', TaskStatus.completed);

        expect(preparer.cleanupCallCount, 1);
      },
    );

    test('start failure writes diagnostic footer to execution log', () async {
      final task = videoTask(id: 'start-fails', sortOrder: 0);
      final harness = QueueHarness(
        tasks: [task],
        processStarter: FakeProcessStarter(error: StateError('boom')),
      );

      final result = await harness.runner.start();
      final logContent = await harness.logFileFor(task.id).readAsString();

      expect(result.outcome, FfmpegQueueStartOutcome.processStartFailed);
      expect(
        harness.repository.taskById('start-fails').status,
        TaskStatus.failed,
      );
      expect(logContent, contains('任务失败'));
      expect(logContent, contains('FFmpeg 启动失败'));
      expect(logContent, contains('boom'));
    });
  });
}

class QueueHarness {
  final FakeMediaTaskRepository repository;
  final FakeTaskFolderRepository taskFolderRepository;
  final FakeProcessStarter processStarter;
  final FakeProcessController processController;
  final FakeProcessObserver processObserver;
  final Directory logDirectory;
  final List<String> completedNotifications = [];
  final List<String> failedNotifications = [];
  late final DefaultFfmpegTaskQueueRunner runner;

  QueueHarness({
    required List<MediaTask> tasks,
    Set<String>? existingPaths,
    ResolvedFfmpegRuntime runtime = const ResolvedFfmpegRuntime(
      ffmpeg: ResolvedFfmpegTool(
        path: '/bin/ffmpeg',
        source: FfmpegBinarySource.systemPath,
      ),
      ffprobe: null,
    ),
    FakeCommandBuilder? commandBuilder,
    MediaInputPreparer mediaInputPreparer = const NoopMediaInputPreparer(),
    FakeProcessStarter? processStarter,
    FakeProcessController? processController,
    FakeProcessObserver? processObserver,
    bool continuousExecutionEnabled = true,
    List<TaskFolder> folders = const [],
  }) : repository = FakeMediaTaskRepository(tasks),
       taskFolderRepository = FakeTaskFolderRepository(folders),
       processStarter = processStarter ?? FakeProcessStarter(),
       processController = processController ?? FakeProcessController(),
       processObserver = processObserver ?? FakeProcessObserver(),
       logDirectory = Directory.systemTemp.createTempSync(
         'framelean-queue-test-',
       ) {
    runner = DefaultFfmpegTaskQueueRunner(
      repository: repository,
      taskFolderRepository: taskFolderRepository,
      sourceFileChecker: FakeSourceFileChecker(
        existingPaths:
            existingPaths ?? tasks.map((task) => task.inputPath).toSet(),
      ),
      readRuntime: () async => runtime,
      commandBuilder: commandBuilder ?? FakeCommandBuilder(),
      mediaInputPreparer: mediaInputPreparer,
      processStarter: this.processStarter,
      processController: this.processController,
      processObserver: this.processObserver,
      createLogFilePath: (task, plan) async {
        return logFileFor(task.id).path;
      },
      onTaskCompleted: (task, [summary]) async {
        completedNotifications.add(task.id);
      },
      onTaskFailed: (task, [summary]) async {
        failedNotifications.add(task.id);
      },
      continuousExecutionEnabled: continuousExecutionEnabled,
      now: () async => DateTime.fromMillisecondsSinceEpoch(1000),
    );
  }

  File logFileFor(String taskId) {
    return File('${logDirectory.path}/$taskId.log');
  }

  Future<void> waitForTaskStatus(String taskId, TaskStatus status) {
    return waitForCondition(
      description: '$taskId to reach $status',
      condition: () => repository.taskById(taskId).status == status,
    );
  }

  Future<void> waitForStartedProcesses(int count) {
    return waitForCondition(
      description: '$count started FFmpeg processes',
      condition: () => processStarter.starts.length >= count,
    );
  }

  Future<void> waitForCondition({
    required String description,
    required bool Function() condition,
  }) async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      if (condition()) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    fail('Timed out waiting for $description');
  }
}

class FakeProcessController implements FfmpegProcessController {
  final List<String> pauseCalls = [];
  final List<String> resumeCalls = [];
  final List<String> terminateCalls = [];

  @override
  Future<void> pause(StartedFfmpegProcess startedProcess) async {
    pauseCalls.add((startedProcess.process as FakeProcess).taskId);
  }

  @override
  Future<void> resume(StartedFfmpegProcess startedProcess) async {
    resumeCalls.add((startedProcess.process as FakeProcess).taskId);
  }

  @override
  Future<void> terminate(StartedFfmpegProcess startedProcess) async {
    terminateCalls.add((startedProcess.process as FakeProcess).taskId);
  }
}

class FakeProcessObserver implements FfmpegProcessObserver {
  final Map<String, Completer<FfmpegProcessObservation>> completers = {};
  final List<String> observedTaskIds = [];

  @override
  Future<FfmpegProcessObservation> observe({
    required StartedFfmpegProcess startedProcess,
    required MediaTask task,
    required String? outputPath,
    ProgressMode progressMode = ProgressMode.timed,
    required Future<void> Function(double progress) onProgress,
  }) {
    observedTaskIds.add(task.id);
    unawaited(onProgress(0.5));
    final completer = Completer<FfmpegProcessObservation>();
    completers[task.id] = completer;
    return completer.future;
  }

  void complete(String taskId, FfmpegProcessObservation observation) {
    completers[taskId]?.complete(observation);
  }
}

MediaTask videoTask({String id = 'task', required int sortOrder}) {
  return MediaTask.draft(
    inputPath: '/videos/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    sortOrder: sortOrder,
  ).copyWith(id: id);
}

TaskFolder taskFolder({required String id, required int sortOrder}) {
  return TaskFolder(
    id: id,
    name: id,
    mediaKind: MediaKind.video,
    sortOrder: sortOrder,
    defaultConfig: MediaTaskConfig.initialVideo(),
    createdAt: sortOrder,
    updatedAt: sortOrder,
  );
}

MediaTask imageTask({
  required String id,
  required String inputPath,
  required int sortOrder,
}) {
  return MediaTask.draft(
    inputPath: inputPath,
    fileName: inputPath.split('/').last,
    mediaKind: MediaKind.image,
    sortOrder: sortOrder,
  ).copyWith(id: id);
}

MediaTask audioTask({required String id, required String inputPath}) {
  return MediaTask.draft(
    inputPath: inputPath,
    fileName: inputPath.split('/').last,
    mediaKind: MediaKind.audio,
    sortOrder: 0,
  ).copyWith(id: id);
}

FfmpegCommandPlan imageFallbackPlan({
  required String inputPath,
  required String firstOutputPath,
  required String fallbackOutputPath,
}) {
  final fallbackArgs = [
    '-hide_banner',
    '-i',
    inputPath,
    '-c:v',
    'libwebp',
    fallbackOutputPath,
  ];
  return FfmpegCommandPlan(
    args: fallbackArgs,
    outputPath: firstOutputPath,
    logHint: '图片 fallback 测试命令',
    steps: [
      FfmpegCommandStep(
        args: ['-hide_banner', '-i', inputPath, firstOutputPath],
        label: '源格式压缩',
        outputPath: firstOutputPath,
        progressMode: ProgressMode.step,
        completionPolicy:
            FfmpegStepCompletionPolicy.completeIfOutputSmallerThanSource,
      ),
      FfmpegCommandStep(
        args: fallbackArgs,
        label: 'WebP 重试',
        outputPath: fallbackOutputPath,
        progressMode: ProgressMode.step,
        completionPolicy:
            FfmpegStepCompletionPolicy.failIfOutputNotSmallerThanSource,
        policyTagsOnStart: const {MediaTaskPolicyTag.imageFormatFallback},
      ),
    ],
  );
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  final List<MediaTask> tasks;

  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  @override
  Future<void> deleteTaskById(String taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async {
    return [...tasks]..sort((first, second) {
      final order = first.sortOrder.compareTo(second.sortOrder);
      if (order != 0) {
        return order;
      }

      return first.createdAt.compareTo(second.createdAt);
    });
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
    final index = tasks.indexWhere(
      (existingTask) => existingTask.id == task.id,
    );
    if (index == -1) {
      tasks.add(task);
      return;
    }

    tasks[index] = task;
  }

  MediaTask taskById(String id) {
    return tasks.singleWhere((task) => task.id == id);
  }
}

class FakeTaskFolderRepository implements TaskFolderRepository {
  FakeTaskFolderRepository([List<TaskFolder> initialFolders = const []])
    : folders = [...initialFolders];

  final List<TaskFolder> folders;

  @override
  Future<void> clearAllFolders() async {
    folders.clear();
  }

  @override
  Future<void> deleteFolderById(String folderId) async {
    folders.removeWhere((folder) => folder.id == folderId);
  }

  @override
  Future<List<TaskFolder>> loadAllFolders() async {
    return [...folders]..sort((first, second) {
      final order = first.sortOrder.compareTo(second.sortOrder);
      if (order != 0) {
        return order;
      }
      return first.createdAt.compareTo(second.createdAt);
    });
  }

  @override
  Future<void> saveFolder(TaskFolder folder) async {
    final index = folders.indexWhere((existing) => existing.id == folder.id);
    if (index == -1) {
      folders.add(folder);
      return;
    }
    folders[index] = folder;
  }

  @override
  Future<void> updateFolderSortOrders(
    List<TaskFolderSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final index = folders.indexWhere(
        (folder) => folder.id == update.folderId,
      );
      if (index == -1) {
        continue;
      }
      folders[index] = folders[index].copyWith(sortOrder: update.sortOrder);
    }
  }
}

class FakeSourceFileChecker implements SourceFileChecker {
  final Set<String> existingPaths;

  const FakeSourceFileChecker({required this.existingPaths});

  @override
  Future<bool> exists(String inputPath) async {
    return existingPaths.contains(inputPath);
  }
}

class FakeCommandBuilder implements FfmpegCommandBuilder {
  final Object? error;
  final List<List<String>>? stepArgs;
  final FfmpegCommandPlan? plan;
  final List<bool> allowExtremeCompressionValues = [];

  FakeCommandBuilder({this.error, this.stepArgs, this.plan});

  @override
  FfmpegCommandPlan build(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    allowExtremeCompressionValues.add(allowExtremeCompression);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    final plan = this.plan;
    if (plan != null) {
      return plan;
    }

    final defaultArgs = [
      '-hide_banner',
      '-i',
      task.inputPath,
      '/videos/${task.id}.out.mp4',
    ];
    final stepArgs = this.stepArgs;

    return FfmpegCommandPlan(
      args: stepArgs?.last ?? defaultArgs,
      steps: stepArgs
          ?.asMap()
          .entries
          .map(
            (entry) => FfmpegCommandStep(
              args: entry.value,
              label: '测试步骤 ${entry.key + 1}',
              outputPath: entry.key == stepArgs.length - 1
                  ? '/videos/${task.id}.out.mp4'
                  : null,
            ),
          )
          .toList(),
      outputPath: '/videos/${task.id}.out.mp4',
      logHint: '测试命令',
    );
  }
}

class FakeMediaInputPreparer implements MediaInputPreparer {
  final String preparedInputPath;
  int cleanupCallCount = 0;

  FakeMediaInputPreparer(this.preparedInputPath);

  @override
  Future<PreparedMediaInput> prepare(
    MediaTask task, {
    required MediaInputPreparationPurpose purpose,
  }) async {
    return PreparedMediaInput(
      task: task.copyWith(inputPath: preparedInputPath),
    );
  }

  @override
  Future<void> cleanup(PreparedMediaInput preparedInput) async {
    cleanupCallCount += 1;
  }
}

class FakeProcessStart {
  final String taskId;
  final String ffmpegPath;
  final List<String> args;
  final File logFile;
  final FakeProcess process;

  const FakeProcessStart({
    required this.taskId,
    required this.ffmpegPath,
    required this.args,
    required this.logFile,
    required this.process,
  });
}

class FakeProcessStarter implements FfmpegProcessStarter {
  final Object? error;
  final List<FakeProcessStart> starts = [];

  FakeProcessStarter({this.error});

  @override
  Future<StartedFfmpegProcess> start({
    required String ffmpegPath,
    required List<String> args,
    required File logFile,
  }) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }

    final inputIndex = args.indexOf('-i');
    final inputPath = inputIndex == -1 ? '' : args[inputIndex + 1];
    final taskId = inputPath.split('/').last.split('.').first;
    final process = FakeProcess(taskId);
    starts.add(
      FakeProcessStart(
        taskId: taskId,
        ffmpegPath: ffmpegPath,
        args: args,
        logFile: logFile,
        process: process,
      ),
    );
    return StartedFfmpegProcess(process: process, logFile: logFile);
  }

  FakeProcess processFor(String taskId) {
    return starts.singleWhere((start) => start.taskId == taskId).process;
  }
}

class FakeProcess implements Process {
  final String taskId;
  final List<ProcessSignal> signals = [];

  FakeProcess(this.taskId);

  @override
  Future<int> get exitCode => Completer<int>().future;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    return true;
  }
}
