import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/execution/execution_log_store.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_status_badge.dart';

/// 任务日志弹窗
///
/// 通过 Riverpod 实时更新任务状态和进度，
/// 通过 [logStore] 读取 FFmpeg 文件日志。
/// 日志区域自动滚动到底部跟随最新输出。
class TaskLogDialog extends ConsumerStatefulWidget {
  final MediaTask task;
  final ExecutionLogStore logStore;
  final Duration pollInterval;

  const TaskLogDialog({
    super.key,
    required this.task,
    required this.logStore,
    this.pollInterval = const Duration(milliseconds: 500),
  });

  @override
  ConsumerState<TaskLogDialog> createState() => _TaskLogDialogState();

  static Future<void> show(
    BuildContext context,
    MediaTask task, {
    required ExecutionLogStore logStore,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TaskLogDialog(task: task, logStore: logStore),
    );
  }
}

class _TaskLogDialogState extends ConsumerState<TaskLogDialog> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<ExecutionLogSnapshot>? _logSubscription;
  String? _liveLog;
  String? _logPath;
  bool _logTruncated = false;
  bool _autoScroll = true;

  MediaTask _resolveCurrentTask() {
    final taskList = ref.watch(mediaTaskListProvider);
    if (!taskList.hasValue) {
      return widget.task;
    }
    for (final task in taskList.requireValue) {
      if (task.id == widget.task.id) {
        return task;
      }
    }
    return widget.task;
  }

  @override
  void initState() {
    super.initState();
    _logSubscription = widget.logStore
        .watchLatestForTask(widget.task.id, interval: widget.pollInterval)
        .listen((snapshot) {
          if (!mounted) {
            return;
          }
          setState(() {
            _liveLog = snapshot.content;
            _logPath = snapshot.filePath;
            _logTruncated = snapshot.truncated;
          });
          _scrollToBottom();
        });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_autoScroll || !_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = _resolveCurrentTask();

    return WorkbenchDialogFrame(
      maxWidth: 900,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
      child: SizedBox(
        height: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(currentTask),
            const SizedBox(height: 16),
            Expanded(child: _buildLogContent()),
            const SizedBox(height: 16),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MediaTask currentTask) {
    return Row(
      children: [
        Expanded(
          child: WorkbenchDialogBackHeader(
            title: currentTask.fileName,
            onClose: () => Navigator.of(context).pop(),
            trailing: MediaTaskStatusBadge(task: currentTask),
          ),
        ),
      ],
    );
  }

  Widget _buildLogContent() {
    final log = _liveLog;

    if (log == null || log.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final metrics = notification.metrics;
                  final atBottom =
                      metrics.pixels >= metrics.maxScrollExtent - 5;
                  if (_autoScroll != atBottom) {
                    setState(() {
                      _autoScroll = atBottom;
                    });
                  }
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  log,
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    color: Color(0xFF333333),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (!_autoScroll) _buildAutoScrollHint(),
        ],
      ),
    );
  }

  Widget _buildAutoScrollHint() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _autoScroll = true;
        });
        _scrollToBottom();
      },
      child: Container(
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF6290FF),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(7),
            bottomRight: Radius.circular(7),
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '跟随最新日志',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final currentTask = _resolveCurrentTask();
    String message;
    if (currentTask.status == TaskStatus.pending) {
      message = '任务尚未开始，暂无日志';
    } else if (currentTask.status == TaskStatus.analyzing) {
      message = '正在分析媒体文件...';
    } else if (currentTask.errorMessage != null &&
        currentTask.errorMessage!.trim().isNotEmpty) {
      message = currentTask.errorMessage!;
    } else {
      message = '暂无日志记录';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xFFCCCCCC),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final log = _liveLog;
    final hasLog = log != null && log.isNotEmpty;

    return Row(
      children: [
        Text(
          _getLogInfo(),
          style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
        ),
        const Spacer(),
        if (hasLog) ...[
          WorkbenchDialogActionButton(
            label: '复制日志',
            backgroundColor: const Color(0xFFB8B8B8),
            onPressed: _copyLog,
            width: 85,
          ),
          const SizedBox(width: 12),
        ],
        WorkbenchDialogActionButton(
          label: '关闭',
          backgroundColor: const Color(0xFF6290FF),
          onPressed: () => Navigator.of(context).pop(),
          width: 75,
        ),
      ],
    );
  }

  String _getLogInfo() {
    final log = _liveLog;
    if (log == null || log.isEmpty) {
      return '无日志';
    }

    final lines = log.split('\n').length;
    final bytes = log.length;
    final kb = (bytes / 1024).toStringAsFixed(1);
    final suffix = _logTruncated ? ' · 已截断' : '';
    final pathSuffix = _logPath == null ? '' : ' · 文件日志';
    return '$lines 行 · $kb KB$pathSuffix$suffix';
  }

  void _copyLog() {
    final log = _liveLog;
    if (log == null || log.isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: log));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('日志已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
