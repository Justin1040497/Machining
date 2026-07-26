import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/domain/library.dart';

class ReconcileMediaTasksResult {
  final List<MediaTask> tasks;
  final List<String> taskIdsNeedingAnalysis;

  const ReconcileMediaTasksResult({
    required this.tasks,
    required this.taskIdsNeedingAnalysis,
  });
}

class ReconcileMediaTasksUseCase {
  final MediaTaskRepository repository;
  final SourceFileChecker sourceFileChecker;
  final SourceFileFingerprintReader fingerprintReader;

  const ReconcileMediaTasksUseCase({
    required this.repository,
    required this.sourceFileChecker,
    required this.fingerprintReader,
  });

  Future<ReconcileMediaTasksResult> call() async {
    final tasks = await repository.loadAllTasks();
    final checkedTasks = <MediaTask>[];
    final taskIdsNeedingAnalysis = <String>[];
    var hasChanged = false;

    for (final task in tasks) {
      final exists = await sourceFileChecker.exists(task.inputPath);

      if (!exists) {
        if (task.status == TaskStatus.missingSource) {
          checkedTasks.add(task);
        } else {
          checkedTasks.add(task.markMissingSource());
          hasChanged = true;
        }
        continue;
      }

      if (task.status == TaskStatus.missingSource) {
        final fingerprint = await fingerprintReader.read(task.inputPath);
        final updatedTask = task
            .clearAnalysis()
            .markAwaitingAnalysis()
            .withSourceFileFingerprint(fingerprint);
        checkedTasks.add(updatedTask);
        taskIdsNeedingAnalysis.add(updatedTask.id);
        hasChanged = true;
        continue;
      }

      final fingerprint = await fingerprintReader.read(task.inputPath);
      if (!fingerprint.isSameAs(task.sourceFileFingerprint)) {
        final updatedTask = task
            .withSourceFileFingerprint(fingerprint)
            .clearAnalysis()
            .markAwaitingAnalysis();
        checkedTasks.add(updatedTask);
        taskIdsNeedingAnalysis.add(updatedTask.id);
        hasChanged = true;
        continue;
      }

      if (task.analysisResult == null) {
        final updatedTask = task.isAwaitingAnalysis
            ? task
            : task.markAwaitingAnalysis();
        checkedTasks.add(updatedTask);
        taskIdsNeedingAnalysis.add(updatedTask.id);
        hasChanged = hasChanged || updatedTask != task;
        continue;
      }

      if (task.status == TaskStatus.awaitAnalysis) {
        checkedTasks.add(task.markAnalyzing().markAnalysisReady());
        hasChanged = true;
        continue;
      }

      checkedTasks.add(task);
    }

    if (hasChanged) {
      await repository.replaceAllTasks(checkedTasks);
    }

    return ReconcileMediaTasksResult(
      tasks: checkedTasks,
      taskIdsNeedingAnalysis: taskIdsNeedingAnalysis,
    );
  }
}
