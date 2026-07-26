import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/use_cases/media_tasks/reorder_workbench_items_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';

void main() {
  group('ReorderWorkbenchTopLevelItemsUseCase', () {
    test('updates mixed task and folder sort orders', () async {
      final taskRepository = FakeMediaTaskRepository([
        mediaTask(id: 'loose', sortOrder: 1),
        mediaTask(id: 'inside-folder', sortOrder: 9, folderId: 'folder-a'),
      ]);
      final folderRepository = FakeTaskFolderRepository([
        taskFolder(id: 'folder-a', sortOrder: 0),
        taskFolder(id: 'folder-b', sortOrder: 2),
      ]);

      await ReorderWorkbenchTopLevelItemsUseCase(
        mediaTaskRepository: taskRepository,
        taskFolderRepository: folderRepository,
      ).call(oldIndex: 0, newIndex: 2);

      expect(taskRepository.sortOrderUpdates, [
        const MediaTaskSortOrderUpdate(taskId: 'loose', sortOrder: 0),
      ]);
      expect(folderRepository.sortOrderUpdates, [
        const TaskFolderSortOrderUpdate(folderId: 'folder-a', sortOrder: 1),
        const TaskFolderSortOrderUpdate(folderId: 'folder-b', sortOrder: 2),
      ]);
      expect(taskRepository.taskById('inside-folder').sortOrder, 9);
    });

    test(
      'moves a Client folder block while Engine keeps its active child fixed',
      () async {
        final taskRepository = FakeMediaTaskRepository([
          mediaTask(id: 'first', sortOrder: 0),
          mediaTask(
            id: 'running-in-folder',
            sortOrder: 9,
            folderId: 'folder-a',
            status: TaskStatus.running,
          ),
          mediaTask(id: 'last', sortOrder: 2),
        ]);
        final folderRepository = FakeTaskFolderRepository([
          taskFolder(id: 'folder-a', sortOrder: 1),
        ]);

        await ReorderWorkbenchTopLevelItemsUseCase(
          mediaTaskRepository: taskRepository,
          taskFolderRepository: folderRepository,
        ).call(oldIndex: 2, newIndex: 0);

        expect(taskRepository.sortOrderUpdates, [
          const MediaTaskSortOrderUpdate(taskId: 'last', sortOrder: 0),
          const MediaTaskSortOrderUpdate(taskId: 'first', sortOrder: 1),
        ]);
        expect(folderRepository.sortOrderUpdates, [
          const TaskFolderSortOrderUpdate(folderId: 'folder-a', sortOrder: 2),
        ]);
      },
    );
  });

  group('ReorderFolderTasksUseCase', () {
    test(
      'updates folder sort orders without touching top-level order',
      () async {
        final repository = FakeMediaTaskRepository([
          mediaTask(
            id: 'first',
            sortOrder: 10,
            folderId: 'folder-a',
            folderSortOrder: 0,
          ),
          mediaTask(
            id: 'second',
            sortOrder: 11,
            folderId: 'folder-a',
            folderSortOrder: 1,
          ),
          mediaTask(id: 'loose', sortOrder: 0),
        ]);

        await ReorderFolderTasksUseCase(
          repository: repository,
        ).call(folderId: 'folder-a', oldIndex: 0, newIndex: 2);

        expect(repository.folderSortOrderUpdates, [
          const MediaTaskFolderSortOrderUpdate(
            taskId: 'second',
            folderSortOrder: 0,
          ),
          const MediaTaskFolderSortOrderUpdate(
            taskId: 'first',
            folderSortOrder: 1,
          ),
        ]);
        expect(repository.sortOrderUpdates, isEmpty);
        expect(repository.taskById('loose').sortOrder, 0);
      },
    );

    test('does not reorder folder tasks across a running task', () async {
      final repository = FakeMediaTaskRepository([
        mediaTask(
          id: 'first',
          sortOrder: 10,
          folderId: 'folder-a',
          folderSortOrder: 0,
        ),
        mediaTask(
          id: 'running',
          sortOrder: 11,
          folderId: 'folder-a',
          folderSortOrder: 1,
          status: TaskStatus.running,
        ),
        mediaTask(
          id: 'last',
          sortOrder: 12,
          folderId: 'folder-a',
          folderSortOrder: 2,
        ),
      ]);

      await ReorderFolderTasksUseCase(
        repository: repository,
      ).call(folderId: 'folder-a', oldIndex: 2, newIndex: 0);

      expect(repository.folderSortOrderUpdates, isEmpty);
    });
  });
}

MediaTask mediaTask({
  required String id,
  required int sortOrder,
  String? folderId,
  int? folderSortOrder,
  TaskStatus status = TaskStatus.pending,
}) {
  return MediaTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: sortOrder,
    folderId: folderId,
    folderSortOrder: folderSortOrder,
    createdAt: sortOrder,
  );
}

TaskFolder taskFolder({required String id, required int sortOrder}) {
  return TaskFolder(
    id: id,
    name: id,
    mediaKind: MediaKind.video,
    sortOrder: sortOrder,
    defaultConfig: MediaTaskConfig.initialVideo(),
    createdAt: sortOrder,
    updatedAt: sortOrder,
  );
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  final List<MediaTask> tasks;
  final List<MediaTaskSortOrderUpdate> sortOrderUpdates = [];
  final List<MediaTaskFolderSortOrderUpdate> folderSortOrderUpdates = [];

  @override
  Future<void> deleteTaskById(String taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async => [...tasks];

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    this.tasks
      ..clear()
      ..addAll(tasks);
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    final index = tasks.indexWhere((existing) => existing.id == task.id);
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
    sortOrderUpdates.addAll(updates);
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
    folderSortOrderUpdates.addAll(updates);
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
  final List<TaskFolderSortOrderUpdate> sortOrderUpdates = [];

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
    sortOrderUpdates.addAll(updates);
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
