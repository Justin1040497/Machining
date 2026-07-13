import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/media_analyzer.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
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
    var task = await repository.loadTaskById(taskId);
    if (task == null || !task.isAwaitingAnalysis) {
      return task;
    }
    task = task.markAnalyzing();
    await repository.saveTask(task);

    var runtime = await readRuntime();
    if (!runtime.canAnalyze || runtime.ffprobe == null) {
      runtime = await refreshRuntime();
    }

    if (!runtime.canAnalyze || runtime.ffprobe == null) {
      return markAnalysisUnavailable(taskId, 'FFprobe 不可用，无法分析媒体信息');
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
      final latestTask = await repository.loadTaskById(taskId);
      if (latestTask == null) {
        return null;
      }
      final updatedTask = latestTask
          .withAnalysisResult(result)
          .markAnalysisReady();
      await repository.saveTask(updatedTask);
      return updatedTask;
    } on Object catch (error) {
      final latestTask = await repository.loadTaskById(taskId);
      if (latestTask == null) {
        return null;
      }
      final occurredAt = DateTime.now().millisecondsSinceEpoch;
      final updatedTask = latestTask.markFailed(
        TaskFailure(
          stage: TaskFailureStage.analysis,
          code: TaskFailureCode.analysisFailed,
          userMessage: '媒体分析失败，请确认文件可以正常读取后重试。',
          technicalSummary: error.toString(),
          occurredAt: occurredAt,
          retryable: true,
        ),
      );
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
    final task = await repository.loadTaskById(taskId);
    if (task == null) {
      return null;
    }

    final occurredAt = DateTime.now().millisecondsSinceEpoch;
    final updatedTask = task.markFailed(
      TaskFailure(
        stage: TaskFailureStage.analysis,
        code: TaskFailureCode.analysisRuntimeUnavailable,
        userMessage: message,
        technicalSummary: message,
        occurredAt: occurredAt,
        retryable: true,
      ),
    );
    await repository.saveTask(updatedTask);
    return updatedTask;
  }
}
