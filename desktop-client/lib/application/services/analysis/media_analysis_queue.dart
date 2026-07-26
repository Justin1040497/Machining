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

/// Client-side submission coordinator for FEngine analysis requests.
///
/// This object only provides duplicate suppression, a bounded IPC submission
/// window, and UI-facing status tracking. FEngine owns work ordering,
/// priority, execution slots, and queue backpressure after a request is sent.
/// The local pending list therefore represents requests waiting for an IPC
/// slot, not a second media-processing scheduler.
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
    this.maxInFlightSubmissions = 32,
    this.onEntryStateChanged,
  }) : _analyzeTask = analyzeTask,
       assert(maxInFlightSubmissions > 0);

  final Future<MediaTask?> Function(String taskId) _analyzeTask;

  /// Maximum number of Client -> FEngine requests waiting for a terminal
  /// response at once. It is an IPC backpressure limit, not an execution
  /// concurrency setting.
  final int maxInFlightSubmissions;

  /// 条目状态变化回调，用于 UI 层刷新任务列表。
  void Function(MediaAnalysisEntry entry)? onEntryStateChanged;

  final Queue<String> _pendingQueue = Queue<String>();
  final Map<String, MediaAnalysisEntry> _entries = {};
  final Set<String> _activeTaskIds = {};
  final Set<Future<void>> _activeOperations = {};
  int _activeCount = 0;
  bool _stopped = false;
  Completer<void>? _idleCompleter;
  Future<void>? _stopFuture;

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
    return _activeTaskIds.contains(taskId);
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
  Future<void> stop() {
    return _stopFuture ??= _stop();
  }

  Future<void> _stop() async {
    _stopped = true;
    _pendingQueue.clear();

    // 队列不能中断调用方的 Future，但停止后不再接受其结果。
    for (final entry in _entries.values) {
      if (entry.state == MediaAnalysisEntryState.pending ||
          entry.state == MediaAnalysisEntryState.analyzing) {
        _entries[entry.taskId] = entry.copyWith(
          state: MediaAnalysisEntryState.cancelled,
        );
      }
    }

    _emitSnapshot();
    await Future.wait([..._activeOperations]);
    if (!(_idleCompleter?.isCompleted ?? true)) {
      _idleCompleter?.complete();
    }
    _idleCompleter = null;
    await _snapshotController.close();
  }

  void _tryProcessNext() {
    if (_stopped) {
      return;
    }

    while (_activeCount < maxInFlightSubmissions && _pendingQueue.isNotEmpty) {
      final taskId = _pendingQueue.removeFirst();
      _activeCount++;
      _activeTaskIds.add(taskId);
      _entries[taskId] = _entries[taskId]!.copyWith(
        state: MediaAnalysisEntryState.analyzing,
      );
      _emitSnapshot();

      late final Future<void> operation;
      operation = _executeAnalysis(taskId).whenComplete(() {
        _activeOperations.remove(operation);
      });
      _activeOperations.add(operation);
      unawaited(operation);
    }
  }

  Future<void> _executeAnalysis(String taskId) async {
    MediaAnalysisEntry? resultEntry;
    try {
      final analyzedTask = await _analyzeTask(taskId);

      // 检查是否被取消
      if (_stopped) {
        return;
      }

      if (analyzedTask == null) {
        resultEntry = _entries[taskId] = _entries[taskId]!.copyWith(
          state: MediaAnalysisEntryState.cancelled,
        );
      } else if (analyzedTask.isAnalysisReady) {
        resultEntry = _entries[taskId] = _entries[taskId]!.copyWith(
          state: MediaAnalysisEntryState.succeeded,
        );
      } else {
        resultEntry = _entries[taskId] = _entries[taskId]!.copyWith(
          state: MediaAnalysisEntryState.failed,
          errorMessage:
              analyzedTask.failure?.userMessage ??
              analyzedTask.analysisErrorMessage ??
              '媒体分析未生成可用结果',
        );
      }
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
      _activeTaskIds.remove(taskId);
      _emitSnapshot();

      // 通知 UI 层分析状态变化
      final entry = resultEntry;
      if (entry != null) {
        onEntryStateChanged?.call(entry);
      }

      if (isIdle) {
        if (!(_idleCompleter?.isCompleted ?? true)) {
          _idleCompleter?.complete();
        }
        _idleCompleter = null;
      } else if (!_stopped) {
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
