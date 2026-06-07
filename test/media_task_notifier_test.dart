import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/infrastructure/providers/execution_provider.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';

void main() {
  group('MediaTaskListNotifier', () {
    test('keeps already missing source tasks while loading history', () async {
      final missingTask = videoTask(
        status: TaskStatus.missingSource,
      ).copyWith(sourceFileFingerprint: testFingerprint);
      final repository = FakeMediaTaskRepository([missingTask]);
      final fingerprintReader = FakeSourceFileFingerprintReader();
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(existingPaths: {}),
        fingerprintReader: fingerprintReader,
      );

      final tasks = await container.read(mediaTaskListProvider.future);

      expect(tasks, hasLength(1));
      expect(tasks.single.id, missingTask.id);
      expect(tasks.single.status, TaskStatus.missingSource);
      expect(tasks.single.config, missingTask.config);
      expect(repository.replaceAllCallCount, 0);
      expect(fingerprintReader.readPaths, isEmpty);
    });

    test('marks missing source tasks without dropping the task', () async {
      final pendingTask = videoTask(
        status: TaskStatus.pending,
      ).copyWith(sourceFileFingerprint: testFingerprint);
      final repository = FakeMediaTaskRepository([pendingTask]);
      final fingerprintReader = FakeSourceFileFingerprintReader();
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(existingPaths: {}),
        fingerprintReader: fingerprintReader,
      );

      final tasks = await container.read(mediaTaskListProvider.future);

      expect(tasks, hasLength(1));
      expect(tasks.single.id, pendingTask.id);
      expect(tasks.single.status, TaskStatus.missingSource);
      expect(repository.replaceAllCallCount, 1);
      expect(repository.tasks.single.status, TaskStatus.missingSource);
      expect(fingerprintReader.readPaths, isEmpty);
    });

    test('creates new drafts from app settings defaults', () async {
      final repository = FakeMediaTaskRepository([]);
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(
          existingPaths: {'/videos/source.mp4'},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
        appSettingsRepository: FakeAppSettingsRepository(
          AppSettings.initial().copyWith(
            defaultOutputDirectory: '/Users/leftzhou/Desktop',
            saveOutputToSourceDirectory: true,
            defaultOutputVideoCodec: VideoCodec.hevc,
            defaultSmartPreset: SmartCompressionPreset.chat,
          ),
        ),
      );

      await container.read(mediaTaskListProvider.future);
      final task = await container
          .read(mediaTaskListProvider.notifier)
          .createDraftFromPath('/videos/source.mp4');

      expect(task.config.outputDirectory, isEmpty);
      expect(task.config.videoCodec, VideoCodec.hevc);
      expect(task.config.smartPreset, SmartCompressionPreset.chat);
      expect(task.config.outputFileName, contains('source'));
      expect(task.config.outputFileName, contains('hevc'));
    });

    test(
      'reorders tasks by updating sort orders without replacing all tasks',
      () async {
        final firstTask = readyVideoTask(id: 'first', sortOrder: 0);
        final secondTask = readyVideoTask(id: 'second', sortOrder: 1);
        final thirdTask = readyVideoTask(id: 'third', sortOrder: 2);
        final repository = FakeMediaTaskRepository([
          firstTask,
          secondTask,
          thirdTask,
        ]);
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {
              firstTask.inputPath,
              secondTask.inputPath,
              thirdTask.inputPath,
            },
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
        );

        await container.read(mediaTaskListProvider.future);
        await container
            .read(mediaTaskListProvider.notifier)
            .reorderTasks(oldIndex: 0, newIndex: 3);

        final tasks = container.read(mediaTaskListProvider).requireValue;
        expect(tasks.map((task) => task.id), ['second', 'third', 'first']);
        expect(repository.updateSortOrdersCallCount, 1);
        expect(repository.replaceAllCallCount, 0);
        expect(repository.taskById('first').sortOrder, 2);
        expect(repository.taskById('second').sortOrder, 0);
        expect(repository.taskById('third').sortOrder, 1);
      },
    );

    test('reloads repository order when reorder persistence fails', () async {
      final firstTask = readyVideoTask(id: 'first', sortOrder: 0);
      final secondTask = readyVideoTask(id: 'second', sortOrder: 1);
      final repository = FakeMediaTaskRepository([firstTask, secondTask])
        ..updateSortOrdersError = StateError('sort failed');
      final container = testContainer(
        repository: repository,
        sourceFileChecker: FakeSourceFileChecker(
          existingPaths: {firstTask.inputPath, secondTask.inputPath},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
      );

      await container.read(mediaTaskListProvider.future);

      await expectLater(
        container
            .read(mediaTaskListProvider.notifier)
            .reorderTasks(oldIndex: 0, newIndex: 2),
        throwsStateError,
      );

      final tasks = container.read(mediaTaskListProvider).requireValue;
      expect(tasks.map((task) => task.id), ['first', 'second']);
      expect(repository.updateSortOrdersCallCount, 1);
    });
  });
}

ProviderContainer testContainer({
  required FakeMediaTaskRepository repository,
  required FakeSourceFileChecker sourceFileChecker,
  required FakeSourceFileFingerprintReader fingerprintReader,
  FakeAppSettingsRepository? appSettingsRepository,
}) {
  return ProviderContainer.test(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(
        appSettingsRepository ??
            FakeAppSettingsRepository(AppSettings.initial()),
      ),
      mediaTaskRepositoryProvider.overrideWithValue(repository),
      sourceFileCheckerProvider.overrideWithValue(sourceFileChecker),
      sourceFileFingerprintReaderProvider.overrideWithValue(fingerprintReader),
      ffmpegTaskQueueRunnerProvider.overrideWithValue(
        FakeFfmpegTaskQueueRunner(),
      ),
    ],
  );
}

const testFingerprint = SourceFileFingerprint(
  fileSize: 100 * 1024 * 1024,
  lastModifiedAt: 1,
);

MediaTask videoTask({
  String id = 'task-1',
  String inputPath = '/videos/missing.mp4',
  TaskStatus status = TaskStatus.pending,
  VideoTaskConfig? config,
  int sortOrder = 0,
}) {
  return MediaTask(
    id: id,
    inputPath: inputPath,
    fileName: 'missing.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status,
    config: config ?? VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: sortOrder,
    createdAt: 1,
  );
}

MediaTask readyVideoTask({required String id, required int sortOrder}) {
  return videoTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    sortOrder: sortOrder,
  ).copyWith(
    sourceFileFingerprint: testFingerprint,
    analysisResult: MediaAnalysisResult(durationMs: 1000),
    analysisUpdatedAt: 1,
  );
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  final List<MediaTask> tasks;
  int replaceAllCallCount = 0;
  int updateSortOrdersCallCount = 0;
  Object? updateSortOrdersError;

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
    replaceAllCallCount += 1;
    this.tasks
      ..clear()
      ..addAll(tasks);
  }

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {
    updateSortOrdersCallCount += 1;
    final error = updateSortOrdersError;
    if (error != null) {
      throw error;
    }

    for (final update in updates) {
      final index = tasks.indexWhere((task) => task.id == update.taskId);
      if (index == -1) {
        continue;
      }

      tasks[index] = tasks[index].copyWith(sortOrder: update.sortOrder);
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

  MediaTask taskById(String id) {
    return tasks.singleWhere((task) => task.id == id);
  }
}

class FakeSourceFileChecker implements SourceFileChecker {
  const FakeSourceFileChecker({required this.existingPaths});

  final Set<String> existingPaths;

  @override
  Future<bool> exists(String inputPath) async {
    return existingPaths.contains(inputPath);
  }
}

class FakeSourceFileFingerprintReader implements SourceFileFingerprintReader {
  FakeSourceFileFingerprintReader({this.fingerprint});

  final SourceFileFingerprint? fingerprint;
  final List<String> readPaths = [];

  @override
  Future<SourceFileFingerprint> read(String inputPath) async {
    readPaths.add(inputPath);
    final value = fingerprint;
    if (value != null) {
      return value;
    }

    throw StateError('不应该读取缺失源文件指纹: $inputPath');
  }
}

class FakeAppSettingsRepository implements AppSettingsRepository {
  FakeAppSettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}

class FakeFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  @override
  String? foregroundTaskId;

  @override
  FfmpegQueueStatus queueStatus = FfmpegQueueStatus.idle;

  @override
  Future<void> cancelAllExecutions() async {}

  @override
  Future<FfmpegQueueStartResult> cancelTask(String taskId) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.cancelled,
    );
  }

  @override
  Future<FfmpegQueueStartResult> pauseTask(String taskId) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
    );
  }

  @override
  Future<FfmpegQueueStartResult> pauseAllRunningTasks() async {
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
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startOrResumeTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
    );
  }
}
