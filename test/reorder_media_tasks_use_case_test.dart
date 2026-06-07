import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/use_cases/media_tasks/reorder_media_tasks_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';

void main() {
  group('ReorderMediaTasksUseCase', () {
    test('updates sort orders without replacing full task records', () async {
      final repository = FakeMediaTaskRepository([
        mediaTask(id: 'first', sortOrder: 0),
        mediaTask(id: 'second', sortOrder: 1),
        mediaTask(id: 'third', sortOrder: 2),
      ]);

      final tasks = await ReorderMediaTasksUseCase(
        repository: repository,
      ).call(oldIndex: 0, newIndex: 3);

      expect(tasks.map((task) => task.id), ['second', 'third', 'first']);
      expect(repository.replaceAllCallCount, 0);
      expect(repository.sortOrderUpdates, [
        const MediaTaskSortOrderUpdate(taskId: 'second', sortOrder: 0),
        const MediaTaskSortOrderUpdate(taskId: 'third', sortOrder: 1),
        const MediaTaskSortOrderUpdate(taskId: 'first', sortOrder: 2),
      ]);
    });

    test('does not persist when reorder is invalid', () async {
      final repository = FakeMediaTaskRepository([
        mediaTask(id: 'first', sortOrder: 0),
      ]);

      final tasks = await ReorderMediaTasksUseCase(
        repository: repository,
      ).call(oldIndex: -1, newIndex: 1);

      expect(tasks.map((task) => task.id), ['first']);
      expect(repository.sortOrderUpdates, isEmpty);
      expect(repository.replaceAllCallCount, 0);
    });
  });
}

MediaTask mediaTask({required String id, required int sortOrder}) {
  return MediaTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: sortOrder,
    createdAt: 1,
  );
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  final List<MediaTask> tasks;
  final List<MediaTaskSortOrderUpdate> sortOrderUpdates = [];
  int replaceAllCallCount = 0;

  @override
  Future<void> deleteTaskById(String taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async {
    return [...tasks]..sort((first, second) {
      final order = first.sortOrder.compareTo(second.sortOrder);
      if (order != 0) {
        return order;
      }

      return first.createdAt.compareTo(second.createdAt);
    });
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    replaceAllCallCount += 1;
    this.tasks
      ..clear()
      ..addAll(tasks);
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
