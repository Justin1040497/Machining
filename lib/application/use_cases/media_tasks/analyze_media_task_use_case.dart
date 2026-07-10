import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/media_analyzer.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/library.dart';

class AnalyzeMediaTaskUseCase {
  final MediaTaskRepository repository;
  final MediaAnalyzer analyzer;
  final SourceFileChecker sourceFileChecker;
  final Future<ResolvedFfmpegRuntime> Function() readRuntime;
  final Future<ResolvedFfmpegRuntime> Function() refreshRuntime;
  final MediaInputPreparer mediaInputPreparer;

  const AnalyzeMediaTaskUseCase({
    required this.repository,
    required this.analyzer,
    required this.sourceFileChecker,
    required this.readRuntime,
    required this.refreshRuntime,
    this.mediaInputPreparer = const NoopMediaInputPreparer(),
  });

  Future<MediaTask?> call(String taskId) async {
    var runtime = await readRuntime();
    if (!runtime.canAnalyze || runtime.ffprobe == null) {
      runtime = await refreshRuntime();
    }

    if (!runtime.canAnalyze || runtime.ffprobe == null) {
      return markAnalysisUnavailable(taskId, 'FFprobe 不可用，无法分析媒体信息');
    }

    var task = findMediaTaskById(await repository.loadAllTasks(), taskId);
    if (task.analysisResult == null && task.status == TaskStatus.pending) {
      task = task.copyWith(status: TaskStatus.analyzing);
      await repository.saveTask(task);
    }

    if (!await sourceFileChecker.exists(task.inputPath)) {
      final updatedTask = task.markMissingSource();
      await repository.saveTask(updatedTask);
      return updatedTask;
    }

    PreparedMediaInput? preparedInput;
    try {
      preparedInput = await mediaInputPreparer.prepare(
        task,
        purpose: MediaInputPreparationPurpose.analysis,
      );
      final result = await analyzer.analyze(
        ffprobePath: runtime.ffprobe!.path,
        inputPath: preparedInput.task.inputPath,
      );
      final latestTask = findMediaTaskById(
        await repository.loadAllTasks(),
        taskId,
      );
      final updatedTask = latestTask
          .withAnalysisResult(result)
          .copyWith(
            status: latestTask.status == TaskStatus.analyzing
                ? TaskStatus.pending
                : latestTask.status,
          );
      await repository.saveTask(updatedTask);
      return updatedTask;
    } on Object catch (error) {
      final latestTask = findMediaTaskById(
        await repository.loadAllTasks(),
        taskId,
      );
      final updatedTask = latestTask
          .withAnalysisError(error.toString())
          .markFailed('媒体分析失败: $error');
      await repository.saveTask(updatedTask);
      return updatedTask;
    } finally {
      final input = preparedInput;
      if (input != null) {
        await mediaInputPreparer.cleanup(input);
      }
    }
  }

  Future<MediaTask?> markAnalysisUnavailable(
    String taskId,
    String message,
  ) async {
    final task = maybeFindMediaTaskById(
      await repository.loadAllTasks(),
      taskId,
    );
    if (task == null) {
      return null;
    }

    final updatedTask = task.withAnalysisError(message).markFailed(message);
    await repository.saveTask(updatedTask);
    return updatedTask;
  }
}
