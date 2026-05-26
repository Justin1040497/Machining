import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';

class ReorderMediaTasksUseCase {
  final MediaTaskRepository repository;

  const ReorderMediaTasksUseCase({required this.repository});

  Future<List<MediaTask>> call({
    required int oldIndex,
    required int newIndex,
  }) async {
    final tasks = await repository.loadAllTasks();

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

    final reorderedTasks = <MediaTask>[];
    for (var index = 0; index < reordered.length; index += 1) {
      reorderedTasks.add(reordered[index].copyWith(sortOrder: index));
    }

    await repository.replaceAllTasks(reorderedTasks);
    return reorderedTasks;
  }
}
