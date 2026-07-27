import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_arrangement_persistence.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/execution/execution_queue_result.dart'
    show EngineQueueStartOutcome;
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/place_workbench_top_level_item_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/task_folder_use_cases.dart';
import 'package:framelean/application/use_cases/media_tasks/submit_engine_execution_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_folder_compatibility_class.dart';
import 'package:framelean/domain/enums/task_folder_origin.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';

void main() {
  test('places inserted top-level task below unfinished items', () async {
    final pending = videoTask(id: 'pending', sortOrder: 0);
    final completed = videoTask(
      id: 'completed',
      sortOrder: 1,
      status: TaskStatus.completed,
    );
    final inserted = videoTask(id: 'inserted', sortOrder: 2);
    final repository = FakeMediaTaskRepository([pending, completed, inserted]);
    final folderRepository = FakeTaskFolderRepository([]);

    await PlaceWorkbenchTopLevelItemUseCase(
      mediaTaskRepository: repository,
      taskFolderRepository: folderRepository,
    ).call(const WorkbenchInsertedItem.task('inserted'));

    expect(repository.taskById('pending').sortOrder, 0);
    expect(repository.taskById('inserted').sortOrder, 1);
    expect(repository.taskById('completed').sortOrder, 2);
  });

  test('organizes imported batch by per-kind counts', () async {
    MediaTask importedTask(String id, MediaKind mediaKind, int sortOrder) {
      return MediaTask.draft(
        inputPath: '/imports/$id',
        fileName: id,
        mediaKind: mediaKind,
        sortOrder: sortOrder,
      ).copyWith(id: id);
    }

    final repository = FakeMediaTaskRepository([
      importedTask('single.mp4', MediaKind.video, 0),
      importedTask('first.mp3', MediaKind.audio, 1),
      importedTask('second.wav', MediaKind.audio, 2),
      importedTask('first.jpg', MediaKind.image, 3),
      importedTask('second.png', MediaKind.image, 4),
    ]);
    final folderRepository = FakeTaskFolderRepository([]);

    final result = await OrganizeImportedMediaBatchUseCase(
      mediaTaskRepository: repository,
      taskFolderRepository: folderRepository,
    ).call(taskIds: repository.tasks.map((task) => task.id).toList());

    expect(result.folders.map((folder) => folder.mediaKind), [
      MediaKind.audio,
      MediaKind.image,
    ]);
    expect(repository.taskById('single.mp4').folderId, isNull);
    expect(repository.taskById('first.mp3').folderId, isNotNull);
    expect(repository.taskById('second.wav').folderId, isNotNull);
    expect(repository.taskById('first.jpg').folderId, isNotNull);
    expect(repository.taskById('second.png').folderId, isNotNull);
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
        status: TaskStatus.executionFailed,
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
        status: TaskStatus.ready,
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

      expect(result.taskIdsNeedingAnalysis, isEmpty);
      expect(repository.taskById('completed').status, TaskStatus.ready);
      expect(repository.taskById('failed').status, TaskStatus.ready);
      expect(repository.taskById('cancelled').status, TaskStatus.ready);
      expect(repository.taskById('pending').status, TaskStatus.ready);
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

  test('submits every folder task through FEngine in folder order', () async {
    final folder = testFolder();
    final blockedPending = videoTask(
      id: 'blocked',
      folderId: folder.id,
      status: TaskStatus.ready,
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
      status: TaskStatus.ready,
      folderSortOrder: 2,
    );
    final submitter = FakeEngineExecutionSubmitter();
    final repository = FakeMediaTaskRepository([
      blockedPending,
      pending,
      paused,
    ]);

    final result = await StartNextTaskInFolderUseCase(
      executionCoordinator: MediaTaskExecutionCoordinator(
        repository: repository,
        taskFolderRepository: FakeTaskFolderRepository([folder]),
        submitEngineExecution: submitter,
      ),
    ).call(folder.id);

    expect(submitter.taskIds, [blockedPending.id, paused.id, pending.id]);
    expect(result.outcome, EngineQueueStartOutcome.invalidTaskState);
    expect(result.message, contains('3 个任务缺少 FEngine 配置'));
  });

  test(
    'removing a folder task appends it after every top-level item',
    () async {
      final sourceFolder = testFolder();
      final trailingFolder = testFolder().copyWith(
        id: 'folder-2',
        name: '视频任务夹（2）',
        sortOrder: 8,
      );
      final looseTask = videoTask(id: 'loose', sortOrder: 3);
      final folderTask = videoTask(
        id: 'inside',
        folderId: sourceFolder.id,
        folderSortOrder: 0,
      );
      final repository = FakeMediaTaskRepository([looseTask, folderTask]);

      await RemoveTaskFromFolderUseCase(
        repository: repository,
        taskFolderRepository: FakeTaskFolderRepository([
          sourceFolder,
          trailingFolder,
        ]),
      ).call(folderTask.id);

      final releasedTask = repository.taskById(folderTask.id);
      expect(releasedTask.folderId, isNull);
      expect(releasedTask.sortOrder, 9);
    },
  );

  test(
    'keeps four SDR videos grouped and releases one HDR singleton',
    () async {
      final folder = testFolder().copyWith(
        origin: TaskFolderOrigin.automaticImport,
      );
      final tasks = <MediaTask>[
        for (var index = 0; index < 4; index += 1)
          readyVideoTask(
            id: 'sdr-$index',
            folderId: folder.id,
            folderSortOrder: index,
          ),
        readyVideoTask(
          id: 'hdr',
          folderId: folder.id,
          folderSortOrder: 4,
          hdr: true,
        ),
      ];
      final repository = FakeMediaTaskRepository(tasks);
      final folderRepository = FakeTaskFolderRepository([folder]);

      final changed = await ReconcileAnalyzedAutomaticTaskFoldersUseCase(
        mediaTaskRepository: repository,
        taskFolderRepository: folderRepository,
        persistence: FakeTaskFolderArrangementPersistence(
          repository,
          folderRepository,
        ),
      ).call();

      expect(changed, isTrue);
      expect(folderRepository.folders, hasLength(1));
      expect(
        folderRepository.folders.single.compatibilityClass,
        TaskFolderCompatibilityClass.videoSdr,
      );
      expect(repository.taskById('hdr').folderId, isNull);
      expect(
        repository.tasks.where((task) => task.folderId == folder.id),
        hasLength(4),
      );
    },
  );

  test('splits four HDR and four SDR videos into two folders', () async {
    final folder = testFolder().copyWith(
      origin: TaskFolderOrigin.automaticImport,
    );
    final tasks = <MediaTask>[
      for (var index = 0; index < 4; index += 1)
        readyVideoTask(
          id: 'hdr-$index',
          folderId: folder.id,
          folderSortOrder: index,
          hdr: true,
        ),
      for (var index = 0; index < 4; index += 1)
        readyVideoTask(
          id: 'sdr-$index',
          folderId: folder.id,
          folderSortOrder: index + 4,
        ),
    ];
    final repository = FakeMediaTaskRepository(tasks);
    final folderRepository = FakeTaskFolderRepository([folder]);

    await ReconcileAnalyzedAutomaticTaskFoldersUseCase(
      mediaTaskRepository: repository,
      taskFolderRepository: folderRepository,
      persistence: FakeTaskFolderArrangementPersistence(
        repository,
        folderRepository,
      ),
    ).call();

    expect(folderRepository.folders, hasLength(2));
    expect(
      folderRepository.folders.map((value) => value.compatibilityClass),
      containsAll(<TaskFolderCompatibilityClass>{
        TaskFolderCompatibilityClass.videoHdr,
        TaskFolderCompatibilityClass.videoSdr,
      }),
    );
    for (final groupedFolder in folderRepository.folders) {
      expect(
        repository.tasks.where((task) => task.folderId == groupedFolder.id),
        hasLength(4),
      );
    }
  });

  test('manual multi-selection creates separate HDR and SDR folders', () async {
    final tasks = <MediaTask>[
      for (var index = 0; index < 2; index += 1)
        readyVideoTask(
          id: 'hdr-$index',
          folderId: '',
          hdr: true,
        ).releaseFromFolder(newSortOrder: index),
      for (var index = 0; index < 2; index += 1)
        readyVideoTask(
          id: 'sdr-$index',
          folderId: '',
        ).releaseFromFolder(newSortOrder: index + 2),
    ];
    final repository = FakeMediaTaskRepository(tasks);
    final folderRepository = FakeTaskFolderRepository([]);

    final result = await CreateTaskFoldersFromTasksUseCase(
      mediaTaskRepository: repository,
      taskFolderRepository: folderRepository,
    ).call(taskIds: tasks.map((task) => task.id).toList());

    expect(result.folders, hasLength(2));
    expect(
      result.folders.map((value) => value.compatibilityClass),
      containsAll(<TaskFolderCompatibilityClass>{
        TaskFolderCompatibilityClass.videoHdr,
        TaskFolderCompatibilityClass.videoSdr,
      }),
    );
    expect(
      result.folders.every((value) => value.origin == TaskFolderOrigin.manual),
      isTrue,
    );
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
    createdAt: 1,
    updatedAt: 1,
  );
}

MediaTask videoTask({
  required String id,
  String? folderId,
  int? folderSortOrder,
  int sortOrder = 0,
  TaskStatus status = TaskStatus.ready,
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
    sortOrder: sortOrder,
    folderId: folderId,
    folderSortOrder: folderSortOrder,
    createdAt: 1,
  );
}

MediaTask readyVideoTask({
  required String id,
  required String folderId,
  int? folderSortOrder,
  TaskStatus status = TaskStatus.ready,
  MediaTaskConfig? config,
  bool hdr = false,
}) {
  return videoTask(
    id: id,
    folderId: folderId,
    folderSortOrder: folderSortOrder,
    status: status,
    config: config,
  ).copyWith(
    sourceFileFingerprint: testFingerprint,
    analysisResult: MediaAnalysisResult(
      durationMs: 1000,
      colorTransfer: hdr ? 'smpte2084' : 'bt709',
    ),
    analysisUpdatedAt: 1,
  );
}

class FakeTaskFolderArrangementPersistence
    implements TaskFolderArrangementPersistence {
  FakeTaskFolderArrangementPersistence(
    this.taskRepository,
    this.folderRepository,
  );

  final FakeMediaTaskRepository taskRepository;
  final FakeTaskFolderRepository folderRepository;

  @override
  Future<void> apply({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
    required Set<String> deletedFolderIds,
  }) async {
    await taskRepository.replaceAllTasks(tasks);
    folderRepository.folders
      ..removeWhere((folder) => deletedFolderIds.contains(folder.id))
      ..clear()
      ..addAll(folders);
  }
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

  MediaTask taskById(String id) {
    return tasks.singleWhere((task) => task.id == id);
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

  @override
  Future<void> clearAllFolders() async {
    folders.clear();
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

class FakeEngineExecutionSubmitter implements EngineExecutionSubmitter {
  final List<String> taskIds = [];

  @override
  Future<EngineExecutionDispatchResult> call(
    String taskId, {
    EngineWorkPriority priority = EngineWorkPriority.normal,
  }) async {
    taskIds.add(taskId);
    return const EngineExecutionDispatchResult(
      outcome: EngineExecutionDispatchOutcome.notEngineConfigured,
      message: '任务没有可提交的引擎配置',
    );
  }
}
