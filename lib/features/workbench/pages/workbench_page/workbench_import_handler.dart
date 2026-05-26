import 'dart:io';

import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:machining/features/workbench/providers/media_task_notifier.dart';

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
      if (entityType != FileSystemEntityType.file) {
        failures.add(
          DroppedImportFailure(path: inputPath, reason: '只能导入视频文件，不能导入文件夹'),
        );
        continue;
      }

      try {
        final task = await notifier.createDraftFromPath(inputPath);
        createdTasks.add(task);
      } on Object catch (error) {
        failures.add(
          DroppedImportFailure(
            path: inputPath,
            reason: formatImportFailureReason(error),
          ),
        );
      }
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
