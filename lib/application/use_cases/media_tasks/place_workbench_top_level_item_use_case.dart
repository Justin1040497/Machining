import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/task_status.dart';

enum WorkbenchInsertedItemKind { task, folder }

class WorkbenchInsertedItem {
  const WorkbenchInsertedItem.task(this.id)
    : kind = WorkbenchInsertedItemKind.task;

  const WorkbenchInsertedItem.folder(this.id)
    : kind = WorkbenchInsertedItemKind.folder;

  final String id;
  final WorkbenchInsertedItemKind kind;
}

class PlaceWorkbenchTopLevelItemUseCase {
  const PlaceWorkbenchTopLevelItemUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;

  Future<void> call(WorkbenchInsertedItem insertedItem) async {
    final tasks = await mediaTaskRepository.loadAllTasks();
    final folders = await taskFolderRepository.loadAllFolders();
    final items = _buildTopLevelItems(tasks, folders);
    final insertedKey = _itemKey(insertedItem.kind, insertedItem.id);
    final insertedIndex = items.indexWhere((item) => item.key == insertedKey);
    if (insertedIndex < 0) {
      return;
    }

    final inserted = items.removeAt(insertedIndex);
    final incompleteItems = items.where((item) => !item.completed).toList();
    final completedItems = items.where((item) => item.completed).toList();
    final orderedItems = [...incompleteItems, inserted, ...completedItems];

    final taskUpdates = <MediaTaskSortOrderUpdate>[];
    final folderUpdates = <TaskFolderSortOrderUpdate>[];
    for (var index = 0; index < orderedItems.length; index += 1) {
      final item = orderedItems[index];
      switch (item.kind) {
        case WorkbenchInsertedItemKind.task:
          taskUpdates.add(
            MediaTaskSortOrderUpdate(taskId: item.id, sortOrder: index),
          );
        case WorkbenchInsertedItemKind.folder:
          folderUpdates.add(
            TaskFolderSortOrderUpdate(folderId: item.id, sortOrder: index),
          );
      }
    }

    if (taskUpdates.isNotEmpty) {
      await mediaTaskRepository.updateTaskSortOrders(taskUpdates);
    }
    if (folderUpdates.isNotEmpty) {
      await taskFolderRepository.updateFolderSortOrders(folderUpdates);
    }
  }
}

List<_TopLevelInsertionItem> _buildTopLevelItems(
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

  final items = <_TopLevelInsertionItem>[
    for (final task in tasks.where((task) => task.folderId == null))
      _TopLevelInsertionItem(
        id: task.id,
        kind: WorkbenchInsertedItemKind.task,
        sortOrder: task.sortOrder,
        createdAt: task.createdAt,
        completed: task.status == TaskStatus.completed,
      ),
    for (final folder in folders)
      _TopLevelInsertionItem(
        id: folder.id,
        kind: WorkbenchInsertedItemKind.folder,
        sortOrder: folder.sortOrder,
        createdAt: folder.createdAt,
        completed: _folderIsCompleted(folderTasksById[folder.id] ?? const []),
      ),
  ];

  items.sort((a, b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) {
      return order;
    }
    return a.createdAt.compareTo(b.createdAt);
  });
  return items;
}

bool _folderIsCompleted(List<MediaTask> tasks) {
  return tasks.isNotEmpty &&
      tasks.every((task) => task.status == TaskStatus.completed);
}

String _itemKey(WorkbenchInsertedItemKind kind, String id) {
  return '${kind.name}:$id';
}

class _TopLevelInsertionItem {
  const _TopLevelInsertionItem({
    required this.id,
    required this.kind,
    required this.sortOrder,
    required this.createdAt,
    required this.completed,
  });

  final String id;
  final WorkbenchInsertedItemKind kind;
  final int sortOrder;
  final int createdAt;
  final bool completed;

  String get key => _itemKey(kind, id);
}
