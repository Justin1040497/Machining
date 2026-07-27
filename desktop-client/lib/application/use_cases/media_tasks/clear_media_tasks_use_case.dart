import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/domain/library.dart';

class ClearMediaTasksUseCase {
  final MediaTaskRepository repository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;
  final TaskFolderRepository taskFolderRepository;

  const ClearMediaTasksUseCase({
    required this.repository,
    required this.analysisProjectionRepository,
    required this.taskFolderRepository,
    Object? queueRunner,
  });

  Future<List<MediaTask>> call() async {
    await analysisProjectionRepository.deleteAll();
    await repository.replaceAllTasks([]);
    await taskFolderRepository.clearAllFolders();
    return const [];
  }
}
