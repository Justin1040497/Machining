import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/task_status.dart';

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

      final updatedTask = task.copyWith(
        config: buildOutputTaskConfigFromSettings(
          task: task,
          settings: settings,
          now: appliedAt,
        ),
      );
      await repository.saveTask(updatedTask);
    }
  }

  bool _canRefreshOutputSettings(TaskStatus status) {
    return status == TaskStatus.pending ||
        status == TaskStatus.failed ||
        status == TaskStatus.cancelled;
  }
}
