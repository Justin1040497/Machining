import 'dart:io';

import 'package:framelean/application/services/platform/file_revealer.dart';
import 'package:path/path.dart' as path;

class FileRevealTarget {
  const FileRevealTarget({required this.path, required this.isDirectory});

  final String path;
  final bool isDirectory;
}

class FileManagerCommand {
  const FileManagerCommand({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

class LocalFileRevealer implements FileRevealer {
  const LocalFileRevealer();

  @override
  Future<FileRevealResult> revealPath(String targetPath) async {
    final trimmedPath = targetPath.trim();
    if (trimmedPath.isEmpty) {
      return const FileRevealResult.failure('没有可打开的文件位置');
    }

    try {
      final target = resolveRevealTarget(trimmedPath);
      if (target == null) {
        return FileRevealResult.failure('文件位置不存在: $trimmedPath');
      }

      final result = await runRevealInFileManager(target);
      if (result.exitCode != 0) {
        return FileRevealResult.failure(failureMessageFor(result));
      }
    } on Object catch (error) {
      return FileRevealResult.failure('打开文件所在位置失败: $error');
    }

    return const FileRevealResult.success();
  }

  static FileRevealTarget? resolveRevealTarget(String targetPath) {
    final targetType = FileSystemEntity.typeSync(targetPath);
    if (targetType == FileSystemEntityType.directory) {
      return FileRevealTarget(path: targetPath, isDirectory: true);
    }

    if (targetType != FileSystemEntityType.notFound) {
      return FileRevealTarget(path: targetPath, isDirectory: false);
    }

    final parentPath = path.dirname(targetPath);
    if (parentPath == targetPath || parentPath.trim().isEmpty) {
      return null;
    }

    final parentType = FileSystemEntity.typeSync(parentPath);
    if (parentType == FileSystemEntityType.directory) {
      return FileRevealTarget(path: parentPath, isDirectory: true);
    }

    return null;
  }

  static Future<ProcessResult> runRevealInFileManager(
    FileRevealTarget target,
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

  static FileManagerCommand? buildRevealCommand({
    required String targetPath,
    required bool targetIsDirectory,
    String? operatingSystem,
  }) {
    final currentOperatingSystem = operatingSystem ?? Platform.operatingSystem;

    if (currentOperatingSystem == 'macos') {
      return FileManagerCommand(
        executable: 'open',
        arguments: targetIsDirectory ? [targetPath] : ['-R', targetPath],
      );
    }

    if (currentOperatingSystem == 'windows') {
      return FileManagerCommand(
        executable: 'explorer.exe',
        arguments: targetIsDirectory ? [targetPath] : ['/select,', targetPath],
      );
    }

    if (currentOperatingSystem == 'linux') {
      final linuxPathContext = path.Context(style: path.Style.posix);
      return FileManagerCommand(
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
