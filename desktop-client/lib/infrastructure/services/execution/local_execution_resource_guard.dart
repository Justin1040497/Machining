import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class LocalExecutionResourceGuard implements ExecutionResourceGuard {
  const LocalExecutionResourceGuard({
    this.processorCountOverride,
    this.totalMemoryBytesOverride,
  });

  final int? processorCountOverride;
  final int? totalMemoryBytesOverride;

  static const _eightGb = 8 * 1024 * 1024 * 1024;
  static const _sixteenGb = 16 * 1024 * 1024 * 1024;

  @override
  Future<ExecutionCapacity> capacity({
    required int userMaxConcurrentExecutions,
    required List<MediaTask> runningTasks,
  }) async {
    final processors = processorCountOverride ?? Platform.numberOfProcessors;
    final memoryBytes = totalMemoryBytesOverride ?? _bestEffortTotalMemory();
    var effective = userMaxConcurrentExecutions.clamp(1, 3);
    String? reason;

    if (processors <= 4 || (memoryBytes != null && memoryBytes < _eightGb)) {
      effective = 1;
      reason = '当前设备资源较紧张，已临时降为单任务执行';
    } else if (effective >= 3 &&
        (processors < 8 || (memoryBytes != null && memoryBytes < _sixteenGb))) {
      effective = 2;
      reason = '当前设备不适合同时执行 3 个任务，已临时限制为 2 个';
    }

    return ExecutionCapacity(
      effectiveMaxConcurrentExecutions: effective,
      reason: reason,
    );
  }

  @override
  Future<bool> canStartTask({
    required MediaTask task,
    required List<MediaTask> runningTasks,
    required int userMaxConcurrentExecutions,
  }) async {
    final processors = processorCountOverride ?? Platform.numberOfProcessors;
    final currentCapacity = await capacity(
      userMaxConcurrentExecutions: userMaxConcurrentExecutions,
      runningTasks: runningTasks,
    );
    if (runningTasks.length >=
        currentCapacity.effectiveMaxConcurrentExecutions) {
      return false;
    }
    if (!isHeavyExecutionTask(task)) {
      return true;
    }

    final heavyRunningTasks = runningTasks
        .where(isHeavyExecutionTask)
        .toList(growable: false);
    final videoSlotLimit = _effectiveVideoSlotLimit(
      processors: processors,
      memoryBytes: totalMemoryBytesOverride ?? _bestEffortTotalMemory(),
      userMaxConcurrentExecutions:
          currentCapacity.effectiveMaxConcurrentExecutions,
    );
    if (heavyRunningTasks.length >= videoSlotLimit) {
      return false;
    }

    final threadBudget = _threadBudget(processors);
    final runningThreadWeight = heavyRunningTasks.fold<int>(
      0,
      (total, runningTask) =>
          total + _taskThreadWeight(runningTask, processors),
    );
    final candidateThreadWeight = _taskThreadWeight(task, processors);
    if (heavyRunningTasks.isNotEmpty &&
        runningThreadWeight + candidateThreadWeight > threadBudget) {
      return false;
    }

    return true;
  }

  int _effectiveVideoSlotLimit({
    required int processors,
    required int? memoryBytes,
    required int userMaxConcurrentExecutions,
  }) {
    if (userMaxConcurrentExecutions <= 1 ||
        processors <= 4 ||
        (memoryBytes != null && memoryBytes < _eightGb)) {
      return 1;
    }
    if (processors >= 8 && (memoryBytes == null || memoryBytes >= _sixteenGb)) {
      return userMaxConcurrentExecutions.clamp(1, 2);
    }
    return 1;
  }

  int _threadBudget(int processors) {
    return processors <= 2 ? 1 : processors - 1;
  }

  int _taskThreadWeight(MediaTask task, int processors) {
    final manualLimit = task.config.threadLimit;
    if (manualLimit != null) {
      return manualLimit.clamp(1, processors);
    }
    if (!isHeavyExecutionTask(task)) {
      return 1;
    }
    return processors >= 8 ? 3 : 2;
  }

  int? _bestEffortTotalMemory() {
    if (Platform.isWindows) {
      return _readWindowsTotalMemory();
    }
    if (Platform.isMacOS) {
      return _readMacOSTotalMemory();
    }
    if (Platform.isLinux) {
      return _readLinuxTotalMemory();
    }
    return null;
  }

  int? _readMacOSTotalMemory() {
    try {
      final result = Process.runSync('sysctl', const ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim());
      }
    } on Object {
      // Fall through to the conservative unknown-memory path.
    }
    return null;
  }

  int? _readWindowsTotalMemory() {
    try {
      // 使用 wmic 获取系统总物理内存（单位：字节）
      final result = Process.runSync(
        'wmic',
        const ['computersystem', 'get', 'TotalPhysicalMemory'],
      );
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'(\d+)').firstMatch(output);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
    } on Object {
      // Fall through to the conservative unknown-memory path.
    }
    return null;
  }

  int? _readLinuxTotalMemory() {
    try {
      final file = File('/proc/meminfo');
      if (!file.existsSync()) {
        return null;
      }
      final contents = file.readAsStringSync();
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(contents);
      if (match != null) {
        final kb = int.tryParse(match.group(1)!);
        if (kb != null) {
          return kb * 1024; // 转换为字节
        }
      }
    } on Object {
      // Fall through.
    }
    return null;
  }
}
