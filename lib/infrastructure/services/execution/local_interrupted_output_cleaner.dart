import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
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
      // 应用重启后旧进程已不存在：将 running、paused、analyzing 状态恢复。
      // running/paused：FFmpeg 进程已消亡，标记失败并清理输出。
      // analyzing：FFprobe 进程已消亡，恢复为 pending 等待重新分析。
      if (task.status == TaskStatus.running ||
          task.status == TaskStatus.paused) {
        final failedTask = task
            .markFailed('应用上次异常退出，未完成的临时输出已清理，请重新开始任务。')
            .copyWith(clearOutputPath: true);
        await repository.saveTask(failedTask);
        failedTaskCount += 1;
      } else if (task.status == TaskStatus.analyzing) {
        // FFprobe 进程在重启后已不存在，恢复为 pending 以便重新分析。
        final recoveredTask = task.copyWith(status: TaskStatus.pending);
        await repository.saveTask(recoveredTask);
        failedTaskCount += 1;
      }
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
