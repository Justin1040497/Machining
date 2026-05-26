import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/domain/entities/media_task.dart';

class ClearMediaTasksUseCase {
  final MediaTaskRepository repository;
  final FfmpegTaskQueueRunner queueRunner;

  const ClearMediaTasksUseCase({
    required this.repository,
    required this.queueRunner,
  });

  Future<List<MediaTask>> call() async {
    await queueRunner.cancelAllExecutions();
    await repository.replaceAllTasks([]);
    return const [];
  }
}
