import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/domain/library.dart';

List<MediaTask> reorderMediaTasksInMemory(
  List<MediaTask> tasks, {
  required int oldIndex,
  required int newIndex,
}) {
  if (oldIndex < 0 || oldIndex >= tasks.length) {
    return tasks;
  }

  if (tasks[oldIndex].status == TaskStatus.running) {
    return tasks;
  }

  var targetIndex = newIndex;
  if (targetIndex > oldIndex) {
    targetIndex -= 1;
  }
  targetIndex = targetIndex.clamp(0, tasks.length - 1);
  if (oldIndex == targetIndex) {
    return tasks;
  }

  final reordered = [...tasks];
  final movedTask = reordered.removeAt(oldIndex);
  reordered.insert(targetIndex, movedTask);

  return [
    for (var index = 0; index < reordered.length; index += 1)
      reordered[index].copyWith(sortOrder: index),
  ];
}

List<MediaTaskSortOrderUpdate> mediaTaskSortOrderUpdatesFor(
  List<MediaTask> tasks,
) {
  return [
    for (final task in tasks)
      MediaTaskSortOrderUpdate(taskId: task.id, sortOrder: task.sortOrder),
  ];
}

class ReorderMediaTasksUseCase {
  final MediaTaskRepository repository;

  const ReorderMediaTasksUseCase({required this.repository});

  Future<List<MediaTask>> call({
    required int oldIndex,
    required int newIndex,
  }) async {
    final tasks = await repository.loadAllTasks();
    final reorderedTasks = reorderMediaTasksInMemory(
      tasks,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (identical(reorderedTasks, tasks)) {
      return tasks;
    }

    await repository.updateTaskSortOrders(
      mediaTaskSortOrderUpdatesFor(reorderedTasks),
    );
    return reorderedTasks;
  }
}
