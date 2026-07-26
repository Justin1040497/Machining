import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/execution/media_task_execution_coordinator.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/place_workbench_top_level_item_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
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
    required this.appSettingsRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;
  final AppSettingsRepository appSettingsRepository;

  Future<TaskFolderBatchTasksResult> call({
    required String folderId,
    required MediaTaskConfig config,
    required TaskPurpose purpose,
  }) async {
    final folders = await taskFolderRepository.loadAllFolders();
    final folder = folders.firstWhere((folder) => folder.id == folderId);
    final normalizedConfig = config
        .forKind(folder.mediaKind)
        .copyWith(engineConfiguration: null);
    await taskFolderRepository.saveFolder(
      folder.copyWith(
        defaultConfig: normalizedConfig,
        defaultPurpose: purpose,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final settings = await appSettingsRepository.loadSettings();
    final template = settings.defaultOutputFileNameTemplate;
    final now = DateTime.now();

    final tasks = await mediaTaskRepository.loadAllTasks();
    for (final task in tasks.where((task) => task.folderId == folderId)) {
      if (!_canApplyFolderConfig(task)) {
        continue;
      }
      final taskConfig = resolveSourceOutputFormatForConfig(
        config: normalizedConfig,
        sourceFileName: task.inputPath,
        mediaKind: task.mediaKind,
      );
      // 任务夹共同设置时，每个任务的输出文件名按全局模板 + 各自源名重新渲染，
      // 避免所有任务套用第一个任务的源名渲染结果。
      final version = processingVersionForTask(
        tasks: tasks,
        inputPath: task.inputPath,
        mediaKind: task.mediaKind,
        purpose: purpose,
        taskId: task.id,
      );
      final renderedFileName = buildDefaultOutputFileName(
        sourceFileName: task.inputPath,
        mediaKind: task.mediaKind,
        template: template,
        purpose: purpose,
        mediaConfig: taskConfig,
        now: now,
        version: version,
      );
      await mediaTaskRepository.saveTask(
        task.copyWith(
          config: taskConfig.copyWith(outputFileName: renderedFileName),
          purpose: purpose,
        ),
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

  Future<FfmpegQueueStartResult> call(
    String folderId, {
    bool allowExtremeCompression = false,
  }) async {
    return executionCoordinator.startFolderQueue(
      folderId,
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
    return queueRunner.pauseFolderQueue(folderId);
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

bool _canApplyFolderConfig(MediaTask task) {
  return task.status != TaskStatus.running &&
      task.status != TaskStatus.paused &&
      task.status != TaskStatus.analyzing;
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
