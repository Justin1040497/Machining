import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/library.dart';

class ApplyOutputSettingsToExistingTasksUseCase {
  ApplyOutputSettingsToExistingTasksUseCase({
    required this.repository,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final MediaTaskRepository repository;
  final DateTime Function() now;

  Future<void> call(AppSettings settings) async {
    final tasks = await repository.loadAllTasks();
    final appliedAt = now();

    for (final task in tasks) {
      if (!_canRefreshOutputSettings(task.status)) {
        continue;
      }
      if (task.config.outputLocationMode != OutputLocationMode.system) {
        continue;
      }

      final updatedTask = task.copyWith(
        config: buildOutputTaskConfigFromSettings(
          task: task,
          settings: settings,
          now: appliedAt,
          version: processingVersionForTask(
            tasks: tasks,
            inputPath: task.inputPath,
            mediaKind: task.mediaKind,
            purpose: task.purpose,
            taskId: task.id,
          ),
        ),
      );
      await repository.saveTask(updatedTask);
    }
  }

  bool _canRefreshOutputSettings(TaskStatus status) {
    return status == TaskStatus.awaitingAnalysis ||
        status == TaskStatus.pending ||
        status == TaskStatus.failed ||
        status == TaskStatus.cancelled;
  }
}
