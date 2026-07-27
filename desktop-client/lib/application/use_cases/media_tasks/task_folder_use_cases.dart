import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_arrangement_persistence.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/execution_queue_result.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/place_workbench_top_level_item_use_case.dart';
import 'package:framelean/domain/library.dart';

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
    _requireAnalyzedCompatibleTasks(selectedTasks);

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
    _requireAnalyzedTasks(selectedTasks);
    final selectedByKind = <TaskFolderCompatibilityClass, List<MediaTask>>{};
    for (final task in selectedTasks) {
      selectedByKind
          .putIfAbsent(task.taskFolderCompatibilityClass!, () => [])
          .add(task);
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

class OrganizeImportedMediaBatchUseCase {
  const OrganizeImportedMediaBatchUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<CreateTaskFoldersResult> call({
    required List<String> taskIds,
    String? sourceFolderName,
  }) async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final importedTasks = tasks
        .where((task) => taskIds.contains(task.id) && task.folderId == null)
        .toList();
    if (importedTasks.isEmpty) {
      return CreateTaskFoldersResult(folders: const [], tasks: tasks);
    }

    final selectedByKind = <MediaKind, List<MediaTask>>{};
    for (final task in importedTasks) {
      selectedByKind.putIfAbsent(task.mediaKind, () => []).add(task);
    }

    var existingFolders = await taskFolderRepository.loadAllFolders();
    final createdFolders = <TaskFolder>[];
    for (final entry in selectedByKind.entries) {
      final groupedTasks = entry.value;
      if (groupedTasks.length == 1) {
        await PlaceWorkbenchTopLevelItemUseCase(
          mediaTaskRepository: mediaTaskRepository,
          taskFolderRepository: taskFolderRepository,
        ).call(WorkbenchInsertedItem.task(groupedTasks.single.id));
        continue;
      }

      final normalizedSourceName = sourceFolderName?.trim();
      final preferredName =
          normalizedSourceName == null || normalizedSourceName.isEmpty
          ? null
          : '$normalizedSourceName - ${_mediaKindLabel(entry.key)}';
      final folder = await _createFolderForTasks(
        mediaTaskRepository: mediaTaskRepository,
        taskFolderRepository: taskFolderRepository,
        selectedTasks: groupedTasks,
        existingFolders: existingFolders,
        name: preferredName,
        origin: TaskFolderOrigin.automaticImport,
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

class ReconcileAnalyzedAutomaticTaskFoldersUseCase {
  const ReconcileAnalyzedAutomaticTaskFoldersUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
    required this.persistence,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;
  final TaskFolderArrangementPersistence persistence;

  Future<bool> call() async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final taskById = {for (final task in tasks) task.id: task};
    final folderById = {for (final folder in folders) folder.id: folder};
    final childrenByFolder = <String, List<MediaTask>>{};
    for (final task in tasks) {
      final folderId = task.folderId;
      if (folderId != null) {
        childrenByFolder.putIfAbsent(folderId, () => []).add(task);
      }
    }
    for (final children in childrenByFolder.values) {
      children.sort(_compareFolderTaskOrder);
    }

    final topLevel = <_ReconciledTopLevelItem>[
      for (final task in tasks.where((task) => task.folderId == null))
        _ReconciledTopLevelItem.task(task),
      for (final folder in folders) _ReconciledTopLevelItem.folder(folder),
    ]..sort(_compareReconciledTopLevel);

    final result = <_ReconciledTopLevelItem>[];
    final deletedFolderIds = <String>{};
    final namingFolders = [...folders];
    var changed = false;

    for (final item in topLevel) {
      final folder = item.folder;
      if (folder == null || folder.origin != TaskFolderOrigin.automaticImport) {
        result.add(item);
        continue;
      }

      final children = childrenByFolder[folder.id] ?? const <MediaTask>[];
      if (children.isEmpty) {
        deletedFolderIds.add(folder.id);
        folderById.remove(folder.id);
        changed = true;
        continue;
      }
      if (children.any(_isAnalysisPending)) {
        result.add(item);
        continue;
      }

      final partitions = <String, _TaskFolderPartition>{};
      for (final child in children) {
        final compatibilityClass = child.taskFolderCompatibilityClass;
        final key = compatibilityClass?.name ?? 'unclassified:${child.id}';
        partitions
            .putIfAbsent(key, () => _TaskFolderPartition(compatibilityClass))
            .tasks
            .add(child);
      }

      if (partitions.length == 1 &&
          partitions.values.single.tasks.length >= 2) {
        final compatibilityClass = partitions.values.single.compatibilityClass!;
        if (folder.compatibilityClass != compatibilityClass) {
          final updated = folder.copyWith(
            compatibilityClass: compatibilityClass,
          );
          folderById[folder.id] = updated;
          result.add(_ReconciledTopLevelItem.folder(updated));
          changed = true;
        } else {
          result.add(item);
        }
        continue;
      }

      var reusedOriginal = false;
      for (final partition in partitions.values) {
        if (partition.tasks.length == 1) {
          final task = partition.tasks.single.releaseFromFolder();
          taskById[task.id] = task;
          result.add(_ReconciledTopLevelItem.task(task));
          continue;
        }

        final compatibilityClass = partition.compatibilityClass!;
        final targetFolder = reusedOriginal
            ? TaskFolder.create(
                name: defaultFolderName(
                  partition.tasks.first.mediaKind,
                  namingFolders,
                  compatibilityClass: compatibilityClass,
                ),
                mediaKind: partition.tasks.first.mediaKind,
                origin: TaskFolderOrigin.automaticImport,
                compatibilityClass: compatibilityClass,
                sortOrder: folder.sortOrder,
              )
            : folder.copyWith(compatibilityClass: compatibilityClass);
        reusedOriginal = true;
        folderById[targetFolder.id] = targetFolder;
        if (targetFolder.id != folder.id) {
          namingFolders.add(targetFolder);
        }
        for (final (index, task) in partition.tasks.indexed) {
          taskById[task.id] = task.moveToFolder(
            targetFolderId: targetFolder.id,
            targetFolderSortOrder: index,
          );
        }
        result.add(_ReconciledTopLevelItem.folder(targetFolder));
      }

      if (!reusedOriginal) {
        folderById.remove(folder.id);
        deletedFolderIds.add(folder.id);
      }
      changed = true;
    }

    if (!changed) {
      return false;
    }

    for (final (index, item) in result.indexed) {
      final task = item.task;
      if (task != null) {
        taskById[task.id] = task.releaseFromFolder(newSortOrder: index);
        continue;
      }
      final folder = item.folder!;
      folderById[folder.id] = folder.copyWith(sortOrder: index);
    }

    await persistence.apply(
      tasks: taskById.values.toList(growable: false),
      folders: folderById.values.toList(growable: false),
      deletedFolderIds: deletedFolderIds,
    );
    return true;
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
      final shouldAnalyze =
          task.analysisResult == null ||
          task.failure?.recoveryAction == TaskRecoveryAction.retryAnalysis;
      var pendingTask = task
          .markPendingForRetry()
          .clearError()
          .withSourceFileFingerprint(fingerprint);
      if (shouldAnalyze) {
        pendingTask = pendingTask.clearAnalysis().markAwaitingAnalysis();
      }
      await repository.saveTask(pendingTask);
      if (shouldAnalyze) {
        taskIdsNeedingAnalysis.add(task.id);
      }
    }

    return TaskFolderBatchTasksResult(
      tasks: await repository.loadAllTasks(),
      taskIdsNeedingAnalysis: taskIdsNeedingAnalysis,
    );
  }
}

class StartNextTaskInFolderUseCase {
  const StartNextTaskInFolderUseCase({required this.executionCoordinator});

  final MediaTaskExecutionCoordinator executionCoordinator;

  Future<EngineQueueStartResult> call(String folderId) async {
    return executionCoordinator.startFolderQueue(folderId);
  }
}

class PauseRunningTaskInFolderUseCase {
  const PauseRunningTaskInFolderUseCase({
    required this.repository,
    required this.executionCoordinator,
  });

  final MediaTaskRepository repository;
  final MediaTaskExecutionCoordinator executionCoordinator;

  Future<EngineQueueStartResult> call(String folderId) async {
    return executionCoordinator.pauseFolder(folderId);
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
  List<TaskFolder> existingFolders, {
  TaskFolderCompatibilityClass? compatibilityClass,
}) {
  final label = switch ((mediaKind, compatibilityClass)) {
    (MediaKind.video, TaskFolderCompatibilityClass.videoHdr) => 'HDR 视频',
    (MediaKind.video, _) => '视频',
    (MediaKind.image, _) => '图片',
    (MediaKind.audio, _) => '音频',
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
  TaskFolderOrigin origin = TaskFolderOrigin.manual,
}) async {
  final mediaKind = selectedTasks.first.mediaKind;
  final compatibilityClass = selectedTasks.first.taskFolderCompatibilityClass;
  if (origin == TaskFolderOrigin.manual) {
    _requireAnalyzedCompatibleTasks(selectedTasks);
  }
  final preferredName = name?.trim();
  final folder = TaskFolder.create(
    name: preferredName?.isNotEmpty == true
        ? uniqueFolderName(preferredName!, existingFolders)
        : defaultFolderName(
            mediaKind,
            existingFolders,
            compatibilityClass: compatibilityClass,
          ),
    mediaKind: mediaKind,
    origin: origin,
    compatibilityClass: compatibilityClass,
    sortOrder: nextFolderSortOrder(existingFolders),
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

void _requireAnalyzedTasks(List<MediaTask> tasks) {
  if (tasks.any((task) => task.taskFolderCompatibilityClass == null)) {
    throw StateError('请等待所选任务分析完成后再创建任务夹');
  }
}

void _requireAnalyzedCompatibleTasks(List<MediaTask> tasks) {
  _requireAnalyzedTasks(tasks);
  final compatibilityClass = tasks.first.taskFolderCompatibilityClass;
  if (tasks.any(
    (task) => task.taskFolderCompatibilityClass != compatibilityClass,
  )) {
    throw StateError('所选任务包含不同的媒体配置类型，请分别创建任务夹');
  }
}

bool _isAnalysisPending(MediaTask task) {
  return task.status == TaskStatus.awaitAnalysis ||
      task.status == TaskStatus.analysisQueued ||
      task.status == TaskStatus.analyzing;
}

int _compareFolderTaskOrder(MediaTask left, MediaTask right) {
  final order = (left.folderSortOrder ?? left.sortOrder).compareTo(
    right.folderSortOrder ?? right.sortOrder,
  );
  return order != 0 ? order : left.createdAt.compareTo(right.createdAt);
}

int _compareReconciledTopLevel(
  _ReconciledTopLevelItem left,
  _ReconciledTopLevelItem right,
) {
  final order = left.sortOrder.compareTo(right.sortOrder);
  return order != 0 ? order : left.createdAt.compareTo(right.createdAt);
}

final class _TaskFolderPartition {
  _TaskFolderPartition(this.compatibilityClass);

  final TaskFolderCompatibilityClass? compatibilityClass;
  final List<MediaTask> tasks = [];
}

final class _ReconciledTopLevelItem {
  const _ReconciledTopLevelItem.task(MediaTask value)
    : task = value,
      folder = null;

  const _ReconciledTopLevelItem.folder(TaskFolder value)
    : task = null,
      folder = value;

  final MediaTask? task;
  final TaskFolder? folder;

  int get sortOrder => task?.sortOrder ?? folder!.sortOrder;
  int get createdAt => task?.createdAt ?? folder!.createdAt;
}

bool _isRetryableFolderTask(MediaTask task) {
  return task.status == TaskStatus.completed ||
      task.status == TaskStatus.executionFailed ||
      task.status == TaskStatus.analysisFailed ||
      task.status == TaskStatus.cancelled;
}

String _mediaKindLabel(MediaKind mediaKind) {
  return switch (mediaKind) {
    MediaKind.video => '视频',
    MediaKind.image => '图片',
    MediaKind.audio => '音频',
  };
}
