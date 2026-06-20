import 'dart:io';

import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:path/path.dart' as path;

class InterruptedOutputCleanupResult {
  const InterruptedOutputCleanupResult({
    required this.deletedPartialFileCount,
    required this.failedTaskCount,
  });

  final int deletedPartialFileCount;
  final int failedTaskCount;
}

class LocalInterruptedOutputCleaner {
  const LocalInterruptedOutputCleaner();

  Future<InterruptedOutputCleanupResult> cleanup({
    required MediaTaskRepository repository,
    required AppSettings settings,
  }) async {
    final tasks = await repository.loadAllTasks();
    final directories = <String>{
      ?settings.defaultOutputDirectory,
      for (final task in tasks) ...[
        path.dirname(task.inputPath),
        if (task.outputPath case final outputPath?) path.dirname(outputPath),
        if (task.config.outputDirectory.trim().isNotEmpty)
          task.config.outputDirectory.trim(),
      ],
    };

    var deletedPartialFileCount = 0;
    for (final directoryPath in directories) {
      final directory = Directory(directoryPath);
      try {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is! File || !_isFrameLeanPartial(entity.path)) continue;
          await entity.delete();
          deletedPartialFileCount += 1;
        }
      } on Object {
        // Startup cleanup is best effort. The directory may be offline or
        // read-only; task state recovery below must still continue.
      }
    }

    var failedTaskCount = 0;
    for (final task in tasks) {
      if (task.status != TaskStatus.running &&
          task.status != TaskStatus.paused) {
        continue;
      }
      final failedTask = task
          .markFailed('应用上次异常退出，未完成的临时输出已清理，请重新开始任务。')
          .copyWith(clearOutputPath: true);
      await repository.saveTask(failedTask);
      failedTaskCount += 1;
    }

    return InterruptedOutputCleanupResult(
      deletedPartialFileCount: deletedPartialFileCount,
      failedTaskCount: failedTaskCount,
    );
  }

  bool _isFrameLeanPartial(String filePath) {
    final name = path.basename(filePath);
    return name.startsWith('.framelean-') && name.contains('.partial');
  }
}
