import 'dart:async';
import 'dart:collection';

import 'package:framelean/application/services/execution/media_resource_monitor.dart';

/// 媒体工作的类别。
enum MediaWorkKind {
  /// FFmpeg 编码与转换（正式任务）
  encode,

  /// FFprobe 媒体分析
  analyze,

  /// 缩略图生成
  thumbnail,

  /// 预览帧生成
  preview,

  /// 专有媒体预处理
  proprietaryMediaPreparation,
}

/// 媒体工作的优先级，用于资源抢占时的排序。
enum MediaWorkPriority {
  /// 前台最高优先级，用户当前正在交互的任务
  foreground,

  /// 用户主动发起的操作
  userInitiated,

  /// 常规优先级
  normal,

  /// 后台任务
  background,

  /// 空闲时执行
  idle,
}

/// 媒体工作请求，由调用方提交以申请资源。
class MediaWorkRequest {
  const MediaWorkRequest({
    required this.id,
    required this.kind,
    required this.priority,
    this.estimatedMemoryBytes,
    this.estimatedCpuWeight,
  });

  /// 唯一标识，通常为 "kind:taskId" 或类似格式。
  final String id;

  /// 工作类别。
  final MediaWorkKind kind;

  /// 优先级。
  final MediaWorkPriority priority;

  /// 预估内存需求（字节），null 表示未知。
  final int? estimatedMemoryBytes;

  /// 预估 CPU 权重（1-10），null 表示未知。
  final int? estimatedCpuWeight;
}

/// 资源租约，工作完成后必须释放。
abstract class MediaWorkLease {
  /// 工作唯一标识。
  String get workId;

  /// 释放租约，让调度器回收资源。
  Future<void> release();
}

/// 全局媒体工作资源调度器。
///
/// 管理所有媒体工作（编码、分析、缩略图、预览等）的资源分配。
/// 不处理任何业务逻辑（FFmpeg 命令构造、数据库操作等），
/// 只负责决定“当前是否可以运行这个任务”。
///
/// 用法：
/// ```dart
/// final scheduler = MediaWorkScheduler();
/// final lease = await scheduler.acquire(MediaWorkRequest(
///   id: 'encode:$taskId',
///   kind: MediaWorkKind.encode,
///   priority: MediaWorkPriority.foreground,
/// ));
/// try {
///   await executeTask(task);
/// } finally {
///   await lease.release();
/// }
/// ```
class MediaWorkScheduler {
  MediaWorkScheduler({
    this.maxConcurrentEncodes = 1,
    this.maxConcurrentAnalyses = 1,
    this.maxConcurrentThumbnails = 1,
    this.maxConcurrentPreviews = 1,
    this.maxConcurrentPreparations = 1,
    this.maxTotalConcurrentWorks = 3,
    this.resourceMonitor,
  });

  /// 最大并发编码任务数。
  final int maxConcurrentEncodes;

  /// 最大并发分析任务数。
  final int maxConcurrentAnalyses;

  /// 最大并发缩略图任务数。
  final int maxConcurrentThumbnails;

  /// 最大并发预览任务数。
  final int maxConcurrentPreviews;

  /// 最大并发预处理任务数。
  final int maxConcurrentPreparations;

  /// 所有工作的全局最大并发数。
  final int maxTotalConcurrentWorks;

  /// 可选的资源监控器。设置后，调度器在资源压力时自动限制新工作启动。
  final MediaResourceMonitor? resourceMonitor;

  final Map<String, _ActiveLease> _activeLeases = {};
  final Queue<MediaWorkRequest> _waitingQueue = Queue<MediaWorkRequest>();
  final Set<String> _allWorkIds = {};

  /// 当前运行的编码任务数。
  int get activeEncodes =>
      _countByKind(MediaWorkKind.encode);

  /// 当前运行的分析任务数。
  int get activeAnalyses =>
      _countByKind(MediaWorkKind.analyze);

  /// 当前运行的所有工作数。
  int get totalActiveWorks => _activeLeases.length;

  /// 是否可以立即启动指定类别的工作。
  bool canStartImmediately(MediaWorkRequest request) {
    if (_stopped) {
      return false;
    }

    if (_activeLeases.length >= maxTotalConcurrentWorks) {
      return false;
    }

    final currentByKind = _countByKind(request.kind);
    final maxForKind = _maxForKind(request.kind);

    if (currentByKind >= maxForKind) {
      return false;
    }

    // 编码任务运行时，暂停后台缩略图和预览
    if (request.kind == MediaWorkKind.thumbnail ||
        request.kind == MediaWorkKind.preview) {
      if (_countByKind(MediaWorkKind.encode) > 0) {
        return false;
      }
    }

    // 编码任务运行时，不启动新分析（允许当前分析完成）
    if (request.kind == MediaWorkKind.analyze &&
        _countByKind(MediaWorkKind.encode) > 0) {
      return false;
    }

    // 资源监控器检查：压力状态下限制新工作启动。
    final monitor = resourceMonitor;
    if (monitor != null) {
      final pressure = monitor.currentPressure;
      if (pressure == MediaResourcePressure.severePressure) {
        // 严重压力：只允许前台编码任务继续。
        if (request.kind != MediaWorkKind.encode ||
            request.priority != MediaWorkPriority.foreground) {
          return false;
        }
      } else if (pressure == MediaResourcePressure.underPressure) {
        // 压力状态：停止启动新的后台工作（分析、缩略图、预览）。
        if (request.kind == MediaWorkKind.analyze ||
            request.kind == MediaWorkKind.thumbnail ||
            request.kind == MediaWorkKind.preview ||
            request.kind == MediaWorkKind.proprietaryMediaPreparation) {
          return false;
        }
        // 不启动第二个编码任务。
        if (request.kind == MediaWorkKind.encode &&
            _countByKind(MediaWorkKind.encode) > 0) {
          return false;
        }
      }
    }

    return true;
  }

  /// 申请资源租约。
  ///
  /// 如果可以立即启动，则立即返回租约。
  /// 否则加入等待队列，待资源可用时再返回。
  Future<MediaWorkLease> acquire(MediaWorkRequest request) async {
    if (_stopped) {
      throw StateError('调度器已停止');
    }

    // 去重：同一 workId 不重复申请
    if (_allWorkIds.contains(request.id)) {
      throw StateError('工作 ID 重复: ${request.id}');
    }

    if (canStartImmediately(request)) {
      return _grantLease(request);
    }

    // 加入等待队列
    final completer = Completer<MediaWorkLease>();
    _waitingQueue.add(request);
    _waitingCompleters[request.id] = completer;
    return completer.future;
  }

  /// 取消等待中的工作。
  void cancelWaiting(String workId) {
    _waitingQueue.removeWhere((r) => r.id == workId);
    final completer = _waitingCompleters.remove(workId);
    completer?.completeError(StateError('工作已取消: $workId'));
    _allWorkIds.remove(workId);
  }

  /// 检查指定 workId 是否正在运行中。
  bool isRunning(String workId) {
    return _activeLeases.containsKey(workId);
  }

  /// 检查指定 workId 是否在等待队列中。
  bool isWaiting(String workId) {
    return _waitingCompleters.containsKey(workId);
  }

  /// 停止调度器，取消所有等待中的工作。
  Future<void> stop() async {
    _stopped = true;

    // 取消所有等待中工作
    while (_waitingQueue.isNotEmpty) {
      final request = _waitingQueue.removeFirst();
      final completer = _waitingCompleters.remove(request.id);
      completer?.completeError(StateError('调度器已停止'));
      _allWorkIds.remove(request.id);
    }
  }

  // ------------------------------------------------------------------
  // Private
  // ------------------------------------------------------------------

  bool _stopped = false;
  final Map<String, Completer<MediaWorkLease>> _waitingCompleters = {};

  int _countByKind(MediaWorkKind kind) {
    return _activeLeases.values.where((l) => l.kind == kind).length;
  }

  int _maxForKind(MediaWorkKind kind) {
    return switch (kind) {
      MediaWorkKind.encode => maxConcurrentEncodes,
      MediaWorkKind.analyze => maxConcurrentAnalyses,
      MediaWorkKind.thumbnail => maxConcurrentThumbnails,
      MediaWorkKind.preview => maxConcurrentPreviews,
      MediaWorkKind.proprietaryMediaPreparation => maxConcurrentPreparations,
    };
  }

  MediaWorkLease _grantLease(MediaWorkRequest request) {
    _allWorkIds.add(request.id);
    final lease = _ActiveLease(
      workId: request.id,
      kind: request.kind,
      priority: request.priority,
      onRelease: () => _releaseLease(request),
    );
    _activeLeases[request.id] = lease;
    return lease;
  }

  void _releaseLease(MediaWorkRequest request) {
    _activeLeases.remove(request.id);
    _allWorkIds.remove(request.id);

    if (_stopped) {
      return;
    }

    // 释放资源后，尝试从等待队列中挑选下一个可执行任务
    _tryWakeNext();
  }

  void _tryWakeNext() {
    // 按优先级排序等待队列
    final sorted = _waitingQueue.toList()
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));

    for (final request in sorted) {
      if (canStartImmediately(request)) {
        _waitingQueue.remove(request);
        final completer = _waitingCompleters.remove(request.id);
        if (completer != null) {
          completer.complete(_grantLease(request));
        }
        return; // 一次只唤醒一个
      }
    }
  }
}

class _ActiveLease implements MediaWorkLease {
  _ActiveLease({
    required this.workId,
    required this.kind,
    required this.priority,
    required this.onRelease,
  });

  @override
  final String workId;

  final MediaWorkKind kind;
  final MediaWorkPriority priority;
  final void Function() onRelease;

  @override
  Future<void> release() async {
    onRelease();
  }
}
