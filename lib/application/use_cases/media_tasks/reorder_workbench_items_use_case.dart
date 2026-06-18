import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/task_status.dart';

enum WorkbenchTopLevelItemKind { task, folder }

class ReorderWorkbenchTopLevelItemsUseCase {
  const ReorderWorkbenchTopLevelItemsUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<List<MediaTask>> call({
    required int oldIndex,
    required int newIndex,
  }) async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final items = _buildTopLevelItems(tasks, folders);
    final reordered = _reorderRespectingRunningBoundaries(
      items,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (identical(reordered, items)) {
      return tasks;
    }

    final taskUpdates = <MediaTaskSortOrderUpdate>[];
    final folderUpdates = <TaskFolderSortOrderUpdate>[];
    for (var index = 0; index < reordered.length; index += 1) {
      final item = reordered[index];
      switch (item.kind) {
        case WorkbenchTopLevelItemKind.task:
          taskUpdates.add(
            MediaTaskSortOrderUpdate(taskId: item.id, sortOrder: index),
          );
        case WorkbenchTopLevelItemKind.folder:
          folderUpdates.add(
            TaskFolderSortOrderUpdate(folderId: item.id, sortOrder: index),
          );
      }
    }

    await mediaTaskRepository.updateTaskSortOrders(taskUpdates);
    await taskFolderRepository.updateFolderSortOrders(folderUpdates);
    return mediaTaskRepository.loadAllTasks();
  }
}

class ReorderFolderTasksUseCase {
  const ReorderFolderTasksUseCase({required this.repository});

  final MediaTaskRepository repository;

  Future<List<MediaTask>> call({
    required String folderId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final tasks = await repository.loadAllTasks();
    final folderTasks =
        tasks.where((task) => task.folderId == folderId).toList()
          ..sort(_compareFolderTasks);
    final items = [
      for (final task in folderTasks)
        _OrderableItem(
          id: task.id,
          kind: WorkbenchTopLevelItemKind.task,
          running: task.status == TaskStatus.running,
          createdAt: task.createdAt,
          sortOrder: task.folderSortOrder ?? task.sortOrder,
        ),
    ];
    final reordered = _reorderRespectingRunningBoundaries(
      items,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (identical(reordered, items)) {
      return tasks;
    }

    await repository.updateTaskFolderSortOrders([
      for (var index = 0; index < reordered.length; index += 1)
        MediaTaskFolderSortOrderUpdate(
          taskId: reordered[index].id,
          folderSortOrder: index,
        ),
    ]);
    return repository.loadAllTasks();
  }
}

List<_OrderableItem> _buildTopLevelItems(
  List<MediaTask> tasks,
  List<TaskFolder> folders,
) {
  final folderTasksById = <String, List<MediaTask>>{};
  for (final task in tasks) {
    final folderId = task.folderId;
    if (folderId == null) {
      continue;
    }
    folderTasksById.putIfAbsent(folderId, () => []).add(task);
  }

  final items = <_OrderableItem>[
    for (final folder in folders)
      _OrderableItem(
        id: folder.id,
        kind: WorkbenchTopLevelItemKind.folder,
        running:
            folderTasksById[folder.id]?.any(
              (task) => task.status == TaskStatus.running,
            ) ??
            false,
        createdAt: folder.createdAt,
        sortOrder: folder.sortOrder,
      ),
    for (final task in tasks.where((task) => task.folderId == null))
      _OrderableItem(
        id: task.id,
        kind: WorkbenchTopLevelItemKind.task,
        running: task.status == TaskStatus.running,
        createdAt: task.createdAt,
        sortOrder: task.sortOrder,
      ),
  ];
  items.sort(_compareOrderableItems);
  return items;
}

List<_OrderableItem> _reorderRespectingRunningBoundaries(
  List<_OrderableItem> items, {
  required int oldIndex,
  required int newIndex,
}) {
  if (oldIndex < 0 || oldIndex >= items.length) {
    return items;
  }
  final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
  if (targetIndex < 0 ||
      targetIndex >= items.length ||
      targetIndex == oldIndex) {
    return items;
  }
  final movingItem = items[oldIndex];
  if (movingItem.running ||
      _crossesRunningBoundary(items, oldIndex, targetIndex)) {
    return items;
  }
  final reordered = [...items];
  final item = reordered.removeAt(oldIndex);
  reordered.insert(targetIndex, item);
  return reordered;
}

bool _crossesRunningBoundary(
  List<_OrderableItem> items,
  int oldIndex,
  int targetIndex,
) {
  final start = oldIndex < targetIndex ? oldIndex + 1 : targetIndex;
  final end = oldIndex < targetIndex ? targetIndex : oldIndex - 1;
  for (var index = start; index <= end; index += 1) {
    if (items[index].running) {
      return true;
    }
  }
  return false;
}

int _compareOrderableItems(_OrderableItem a, _OrderableItem b) {
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) {
    return order;
  }
  return a.createdAt.compareTo(b.createdAt);
}

int _compareFolderTasks(MediaTask a, MediaTask b) {
  final order = (a.folderSortOrder ?? a.sortOrder).compareTo(
    b.folderSortOrder ?? b.sortOrder,
  );
  if (order != 0) {
    return order;
  }
  return a.createdAt.compareTo(b.createdAt);
}

class _OrderableItem {
  const _OrderableItem({
    required this.id,
    required this.kind,
    required this.running,
    required this.createdAt,
    required this.sortOrder,
  });

  final String id;
  final WorkbenchTopLevelItemKind kind;
  final bool running;
  final int createdAt;
  final int sortOrder;
}
