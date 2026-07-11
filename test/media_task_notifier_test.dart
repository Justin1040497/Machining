import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/app_settings/apply_output_settings_to_existing_tasks_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/providers/input_runtime_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';

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
      expect(task.config.outputFileName, 'source-压缩');
    });

    test(
      'increments output template version for repeated source imports',
      () async {
        final existingTask = readyVideoTask(id: 'source', sortOrder: 0);
        final repository = FakeMediaTaskRepository([existingTask]);
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {existingTask.inputPath},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
          appSettingsRepository: FakeAppSettingsRepository(
            AppSettings.initial().copyWith(
              defaultOutputFileNameTemplate: '{source}-{version}',
            ),
          ),
        );

        await container.read(mediaTaskListProvider.future);
        final task = await container
            .read(mediaTaskListProvider.notifier)
            .createDraftFromPath(existingTask.inputPath);

        expect(task.config.outputFileName, 'source-v2');
      },
    );

    test(
      'applies output settings to retryable tasks without resetting media config',
      () async {
        final renamedTask = readyVideoTask(id: 'source', sortOrder: 0).copyWith(
          fileName: '1.mp4',
          config: systemOutputVideoConfig(
            outputDirectory: '/old',
            outputFileName: 'old',
            videoCodec: VideoCodec.h264,
          ),
        );
        final failedTask = readyVideoTask(id: 'failed', sortOrder: 1).copyWith(
          status: TaskStatus.failed,
          config: systemOutputVideoConfig(
            outputDirectory: '/old',
            outputFileName: 'old',
            videoCodec: VideoCodec.h264,
          ),
        );
        final cancelledTask = readyVideoTask(id: 'cancelled', sortOrder: 2)
            .copyWith(
              status: TaskStatus.cancelled,
              config: systemOutputVideoConfig(
                outputDirectory: '/old',
                outputFileName: 'old',
                videoCodec: VideoCodec.h264,
              ),
            );
        final runningTask = readyVideoTask(id: 'running', sortOrder: 3)
            .copyWith(
              status: TaskStatus.running,
              config: systemOutputVideoConfig(
                outputDirectory: '/old',
                outputFileName: 'old',
                videoCodec: VideoCodec.h264,
              ),
            );
        final repository = FakeMediaTaskRepository([
          renamedTask,
          failedTask,
          cancelledTask,
          runningTask,
        ]);
        await ApplyOutputSettingsToExistingTasksUseCase(
          repository: repository,
        ).call(
          AppSettings.initial().copyWith(
            defaultOutputDirectory: '/exports',
            saveOutputToSourceDirectory: false,
            defaultOutputFileNameTemplate: '{source}-{codec}',
            defaultOutputVideoCodec: VideoCodec.hevc,
          ),
        );

        final updatedTask = repository.taskById(renamedTask.id);
        expect(
          updatedTask.config.outputLocationMode,
          OutputLocationMode.system,
        );
        expect(updatedTask.config.outputDirectory, isEmpty);
        expect(updatedTask.config.outputFileName, 'source-h264');
        expect(updatedTask.config.videoCodec, VideoCodec.h264);
        expect(updatedTask.config.outputFileName, isNot(contains('1-')));
        expect(
          repository.taskById(failedTask.id).config.outputDirectory,
          isEmpty,
        );
        expect(
          repository.taskById(cancelledTask.id).config.outputDirectory,
          isEmpty,
        );
        expect(
          repository.taskById(runningTask.id).config.outputDirectory,
          '/old',
        );
      },
    );

    test('retry applies the latest output settings', () async {
      final failedTask = readyVideoTask(id: 'source', sortOrder: 0).copyWith(
        fileName: '1.mp4',
        status: TaskStatus.failed,
        config: systemOutputVideoConfig(
          outputDirectory: '/old',
          outputFileName: 'old',
          videoCodec: VideoCodec.h264,
        ),
      );
      final repository = FakeMediaTaskRepository([failedTask]);
      final container = testContainer(
        repository: repository,
        sourceFileChecker: FakeSourceFileChecker(
          existingPaths: {failedTask.inputPath},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
        appSettingsRepository: FakeAppSettingsRepository(
          AppSettings.initial().copyWith(
            defaultOutputDirectory: '/retry-output',
            saveOutputToSourceDirectory: false,
            defaultOutputFileNameTemplate: '{source}-{codec}',
            defaultOutputVideoCodec: VideoCodec.hevc,
          ),
        ),
      );

      await container.read(mediaTaskListProvider.future);
      await container
          .read(mediaTaskListProvider.notifier)
          .retryTaskById(failedTask.id);

      final updatedTask = repository.taskById(failedTask.id);
      expect(updatedTask.status, TaskStatus.analyzing);
      expect(updatedTask.config.outputLocationMode, OutputLocationMode.system);
      expect(updatedTask.config.outputDirectory, isEmpty);
      expect(updatedTask.config.outputFileName, 'source-h264');
      expect(updatedTask.config.videoCodec, VideoCodec.h264);
      expect(updatedTask.config.outputFileName, isNot(contains('1-')));
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
      taskFolderRepositoryProvider.overrideWithValue(
        FakeTaskFolderRepository(),
      ),
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

MediaTaskConfig systemOutputVideoConfig({
  required String outputDirectory,
  required String outputFileName,
  required VideoCodec videoCodec,
}) {
  return MediaTaskConfig.fromVideoTaskConfig(
    VideoTaskConfig.initial().copyWith(
      outputDirectory: outputDirectory,
      outputFileName: outputFileName,
      videoCodec: videoCodec,
    ),
  ).copyWith(outputLocationMode: OutputLocationMode.system);
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

  MediaTask taskById(String id) {
    return tasks.singleWhere((task) => task.id == id);
  }
}

class FakeTaskFolderRepository implements TaskFolderRepository {
  final List<TaskFolder> folders = [];

  @override
  Future<void> clearAllFolders() async {
    folders.clear();
  }

  @override
  Future<void> deleteFolderById(String folderId) async {
    folders.removeWhere((folder) => folder.id == folderId);
  }

  @override
  Future<List<TaskFolder>> loadAllFolders() async => [...folders];

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
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startSingleTask(
    String taskId, {
    bool allowExtremeCompression = false,
  }) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
    );
  }

  @override
  Future<FfmpegQueueStartResult> startFolderQueue(
    String folderId, {
    bool allowExtremeCompression = false,
  }) async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.notReady,
    );
  }
}
