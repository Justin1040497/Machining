import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/library.dart';

class DeleteMediaTaskUseCase {
  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;

  const DeleteMediaTaskUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
    Object? queueRunner,
  });

  Future<List<MediaTask>> call(String taskId) async {
    final tasks = await repository.loadAllTasks();
    findMediaTaskById(tasks, taskId);

    await analysisProjectionRepository.deleteByTaskId(taskId);
    await repository.deleteTaskById(taskId);
    return tasks.where((task) => task.id != taskId).toList();
  }
}
