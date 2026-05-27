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

class WorkbenchFileRevealTarget {
  const WorkbenchFileRevealTarget({
    required this.path,
    required this.isDirectory,
  });

  final String path;
  final bool isDirectory;
}

class WorkbenchFileManagerCommand {
  const WorkbenchFileManagerCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
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
      final target = resolveRevealTarget(trimmedPath);
      if (target == null) {
        return WorkbenchFileRevealResult.failure('文件位置不存在: $trimmedPath');
      }

      final result = await runRevealInFileManager(target);
      if (result.exitCode != 0) {
        return WorkbenchFileRevealResult.failure(failureMessageFor(result));
      }
    } on Object catch (error) {
      return WorkbenchFileRevealResult.failure('打开文件所在位置失败: $error');
    }

    return const WorkbenchFileRevealResult.success();
  }

  static WorkbenchFileRevealTarget? resolveRevealTarget(String targetPath) {
    final targetType = FileSystemEntity.typeSync(targetPath);
    if (targetType == FileSystemEntityType.directory) {
      return WorkbenchFileRevealTarget(path: targetPath, isDirectory: true);
    }

    if (targetType != FileSystemEntityType.notFound) {
      return WorkbenchFileRevealTarget(path: targetPath, isDirectory: false);
    }

    final parentPath = path.dirname(targetPath);
    if (parentPath == targetPath || parentPath.trim().isEmpty) {
      return null;
    }

    final parentType = FileSystemEntity.typeSync(parentPath);
    if (parentType == FileSystemEntityType.directory) {
      return WorkbenchFileRevealTarget(path: parentPath, isDirectory: true);
    }

    return null;
  }

  static Future<ProcessResult> runRevealInFileManager(
    WorkbenchFileRevealTarget target,
  ) async {
    final command = buildRevealCommand(
      targetPath: target.path,
      targetIsDirectory: target.isDirectory,
    );
    if (command == null) {
      return Future.value(ProcessResult(0, 1, '', '当前系统暂不支持打开文件所在位置'));
    }

    if (Platform.isWindows) {
      await Process.start(
        command.executable,
        command.arguments,
        mode: ProcessStartMode.detached,
      );
      return ProcessResult(0, 0, '', '');
    }

    return Process.run(command.executable, command.arguments);
  }

  static WorkbenchFileManagerCommand? buildRevealCommand({
    required String targetPath,
    required bool targetIsDirectory,
    String? operatingSystem,
  }) {
    final currentOperatingSystem = operatingSystem ?? Platform.operatingSystem;

    if (currentOperatingSystem == 'macos') {
      return WorkbenchFileManagerCommand(
        executable: 'open',
        arguments: targetIsDirectory ? [targetPath] : ['-R', targetPath],
      );
    }

    if (currentOperatingSystem == 'windows') {
      return WorkbenchFileManagerCommand(
        executable: 'explorer.exe',
        arguments: targetIsDirectory ? [targetPath] : ['/select,', targetPath],
      );
    }

    if (currentOperatingSystem == 'linux') {
      final linuxPathContext = path.Context(style: path.Style.posix);
      return WorkbenchFileManagerCommand(
        executable: 'xdg-open',
        arguments: [
          targetIsDirectory ? targetPath : linuxPathContext.dirname(targetPath),
        ],
      );
    }

    return null;
  }

  static String failureMessageFor(ProcessResult result) {
    final stderr = result.stderr.toString().trim();
    if (stderr.isNotEmpty) {
      return '打开文件所在位置失败: $stderr';
    }

    final stdout = result.stdout.toString().trim();
    if (stdout.isNotEmpty) {
      return '打开文件所在位置失败: $stdout';
    }

    return '打开文件所在位置失败: 退出码 ${result.exitCode}';
  }
}
