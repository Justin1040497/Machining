import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/task_folder_use_cases.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';

void main() {
  test('applies folder config to non execution snapshot tasks', () async {
    final folder = testFolder();
    final oldConfig = MediaTaskConfig.initialVideo();
    final newConfig = MediaTaskConfig.initialVideo().copyWith(
      videoCodec: VideoCodec.hevc,
    );
    final running = videoTask(
      id: 'running',
      folderId: folder.id,
      status: TaskStatus.running,
      config: oldConfig,
    );
    final paused = videoTask(
      id: 'paused',
      folderId: folder.id,
      status: TaskStatus.paused,
      config: oldConfig,
    );
    final analyzing = videoTask(
      id: 'analyzing',
      folderId: folder.id,
      status: TaskStatus.analyzing,
      config: oldConfig,
    );
    final completed = videoTask(
      id: 'completed',
      folderId: folder.id,
      status: TaskStatus.completed,
      config: oldConfig,
    );
    final pending = videoTask(
      id: 'pending',
      folderId: folder.id,
      status: TaskStatus.pending,
      config: oldConfig,
    );
    final missing = videoTask(
      id: 'missing',
      folderId: folder.id,
      status: TaskStatus.missingSource,
      config: oldConfig,
    );
    final repository = FakeMediaTaskRepository([
      running,
      paused,
      analyzing,
      completed,
      pending,
      missing,
    ]);
    final folderRepository = FakeTaskFolderRepository([folder]);

    await ApplyTaskFolderConfigUseCase(
      mediaTaskRepository: repository,
      taskFolderRepository: folderRepository,
    ).call(folderId: folder.id, config: newConfig);

    expect(
      folderRepository.folderById(folder.id).defaultConfig.videoCodec,
      VideoCodec.hevc,
    );
    expect(repository.taskById('completed').config.videoCodec, VideoCodec.hevc);
    expect(repository.taskById('pending').config.videoCodec, VideoCodec.hevc);
    expect(repository.taskById('missing').config.videoCodec, VideoCodec.hevc);
    expect(repository.taskById('running').config.videoCodec, VideoCodec.h264);
    expect(repository.taskById('paused').config.videoCodec, VideoCodec.h264);
    expect(repository.taskById('analyzing').config.videoCodec, VideoCodec.h264);
  });

  test(
    'retries terminal folder tasks and preserves their current config',
    () async {
      final folder = testFolder();
      final config = MediaTaskConfig.initialVideo().copyWith(
        videoCodec: VideoCodec.hevc,
      );
      final completed = readyVideoTask(
        id: 'completed',
        folderId: folder.id,
        status: TaskStatus.completed,
        config: config,
      );
      final failed = readyVideoTask(
        id: 'failed',
        folderId: folder.id,
        status: TaskStatus.failed,
        config: config,
      );
      final cancelled = readyVideoTask(
        id: 'cancelled',
        folderId: folder.id,
        status: TaskStatus.cancelled,
        config: config,
      );
      final pending = readyVideoTask(
        id: 'pending',
        folderId: folder.id,
        status: TaskStatus.pending,
        config: config,
      );
      final repository = FakeMediaTaskRepository([
        completed,
        failed,
        cancelled,
        pending,
      ]);
      final fingerprintReader = FakeSourceFileFingerprintReader();

      final result = await RetryTaskFolderTerminalTasksUseCase(
        repository: repository,
        sourceFileChecker: FakeSourceFileChecker(
          existingPaths: {
            completed.inputPath,
            failed.inputPath,
            cancelled.inputPath,
            pending.inputPath,
          },
        ),
        fingerprintReader: fingerprintReader,
      ).call(folder.id);

      expect(result.taskIdsNeedingAnalysis, [
        'completed',
        'failed',
        'cancelled',
      ]);
      expect(repository.taskById('completed').status, TaskStatus.analyzing);
      expect(repository.taskById('failed').status, TaskStatus.analyzing);
      expect(repository.taskById('cancelled').status, TaskStatus.analyzing);
      expect(repository.taskById('pending').status, TaskStatus.pending);
      expect(
        repository.taskById('completed').config.videoCodec,
        VideoCodec.hevc,
      );
      expect(fingerprintReader.readPaths, [
        completed.inputPath,
        failed.inputPath,
        cancelled.inputPath,
      ]);
    },
  );

  test('starts the first startable folder task through queue runner', () async {
    final folder = testFolder();
    final blockedPending = videoTask(
      id: 'blocked',
      folderId: folder.id,
      status: TaskStatus.pending,
    );
    final paused = readyVideoTask(
      id: 'paused',
      folderId: folder.id,
      status: TaskStatus.paused,
      folderSortOrder: 1,
    );
    final pending = readyVideoTask(
      id: 'pending',
      folderId: folder.id,
      status: TaskStatus.pending,
      folderSortOrder: 2,
    );
    final queueRunner = FakeFfmpegTaskQueueRunner();

    await StartNextTaskInFolderUseCase(
      repository: FakeMediaTaskRepository([blockedPending, pending, paused]),
      queueRunner: queueRunner,
    ).call(folder.id);

    expect(queueRunner.startedTaskIds, ['paused']);
  });
}

const testFingerprint = SourceFileFingerprint(
  fileSize: 100 * 1024 * 1024,
  lastModifiedAt: 1,
);

TaskFolder testFolder() {
  return TaskFolder(
    id: 'folder-1',
    name: '视频任务夹（1）',
    mediaKind: MediaKind.video,
    sortOrder: 0,
    defaultConfig: MediaTaskConfig.initialVideo(),
    createdAt: 1,
    updatedAt: 1,
  );
}

MediaTask videoTask({
  required String id,
  String? folderId,
  int? folderSortOrder,
  TaskStatus status = TaskStatus.pending,
  MediaTaskConfig? config,
}) {
  return MediaTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status,
    config: config ?? MediaTaskConfig.initialVideo(),
    progress: 0,
    sortOrder: 0,
    folderId: folderId,
    folderSortOrder: folderSortOrder,
    createdAt: 1,
  );
}

MediaTask readyVideoTask({
  required String id,
  required String folderId,
  int? folderSortOrder,
  TaskStatus status = TaskStatus.pending,
  MediaTaskConfig? config,
}) {
  return videoTask(
    id: id,
    folderId: folderId,
    folderSortOrder: folderSortOrder,
    status: status,
    config: config,
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
    final index = tasks.indexWhere(
      (existingTask) => existingTask.id == task.id,
    );
    if (index == -1) {
      tasks.add(task);
      return;
    }
    tasks[index] = task;
  }

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {}

  MediaTask taskById(String id) {
    return tasks.singleWhere((task) => task.id == id);
  }
}

class FakeTaskFolderRepository implements TaskFolderRepository {
  FakeTaskFolderRepository(List<TaskFolder> initialFolders)
    : folders = [...initialFolders];

  final List<TaskFolder> folders;

  @override
  Future<void> deleteFolderById(String folderId) async {
    folders.removeWhere((folder) => folder.id == folderId);
  }

  @override
  Future<List<TaskFolder>> loadAllFolders() async {
    return [...folders];
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

  TaskFolder folderById(String id) {
    return folders.singleWhere((folder) => folder.id == id);
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
  final List<String> readPaths = [];

  @override
  Future<SourceFileFingerprint> read(String inputPath) async {
    readPaths.add(inputPath);
    return testFingerprint;
  }
}

class FakeFfmpegTaskQueueRunner implements FfmpegTaskQueueRunner {
  final List<String> startedTaskIds = [];

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
  Future<FfmpegQueueStartResult> pauseAllRunningTasks() async {
    return const FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.paused,
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
    startedTaskIds.add(taskId);
    return FfmpegQueueStartResult(
      outcome: FfmpegQueueStartOutcome.started,
      task: null,
    );
  }
}
