import 'dart:io';
import 'dart:async';

import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';

class WorkbenchImportResult {
  const WorkbenchImportResult({
    required this.createdTasks,
    required this.failures,
  });

  final List<MediaTask> createdTasks;
  final List<DroppedImportFailure> failures;
}

abstract final class WorkbenchImportHandler {
  static Future<WorkbenchImportResult> importDroppedPaths({
    required Iterable<String> paths,
    required MediaTaskListNotifier notifier,
  }) async {
    final createdTasks = <MediaTask>[];
    final createdFileTasks = <MediaTask>[];
    final failures = <DroppedImportFailure>[];

    for (final rawPath in paths) {
      final inputPath = rawPath.trim();
      if (inputPath.isEmpty) {
        failures.add(
          const DroppedImportFailure(path: '未知文件', reason: '文件路径为空'),
        );
        continue;
      }

      final entityType = FileSystemEntity.typeSync(inputPath);
      if (entityType == FileSystemEntityType.directory) {
        final result = await notifier.importFolderFromPath(inputPath);
        createdTasks.addAll(result.createdTasks);
        if (result.foundNoMedia) {
          failures.add(
            DroppedImportFailure(path: inputPath, reason: '未找到可识别媒体文件'),
          );
        }
        failures.addAll(
          result.failures.map(
            (failure) => DroppedImportFailure(
              path: failure.path,
              reason: failure.reason,
            ),
          ),
        );
        continue;
      }

      if (entityType != FileSystemEntityType.file) {
        failures.add(
          DroppedImportFailure(path: inputPath, reason: '路径不是可导入的文件或文件夹'),
        );
        continue;
      }

      try {
        final task = await notifier.createDraftFromPath(
          inputPath,
          analyzeInBackground: false,
        );
        createdTasks.add(task);
        createdFileTasks.add(task);
      } on Object catch (error) {
        failures.add(
          DroppedImportFailure(
            path: inputPath,
            reason: formatImportFailureReason(error),
          ),
        );
      }
    }

    await notifier.createTaskFoldersForImportedBatch(createdFileTasks);
    if (createdFileTasks.isNotEmpty) {
      unawaited(
        notifier.analyzeTasksInBackground(
          createdFileTasks.map((task) => task.id).toList(),
        ),
      );
    }

    return WorkbenchImportResult(
      createdTasks: createdTasks,
      failures: failures,
    );
  }

  static String formatImportFailureReason(Object error) {
    const stateErrorPrefix = 'Bad state: ';
    final message = error.toString();
    if (message.startsWith(stateErrorPrefix)) {
      return message.substring(stateErrorPrefix.length);
    }

    return message;
  }
}
