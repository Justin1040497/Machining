import 'dart:async';
import 'dart:collection';

import 'package:framelean/domain/library.dart';

/// 媒体分析队列中单个条目的状态。
enum MediaAnalysisEntryState {
  /// 等待分析
  pending,

  /// 正在分析
  analyzing,

  /// 分析成功
  succeeded,

  /// 分析失败
  failed,

  /// 已取消
  cancelled,
}

/// 媒体分析队列中单个条目的信息。
class MediaAnalysisEntry {
  const MediaAnalysisEntry({
    required this.taskId,
    required this.state,
    this.errorMessage,
  });

  final String taskId;
  final MediaAnalysisEntryState state;
  final String? errorMessage;

  MediaAnalysisEntry copyWith({
    MediaAnalysisEntryState? state,
    String? errorMessage,
  }) {
    return MediaAnalysisEntry(
      taskId: taskId,
      state: state ?? this.state,
      errorMessage: errorMessage,
    );
  }
}

/// 媒体分析队列的可观察快照。
class MediaAnalysisQueueSnapshot {
  const MediaAnalysisQueueSnapshot({
    required this.pending,
    required this.analyzing,
    required this.succeeded,
    required this.failed,
    required this.total,
  });

  /// 等待分析的数量
  final int pending;

  /// 正在分析的数量
  final int analyzing;

  /// 分析成功的数量
  final int succeeded;

  /// 分析失败的数量
  final int failed;

  /// 总任务数
  final int total;
}

/// 全局媒体分析队列执行器。
///
/// 所有媒体分析入口（单文件导入、多文件导入、文件夹导入、拖拽导入、
/// 启动恢复、手动重新分析等）必须通过此队列统一调度，确保：
/// - 任意时刻活跃 FFprobe 进程数 <= 1
/// - 同一 taskId 不重复分析
/// - 单个文件失败不影响其他文件
/// - 应用退出时能安全停止
///
/// 用法：
/// ```dart
/// final queue = MediaAnalysisQueue(
///   analyzeTask: (taskId) async { ... },
/// );
///
/// // 加入一批任务
/// await queue.enqueueAll(['task1', 'task2', 'task3']);
///
/// // 等待队列完成
/// await queue.waitForCompletion();
/// ```
class MediaAnalysisQueue {
  MediaAnalysisQueue({
    required Future<MediaTask?> Function(String taskId) analyzeTask,
    this.maxConcurrentAnalyses = 1,
    this.onEntryStateChanged,
  }) : _analyzeTask = analyzeTask;

  final Future<MediaTask?> Function(String taskId) _analyzeTask;

  /// 全局 FFprobe 最大并发数，第一版固定为 1。
  final int maxConcurrentAnalyses;

  /// 条目状态变化回调，用于 UI 层刷新任务列表。
  final void Function(MediaAnalysisEntry entry)? onEntryStateChanged;

  final Queue<String> _pendingQueue = Queue<String>();
  final Set<String> _allTaskIds = {};
  final Map<String, MediaAnalysisEntry> _entries = {};
  String? _currentTaskId;
  int _activeCount = 0;
  bool _stopped = false;
  Completer<void>? _idleCompleter;

  final StreamController<MediaAnalysisQueueSnapshot> _snapshotController =
      StreamController<MediaAnalysisQueueSnapshot>.broadcast();

  /// 队列状态可观察流。
  Stream<MediaAnalysisQueueSnapshot> get snapshots =>
      _snapshotController.stream;

  /// 当前快照。
  MediaAnalysisQueueSnapshot get snapshot {
    var pending = 0;
    var analyzing = 0;
    var succeeded = 0;
    var failed = 0;
    for (final entry in _entries.values) {
      switch (entry.state) {
        case MediaAnalysisEntryState.pending:
          pending++;
        case MediaAnalysisEntryState.analyzing:
          analyzing++;
        case MediaAnalysisEntryState.succeeded:
          succeeded++;
        case MediaAnalysisEntryState.failed:
        case MediaAnalysisEntryState.cancelled:
          failed++;
      }
    }
    return MediaAnalysisQueueSnapshot(
      pending: pending,
      analyzing: analyzing,
      succeeded: succeeded,
      failed: failed,
      total: _entries.length,
    );
  }

  /// 是否空闲（无等待、无运行中的分析）。
  bool get isIdle => _pendingQueue.isEmpty && _activeCount == 0;

  /// 添加单个 taskId 到分析队列。
  void enqueue(String taskId) {
    if (_stopped) {
      return;
    }

    // 去重：只阻止已处于 pending 或 analyzing 状态的任务重复加入。
    // completed、failed、cancelled 状态的任务允许重新加入（用于重试）。
    final existing = _entries[taskId];
    if (existing != null &&
        (existing.state == MediaAnalysisEntryState.pending ||
            existing.state == MediaAnalysisEntryState.analyzing)) {
      return;
    }

    _allTaskIds.add(taskId);
    _entries[taskId] = MediaAnalysisEntry(
      taskId: taskId,
      state: MediaAnalysisEntryState.pending,
    );
    _pendingQueue.addLast(taskId);
    _emitSnapshot();
    _tryProcessNext();
  }

  /// 添加一批 taskId 到分析队列。
  void enqueueAll(Iterable<String> taskIds) {
    for (final taskId in taskIds) {
      if (_stopped) {
        break;
      }
      // 去重：只阻止已处于 pending 或 analyzing 状态的任务重复加入。
      final existing = _entries[taskId];
      if (existing != null &&
          (existing.state == MediaAnalysisEntryState.pending ||
              existing.state == MediaAnalysisEntryState.analyzing)) {
        continue;
      }
      _allTaskIds.add(taskId);
      _entries[taskId] = MediaAnalysisEntry(
        taskId: taskId,
        state: MediaAnalysisEntryState.pending,
      );
      _pendingQueue.addLast(taskId);
    }
    _emitSnapshot();
    _tryProcessNext();
  }

  /// 取消等待中的 taskId。
  void cancelWaiting(String taskId) {
    _pendingQueue.remove(taskId);
    final entry = _entries[taskId];
    if (entry != null && entry.state == MediaAnalysisEntryState.pending) {
      _entries[taskId] = entry.copyWith(
        state: MediaAnalysisEntryState.cancelled,
      );
      _emitSnapshot();
    }
  }

  /// 检查 taskId 是否正在等待分析。
  bool isWaiting(String taskId) {
    final entry = _entries[taskId];
    return entry != null && entry.state == MediaAnalysisEntryState.pending;
  }

  /// 检查 taskId 是否正在分析中。
  bool isAnalyzing(String taskId) {
    return _currentTaskId == taskId;
  }

  /// 等待队列空闲。
  Future<void> waitForCompletion() {
    if (isIdle) {
      return Future.value();
    }
    _idleCompleter ??= Completer<void>();
    return _idleCompleter!.future;
  }

  /// 停止队列，取消所有等待和正在进行的分析。
  Future<void> stop() async {
    _stopped = true;
    _pendingQueue.clear();

    // 将等待中的任务标记为取消
    for (final entry in _entries.values) {
      if (entry.state == MediaAnalysisEntryState.pending) {
        _entries[entry.taskId] = entry.copyWith(
          state: MediaAnalysisEntryState.cancelled,
        );
      }
    }

    _emitSnapshot();
    _idleCompleter?.complete();
    await _snapshotController.close();
  }

  void _tryProcessNext() {
    if (_stopped) {
      return;
    }

    while (_activeCount < maxConcurrentAnalyses && _pendingQueue.isNotEmpty) {
      final taskId = _pendingQueue.removeFirst();
      _activeCount++;
      _currentTaskId = taskId;
      _entries[taskId] = _entries[taskId]!.copyWith(
        state: MediaAnalysisEntryState.analyzing,
      );
      _emitSnapshot();

      unawaited(_executeAnalysis(taskId));
    }
  }

  Future<void> _executeAnalysis(String taskId) async {
    MediaAnalysisEntry? resultEntry;
    try {
      await _analyzeTask(taskId);

      // 检查是否被取消
      if (_stopped) {
        return;
      }

      resultEntry = _entries[taskId] = _entries[taskId]!.copyWith(
        state: MediaAnalysisEntryState.succeeded,
      );
    } on Object catch (error) {
      if (_stopped) {
        return;
      }
      resultEntry = _entries[taskId] = _entries[taskId]!.copyWith(
        state: MediaAnalysisEntryState.failed,
        errorMessage: error.toString(),
      );
    } finally {
      _activeCount--;
      if (_currentTaskId == taskId) {
        _currentTaskId = null;
      }
      _emitSnapshot();

      // 通知 UI 层分析状态变化
      final entry = resultEntry;
      if (entry != null) {
        onEntryStateChanged?.call(entry);
      }

      if (isIdle) {
        _idleCompleter?.complete();
        _idleCompleter = null;
      } else {
        _tryProcessNext();
      }
    }
  }

  void _emitSnapshot() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }
}
