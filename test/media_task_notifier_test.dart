import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/repositories/app_settings_repository.dart';
import 'package:machining/application/repositories/media_task_repository.dart';
import 'package:machining/application/services/ffmpeg_task_queue_runner.dart';
import 'package:machining/application/services/source_file_checker.dart';
import 'package:machining/application/services/source_file_fingerprint_reader.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/features/workbench/providers/media_task_notifier.dart';
import 'package:machining/infrastructure/providers/drift_provider.dart';
import 'package:machining/infrastructure/providers/ffmpeg_provider.dart';

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
    sortOrder: 0,
    createdAt: 1,
  );
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  final List<MediaTask> tasks;
  int replaceAllCallCount = 0;

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
    replaceAllCallCount += 1;
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
