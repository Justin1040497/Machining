import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_status.dart';

void main() {
  group('DefaultFfmpegTaskQueueRunner', () {
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
        expect(harness.processStarter.processFor('first').signals, [
          ProcessSignal.sigstop,
        ]);
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
        expect(harness.processStarter.processFor('first').signals, [
          ProcessSignal.sigstop,
          ProcessSignal.sigcont,
        ]);
        expect(harness.processStarter.processFor('second').signals, [
          ProcessSignal.sigstop,
        ]);
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
        expect(harness.processStarter.processFor('first').signals, [
          ProcessSignal.sigstop,
        ]);
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
        expect(harness.processStarter.processFor('first').signals, [
          ProcessSignal.sigstop,
          ProcessSignal.sigterm,
        ]);
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
        expect(harness.processStarter.processFor('first').signals, [
          ProcessSignal.sigstop,
          ProcessSignal.sigterm,
        ]);
        expect(harness.processStarter.processFor('second').signals, [
          ProcessSignal.sigterm,
        ]);
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
      await pumpEventQueue();

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
      await pumpEventQueue();

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
      await pumpEventQueue();

      expect(
        harness.repository.taskById('two-pass').status,
        TaskStatus.completed,
      );
      expect(harness.runner.foregroundTaskId, isNull);
    });

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
  });
}

class QueueHarness {
  final FakeMediaTaskRepository repository;
  final FakeProcessStarter processStarter;
  final FakeProcessObserver processObserver;
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
    FakeProcessStarter? processStarter,
    FakeProcessObserver? processObserver,
    bool continuousExecutionEnabled = true,
  }) : repository = FakeMediaTaskRepository(tasks),
       processStarter = processStarter ?? FakeProcessStarter(),
       processObserver = processObserver ?? FakeProcessObserver() {
    runner = DefaultFfmpegTaskQueueRunner(
      repository: repository,
      sourceFileChecker: FakeSourceFileChecker(
        existingPaths:
            existingPaths ?? tasks.map((task) => task.inputPath).toSet(),
      ),
      readRuntime: () async => runtime,
      commandBuilder: commandBuilder ?? FakeCommandBuilder(),
      processStarter: this.processStarter,
      processObserver: this.processObserver,
      createLogFilePath: (task, plan) async {
        return File(
          '${Directory.systemTemp.path}/framelean-test-${task.id}.log',
        ).path;
      },
      continuousExecutionEnabled: continuousExecutionEnabled,
      now: () async => DateTime.fromMillisecondsSinceEpoch(1000),
    );
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
  final List<bool> allowExtremeCompressionValues = [];

  FakeCommandBuilder({this.error, this.stepArgs});

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
    final process = FakeProcess();
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
  final List<ProcessSignal> signals = [];

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
