import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/place_workbench_top_level_item_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';

class CreateTaskFolderResult {
  const CreateTaskFolderResult({required this.folder, required this.tasks});

  final TaskFolder folder;
  final List<MediaTask> tasks;
}

class CreateTaskFoldersResult {
  const CreateTaskFoldersResult({required this.folders, required this.tasks});

  final List<TaskFolder> folders;
  final List<MediaTask> tasks;
}

class TaskFolderBatchTasksResult {
  const TaskFolderBatchTasksResult({
    required this.tasks,
    this.taskIdsNeedingAnalysis = const [],
  });

  final List<MediaTask> tasks;
  final List<String> taskIdsNeedingAnalysis;
}

class CreateTaskFolderFromTasksUseCase {
  const CreateTaskFolderFromTasksUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<CreateTaskFolderResult> call({
    required List<String> taskIds,
    String? name,
  }) async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final selectedTasks = tasks
        .where((task) => taskIds.contains(task.id))
        .toList();
    if (selectedTasks.isEmpty) {
      throw StateError('没有可加入任务夹的任务');
    }

    final mediaKind = selectedTasks.first.mediaKind;
    if (selectedTasks.any((task) => task.mediaKind != mediaKind)) {
      throw StateError('一个任务夹只能包含同一类型的媒体任务');
    }

    final folders = await taskFolderRepository.loadAllFolders();
    final folder = await _createFolderForTasks(
      mediaTaskRepository: mediaTaskRepository,
      taskFolderRepository: taskFolderRepository,
      selectedTasks: selectedTasks,
      existingFolders: folders,
      name: name,
    );

    return CreateTaskFolderResult(
      folder: folder,
      tasks: await mediaTaskRepository.loadAllTasks(),
    );
  }
}

class CreateTaskFoldersFromTasksUseCase {
  const CreateTaskFoldersFromTasksUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<CreateTaskFoldersResult> call({required List<String> taskIds}) async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final selectedTasks = tasks
        .where((task) => taskIds.contains(task.id) && task.folderId == null)
        .toList();
    if (selectedTasks.isEmpty) {
      throw StateError('没有可加入任务夹的任务');
    }

    final folders = await taskFolderRepository.loadAllFolders();
    final createdFolders = <TaskFolder>[];
    final selectedByKind = <MediaKind, List<MediaTask>>{};
    for (final task in selectedTasks) {
      selectedByKind.putIfAbsent(task.mediaKind, () => []).add(task);
    }

    var existingFolders = folders;
    for (final groupedTasks in selectedByKind.values) {
      final folder = await _createFolderForTasks(
        mediaTaskRepository: mediaTaskRepository,
        taskFolderRepository: taskFolderRepository,
        selectedTasks: groupedTasks,
        existingFolders: existingFolders,
      );
      createdFolders.add(folder);
      existingFolders = [...existingFolders, folder];
    }

    return CreateTaskFoldersResult(
      folders: createdFolders,
      tasks: await mediaTaskRepository.loadAllTasks(),
    );
  }
}

class MoveTaskToFolderUseCase {
  const MoveTaskToFolderUseCase({required this.repository});

  final MediaTaskRepository repository;

  Future<List<MediaTask>> call({
    required String taskId,
    required String folderId,
  }) async {
    final tasks = await repository.loadAllTasks();
    final folderTaskCount = tasks
        .where((task) => task.folderId == folderId)
        .length;
    final task = tasks.firstWhere((task) => task.id == taskId);
    await repository.saveTask(
      task.moveToFolder(
        targetFolderId: folderId,
        targetFolderSortOrder: folderTaskCount,
      ),
    );
    return repository.loadAllTasks();
  }
}

class RemoveTaskFromFolderUseCase {
  const RemoveTaskFromFolderUseCase({
    required this.repository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository repository;
  final TaskFolderRepository taskFolderRepository;

  Future<List<MediaTask>> call(String taskId) async {
    final tasks = await repository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final task = tasks.firstWhere((task) => task.id == taskId);
    final topLevelSortOrders = [
      ...tasks
          .where((candidate) => candidate.folderId == null)
          .map((task) => task.sortOrder),
      ...folders.map((folder) => folder.sortOrder),
    ];
    final nextSortOrder = topLevelSortOrders.fold<int>(
      0,
      (next, sortOrder) => sortOrder >= next ? sortOrder + 1 : next,
    );
    await repository.saveTask(
      task.releaseFromFolder(newSortOrder: nextSortOrder),
    );
    return repository.loadAllTasks();
  }
}

class PruneEmptyTaskFoldersUseCase {
  const PruneEmptyTaskFoldersUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<List<String>> call() async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final deletedFolderIds = <String>[];

    for (final folder in folders) {
      final hasTask = tasks.any((task) => task.folderId == folder.id);
      if (hasTask) {
        continue;
      }
      await taskFolderRepository.deleteFolderById(folder.id);
      deletedFolderIds.add(folder.id);
    }

    return deletedFolderIds;
  }
}

class ApplyTaskFolderConfigUseCase {
  const ApplyTaskFolderConfigUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<TaskFolderBatchTasksResult> call({
    required String folderId,
    required MediaTaskConfig config,
    required TaskPurpose purpose,
  }) async {
    final folders = await taskFolderRepository.loadAllFolders();
    final folder = folders.firstWhere((folder) => folder.id == folderId);
    final normalizedConfig = config.forKind(folder.mediaKind);
    await taskFolderRepository.saveFolder(
      folder.copyWith(
        defaultConfig: normalizedConfig,
        defaultPurpose: purpose,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final tasks = await mediaTaskRepository.loadAllTasks();
    for (final task in tasks.where((task) => task.folderId == folderId)) {
      if (!_canApplyFolderConfig(task)) {
        continue;
      }
      await mediaTaskRepository.saveTask(
        task.copyWith(config: normalizedConfig, purpose: purpose),
      );
    }

    return TaskFolderBatchTasksResult(
      tasks: await mediaTaskRepository.loadAllTasks(),
    );
  }
}

class RenameTaskFolderUseCase {
  const RenameTaskFolderUseCase({required this.repository});

  final TaskFolderRepository repository;

  Future<TaskFolder> call({
    required String folderId,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('任务夹名称不能为空');
    }

    final folders = await repository.loadAllFolders();
    final folder = folders.firstWhere((folder) => folder.id == folderId);
    final renamed = folder.copyWith(
      name: trimmedName,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await repository.saveFolder(renamed);
    return renamed;
  }
}

class RetryTaskFolderTerminalTasksUseCase {
  const RetryTaskFolderTerminalTasksUseCase({
    required this.repository,
    required this.sourceFileChecker,
    required this.fingerprintReader,
  });

  final MediaTaskRepository repository;
  final SourceFileChecker sourceFileChecker;
  final SourceFileFingerprintReader fingerprintReader;

  Future<TaskFolderBatchTasksResult> call(String folderId) async {
    final tasks = await repository.loadAllTasks();
    final taskIdsNeedingAnalysis = <String>[];

    for (final task in tasks.where(_isRetryableFolderTask)) {
      if (task.folderId != folderId) {
        continue;
      }

      if (!await sourceFileChecker.exists(task.inputPath)) {
        await repository.saveTask(task.markMissingSource());
        continue;
      }

      final fingerprint = await fingerprintReader.read(task.inputPath);
      final analyzingTask = task
          .markPendingForRetry()
          .clearError()
          .withSourceFileFingerprint(fingerprint)
          .clearAnalysis()
          .copyWith(status: TaskStatus.analyzing);
      await repository.saveTask(analyzingTask);
      taskIdsNeedingAnalysis.add(task.id);
    }

    return TaskFolderBatchTasksResult(
      tasks: await repository.loadAllTasks(),
      taskIdsNeedingAnalysis: taskIdsNeedingAnalysis,
    );
  }
}

class StartNextTaskInFolderUseCase {
  const StartNextTaskInFolderUseCase({
    required this.repository,
    required this.queueRunner,
  });

  final MediaTaskRepository repository;
  final FfmpegTaskQueueRunner queueRunner;

  Future<FfmpegQueueStartResult> call(
    String folderId, {
    bool allowExtremeCompression = false,
  }) async {
    final tasks = await repository.loadAllTasks();
    final task = _firstOrNull(
      _orderedFolderTasks(tasks, folderId).where(_canStart),
    );
    if (task == null) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.noPendingTask,
        message: '任务夹内没有可执行任务',
      );
    }

    return queueRunner.startOrResumeTask(
      task.id,
      allowExtremeCompression: allowExtremeCompression,
    );
  }
}

class PauseRunningTaskInFolderUseCase {
  const PauseRunningTaskInFolderUseCase({
    required this.repository,
    required this.queueRunner,
  });

  final MediaTaskRepository repository;
  final FfmpegTaskQueueRunner queueRunner;

  Future<FfmpegQueueStartResult> call(String folderId) async {
    final tasks = await repository.loadAllTasks();
    final orderedTasks = _orderedFolderTasks(tasks, folderId);
    final runningTasks = orderedTasks
        .where(
          (task) =>
              task.status == TaskStatus.running &&
              queueRunner.runningTaskIds.contains(task.id),
        )
        .toList();
    if (runningTasks.isEmpty) {
      return const FfmpegQueueStartResult(
        outcome: FfmpegQueueStartOutcome.invalidTaskState,
        message: '任务夹内没有正在执行的任务',
      );
    }

    FfmpegQueueStartResult? lastResult;
    for (final task in runningTasks) {
      lastResult = await queueRunner.pauseTask(task.id);
    }
    return lastResult ??
        const FfmpegQueueStartResult(
          outcome: FfmpegQueueStartOutcome.invalidTaskState,
          message: '任务夹内没有正在执行的任务',
        );
  }
}

class DeleteTaskFolderUseCase {
  const DeleteTaskFolderUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<List<MediaTask>> call(String folderId) async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    var nextSortOrder = tasks
        .where((task) => task.folderId == null)
        .fold<int>(
          0,
          (max, task) => task.sortOrder >= max ? task.sortOrder + 1 : max,
        );

    for (final task in tasks.where((task) => task.folderId == folderId)) {
      await mediaTaskRepository.saveTask(
        task.releaseFromFolder(newSortOrder: nextSortOrder),
      );
      nextSortOrder += 1;
    }
    await taskFolderRepository.deleteFolderById(folderId);
    return mediaTaskRepository.loadAllTasks();
  }
}

String defaultFolderName(
  MediaKind mediaKind,
  List<TaskFolder> existingFolders,
) {
  final label = switch (mediaKind) {
    MediaKind.video => '视频',
    MediaKind.image => '图片',
    MediaKind.audio => '音频',
  };
  final prefix = '$label任务夹';
  var maxIndex = 0;
  for (final folder in existingFolders.where(
    (folder) => folder.mediaKind == mediaKind,
  )) {
    final name = folder.name.trim();
    if (name == prefix) {
      maxIndex = maxIndex < 1 ? 1 : maxIndex;
      continue;
    }
    final match = RegExp(
      '^${RegExp.escape(prefix)}\\s+(\\d+)\$',
    ).firstMatch(name);
    final index = match == null ? null : int.tryParse(match.group(1)!);
    if (index != null && index > maxIndex) {
      maxIndex = index;
    }
  }
  return '$prefix ${maxIndex + 1}';
}

String uniqueFolderName(
  String preferredName,
  List<TaskFolder> existingFolders,
) {
  final baseName = preferredName.trim();
  if (baseName.isEmpty) {
    return baseName;
  }
  final existingNames = existingFolders.map((folder) => folder.name).toSet();
  if (!existingNames.contains(baseName)) {
    return baseName;
  }
  var index = 2;
  while (existingNames.contains('$baseName $index')) {
    index += 1;
  }
  return '$baseName $index';
}

int nextFolderSortOrder(List<TaskFolder> folders) {
  return folders.fold<int>(
    0,
    (max, folder) => folder.sortOrder >= max ? folder.sortOrder + 1 : max,
  );
}

Future<TaskFolder> _createFolderForTasks({
  required MediaTaskRepository mediaTaskRepository,
  required TaskFolderRepository taskFolderRepository,
  required List<MediaTask> selectedTasks,
  required List<TaskFolder> existingFolders,
  String? name,
}) async {
  final mediaKind = selectedTasks.first.mediaKind;
  final preferredName = name?.trim();
  final folder = TaskFolder.create(
    name: preferredName?.isNotEmpty == true
        ? uniqueFolderName(preferredName!, existingFolders)
        : defaultFolderName(mediaKind, existingFolders),
    mediaKind: mediaKind,
    defaultPurpose: selectedTasks.first.purpose,
    sortOrder: nextFolderSortOrder(existingFolders),
    defaultConfig: selectedTasks.first.config,
  );

  await taskFolderRepository.saveFolder(folder);
  for (var index = 0; index < selectedTasks.length; index++) {
    await mediaTaskRepository.saveTask(
      selectedTasks[index].moveToFolder(
        targetFolderId: folder.id,
        targetFolderSortOrder: index,
      ),
    );
  }
  await PlaceWorkbenchTopLevelItemUseCase(
    mediaTaskRepository: mediaTaskRepository,
    taskFolderRepository: taskFolderRepository,
  ).call(WorkbenchInsertedItem.folder(folder.id));
  return folder;
}

List<MediaTask> _orderedFolderTasks(List<MediaTask> tasks, String folderId) {
  return tasks.where((task) => task.folderId == folderId).toList()
    ..sort((a, b) {
      final order = (a.folderSortOrder ?? a.sortOrder).compareTo(
        b.folderSortOrder ?? b.sortOrder,
      );
      if (order != 0) {
        return order;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
}

bool _canApplyFolderConfig(MediaTask task) {
  return task.status != TaskStatus.running &&
      task.status != TaskStatus.paused &&
      task.status != TaskStatus.analyzing;
}

bool _isRetryableFolderTask(MediaTask task) {
  return task.status == TaskStatus.completed ||
      task.status == TaskStatus.failed ||
      task.status == TaskStatus.cancelled;
}

bool _canStart(MediaTask task) {
  if (task.status == TaskStatus.paused) {
    return true;
  }
  return task.status == TaskStatus.pending && task.analysisResult != null;
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}
