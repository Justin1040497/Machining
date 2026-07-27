import 'package:framelean/application/repositories/imported_media_batch_persistence.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/engine/task_folder_queue_projection.dart';
import 'package:framelean/application/use_cases/media_tasks/task_folder_use_cases.dart';
import 'package:framelean/domain/library.dart';

final class OrganizedImportedMediaBatch {
  const OrganizedImportedMediaBatch({
    required this.createdTasks,
    required this.createdFolders,
    required this.allTasks,
    required this.orderedImportedTaskIds,
  });

  final List<MediaTask> createdTasks;
  final List<TaskFolder> createdFolders;
  final List<MediaTask> allTasks;
  final List<String> orderedImportedTaskIds;
}

/// Organizes every valid item before a single task/folder/order transaction.
final class OrganizeImportedMediaBatchAtomicallyUseCase {
  const OrganizeImportedMediaBatchAtomicallyUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
    required this.persistence,
    this.queueProjection = const TaskFolderQueueProjection(),
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;
  final ImportedMediaBatchPersistence persistence;
  final TaskFolderQueueProjection queueProjection;

  Future<OrganizedImportedMediaBatch> call(
    List<MediaTask> importedTasks,
  ) async {
    if (importedTasks.isEmpty) {
      return OrganizedImportedMediaBatch(
        createdTasks: const <MediaTask>[],
        createdFolders: const <TaskFolder>[],
        allTasks: await mediaTaskRepository.loadAllTasks(),
        orderedImportedTaskIds: const <String>[],
      );
    }
    final importedIds = importedTasks.map((task) => task.id).toSet();
    if (importedIds.length != importedTasks.length) {
      throw StateError('导入批次包含重复任务 ID');
    }
    final existingTasks = (await mediaTaskRepository.loadAllTasks())
        .where((task) => !importedIds.contains(task.id))
        .toList(growable: false);
    final existingFolders = await taskFolderRepository.loadAllFolders();
    final nextTopLevelOrder =
        <int>[
          ...existingTasks
              .where((task) => task.folderId == null)
              .map((task) => task.sortOrder),
          ...existingFolders.map((folder) => folder.sortOrder),
        ].fold<int>(-1, (maximum, value) => value > maximum ? value : maximum) +
        1;

    final byKind = <MediaKind, List<MediaTask>>{};
    for (final task in importedTasks) {
      byKind.putIfAbsent(task.mediaKind, () => <MediaTask>[]).add(task);
    }
    final organizedTasks = <MediaTask>[];
    final createdFolders = <TaskFolder>[];
    var topLevelOffset = 0;
    for (final entry in byKind.entries) {
      final group = entry.value;
      final topLevelOrder = nextTopLevelOrder + topLevelOffset;
      topLevelOffset += 1;
      if (group.length == 1) {
        organizedTasks.add(
          group.single.copyWith(sortOrder: topLevelOrder, clearFolder: true),
        );
        continue;
      }
      final folder = TaskFolder.create(
        name: defaultFolderName(entry.key, <TaskFolder>[
          ...existingFolders,
          ...createdFolders,
        ]),
        mediaKind: entry.key,
        origin: TaskFolderOrigin.automaticImport,
        sortOrder: topLevelOrder,
      );
      createdFolders.add(folder);
      for (var index = 0; index < group.length; index += 1) {
        organizedTasks.add(
          group[index].moveToFolder(
            targetFolderId: folder.id,
            targetFolderSortOrder: index,
          ),
        );
      }
    }

    await persistence.save(tasks: organizedTasks, folders: createdFolders);
    final allTasks = <MediaTask>[...existingTasks, ...organizedTasks];
    final allFolders = <TaskFolder>[...existingFolders, ...createdFolders];
    final orderedImportedTaskIds = queueProjection
        .orderedTaskIds(allTasks, allFolders)
        .where(importedIds.contains)
        .toList(growable: false);
    if (orderedImportedTaskIds.length != importedTasks.length) {
      throw StateError('导入批次摊平结果缺失或重复');
    }
    return OrganizedImportedMediaBatch(
      createdTasks: organizedTasks,
      createdFolders: createdFolders,
      allTasks: allTasks,
      orderedImportedTaskIds: orderedImportedTaskIds,
    );
  }
}
