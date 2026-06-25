import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:framelean/application/constants.dart';

class ExecutionLogSnapshot {
  final String? filePath;
  final String content;
  final bool truncated;

  const ExecutionLogSnapshot({
    required this.filePath,
    required this.content,
    required this.truncated,
  });

  bool get exists => filePath != null;
}

class ExecutionLogStore {
  static const defaultMaxReadBytes = maxLogReadBytes;

  final Directory logsDirectory;
  final int maxReadBytes;

  const ExecutionLogStore({
    required this.logsDirectory,
    this.maxReadBytes = defaultMaxReadBytes,
  });

  Future<File?> latestLogFileForTask(String taskId) async {
    if (!await logsDirectory.exists()) {
      return null;
    }

    File? latestFile;
    DateTime? latestModifiedAt;
    await for (final entity in logsDirectory.list()) {
      if (entity is! File) {
        continue;
      }

      final name = path.basename(entity.path);
      if (!name.contains('_${taskId}_') || !name.endsWith('.log')) {
        continue;
      }

      final modifiedAt = await entity.lastModified();
      if (latestModifiedAt == null || modifiedAt.isAfter(latestModifiedAt)) {
        latestFile = entity;
        latestModifiedAt = modifiedAt;
      }
    }

    return latestFile;
  }

  Future<ExecutionLogSnapshot> readLatestForTask(String taskId) async {
    final file = await latestLogFileForTask(taskId);
    if (file == null) {
      return const ExecutionLogSnapshot(
        filePath: null,
        content: '',
        truncated: false,
      );
    }

    return readFile(file);
  }

  Future<ExecutionLogSnapshot> readFile(File file) async {
    final length = await file.length();
    if (length <= maxReadBytes) {
      return ExecutionLogSnapshot(
        filePath: file.path,
        content: await file.readAsString(),
        truncated: false,
      );
    }

    final handle = await file.open();
    try {
      await handle.setPosition(length - maxReadBytes);
      final bytes = await handle.read(maxReadBytes);
      return ExecutionLogSnapshot(
        filePath: file.path,
        content:
            '[日志过长，仅显示最后 ${_formatBytes(maxReadBytes)}]\n'
            '${String.fromCharCodes(bytes)}',
        truncated: true,
      );
    } finally {
      await handle.close();
    }
  }

  Stream<ExecutionLogSnapshot> watchLatestForTask(
    String taskId, {
    Duration interval = debounceInterval,
  }) async* {
    ExecutionLogSnapshot? previous;
    while (true) {
      final current = await readLatestForTask(taskId);
      if (previous == null ||
          previous.filePath != current.filePath ||
          previous.content != current.content ||
          previous.truncated != current.truncated) {
        yield current;
        previous = current;
      }
      await Future<void>.delayed(interval);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)}KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}
