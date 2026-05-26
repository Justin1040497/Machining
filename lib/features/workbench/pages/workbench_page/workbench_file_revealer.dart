import 'dart:io';

import 'package:framelean/domain/entities/media_task.dart';
import 'package:path/path.dart' as path;

class WorkbenchFileRevealResult {
  const WorkbenchFileRevealResult._({required this.message});

  const WorkbenchFileRevealResult.success() : this._(message: null);

  const WorkbenchFileRevealResult.failure(String message)
    : this._(message: message);

  final String? message;

  bool get succeeded => message == null;
}

abstract final class WorkbenchFileRevealer {
  static Future<WorkbenchFileRevealResult> revealTask(MediaTask task) {
    final targetPath = task.outputPath?.trim().isNotEmpty == true
        ? task.outputPath!.trim()
        : task.inputPath;
    return revealPath(targetPath);
  }

  static Future<WorkbenchFileRevealResult> revealPath(String targetPath) async {
    final trimmedPath = targetPath.trim();
    if (trimmedPath.isEmpty) {
      return const WorkbenchFileRevealResult.failure('没有可打开的文件位置');
    }

    try {
      final result = await runRevealInFileManager(trimmedPath);
      if (result.exitCode != 0) {
        return WorkbenchFileRevealResult.failure(
          '打开文件所在位置失败: ${result.stderr}',
        );
      }
    } on Object catch (error) {
      return WorkbenchFileRevealResult.failure('打开文件所在位置失败: $error');
    }

    return const WorkbenchFileRevealResult.success();
  }

  static Future<ProcessResult> runRevealInFileManager(String targetPath) {
    if (Platform.isMacOS) {
      return Process.run('open', ['-R', targetPath]);
    }

    if (Platform.isWindows) {
      return Process.run('explorer', ['/select,$targetPath']);
    }

    if (Platform.isLinux) {
      return Process.run('xdg-open', [path.dirname(targetPath)]);
    }

    return Future.value(ProcessResult(0, 1, '', '当前系统暂不支持打开文件所在位置'));
  }
}
