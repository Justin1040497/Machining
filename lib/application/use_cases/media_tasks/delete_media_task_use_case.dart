import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/library.dart';

class DeleteMediaTaskUseCase {
  final MediaTaskRepository repository;
  final FfmpegTaskQueueRunner queueRunner;

  const DeleteMediaTaskUseCase({
    required this.repository,
    required this.queueRunner,
  });

  Future<List<MediaTask>> call(String taskId) async {
    final tasks = await repository.loadAllTasks();
    final task = findMediaTaskById(tasks, taskId);

    if (task.status == TaskStatus.running || task.status == TaskStatus.paused) {
      await queueRunner.cancelTask(taskId);
    }

    await repository.deleteTaskById(taskId);
    return tasks.where((task) => task.id != taskId).toList();
  }
}
