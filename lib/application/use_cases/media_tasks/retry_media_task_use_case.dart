import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';

class RetryMediaTaskResult {
  final MediaTask task;
  final bool shouldAnalyze;

  const RetryMediaTaskResult({required this.task, required this.shouldAnalyze});
}

class RetryMediaTaskUseCase {
  final MediaTaskRepository repository;
  final AppSettingsRepository settingsRepository;
  final SourceFileChecker sourceFileChecker;
  final SourceFileFingerprintReader fingerprintReader;

  const RetryMediaTaskUseCase({
    required this.repository,
    required this.settingsRepository,
    required this.sourceFileChecker,
    required this.fingerprintReader,
  });

  Future<RetryMediaTaskResult> call(String taskId) async {
    final tasks = await repository.loadAllTasks();
    final task = findMediaTaskById(tasks, taskId);

    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      return RetryMediaTaskResult(task: updatedTask, shouldAnalyze: false);
    }

    final fingerprint = await fingerprintReader.read(task.inputPath);
    final settings = await settingsRepository.loadSettings();
    final retryTask = task
        .markPendingForRetry()
        .clearError()
        .withSourceFileFingerprint(fingerprint)
        .clearAnalysis();
    final analyzingTask = retryTask
        .copyWith(
          config: buildOutputTaskConfigFromSettings(
            task: retryTask,
            settings: settings,
            now: DateTime.now(),
            version: processingVersionForTask(
              tasks: tasks,
              inputPath: retryTask.inputPath,
              mediaKind: retryTask.mediaKind,
              purpose: retryTask.purpose,
              taskId: retryTask.id,
            ),
          ),
        )
        .copyWith(status: TaskStatus.analyzing);

    await repository.saveTask(analyzingTask);
    return RetryMediaTaskResult(task: analyzingTask, shouldAnalyze: true);
  }
}
