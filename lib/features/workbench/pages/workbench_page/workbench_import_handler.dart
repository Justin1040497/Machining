import 'dart:io';

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
    final failures = <DroppedImportFailure>[];
    final pendingFilePaths = <String>[];

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
        // 文件夹导入立即处理
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

      pendingFilePaths.add(inputPath);
    }

    // 批量导入纯文件，使用批量写入优化
    if (pendingFilePaths.isNotEmpty) {
      try {
        final batchTasks = await notifier.createDraftsFromPaths(pendingFilePaths);
        createdTasks.addAll(batchTasks);
      } on Object catch (error) {
        // createDraftsFromPaths 内部已跳过不支持的文件，
        // 这里捕获的通常是整体失败
        failures.add(
          DroppedImportFailure(
            path: '批量导入',
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
