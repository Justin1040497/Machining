import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/library.dart';

class RetryMediaTaskResult {
  final MediaTask task;
  final bool shouldAnalyze;

  const RetryMediaTaskResult({required this.task, required this.shouldAnalyze});
}

class RetryMediaTaskUseCase {
  final MediaTaskRepository repository;
  final AppSettingsRepository settingsRepository;
  final EngineAnalysisProjectionRepository analysisProjectionRepository;
  final SourceFileChecker sourceFileChecker;
  final SourceFileFingerprintReader fingerprintReader;

  const RetryMediaTaskUseCase({
    required this.repository,
    required this.settingsRepository,
    required this.analysisProjectionRepository,
    required this.sourceFileChecker,
    required this.fingerprintReader,
  });

  Future<RetryMediaTaskResult> call(String taskId) async {
    final tasks = await repository.loadAllTasks();
    final task = findMediaTaskById(tasks, taskId);
    final failure = task.failure;
    if ((task.status == TaskStatus.analysisFailed ||
            task.status == TaskStatus.executionFailed) &&
        failure != null &&
        !failure.retryable &&
        failure.recoveryAction == TaskRecoveryAction.none) {
      throw StateError('当前失败不支持直接重试，请先解决失败原因。');
    }

    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      return RetryMediaTaskResult(task: updatedTask, shouldAnalyze: false);
    }

    final fingerprint = await fingerprintReader.read(task.inputPath);
    final settings = await settingsRepository.loadSettings();
    final shouldAnalyze =
        task.analysisResult == null ||
        task.failure?.recoveryAction == TaskRecoveryAction.retryAnalysis;
    final retryTask = task
        .markPendingForRetry()
        .clearError()
        .withSourceFileFingerprint(fingerprint);
    final resetTask = shouldAnalyze
        ? retryTask.clearAnalysis().markAwaitingAnalysis()
        : retryTask;
    final pendingTask = resetTask.copyWith(
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
    );

    if (shouldAnalyze) {
      await analysisProjectionRepository.deleteByTaskId(taskId);
    }
    await repository.saveTask(pendingTask);
    return RetryMediaTaskResult(
      task: pendingTask,
      shouldAnalyze: shouldAnalyze,
    );
  }
}
