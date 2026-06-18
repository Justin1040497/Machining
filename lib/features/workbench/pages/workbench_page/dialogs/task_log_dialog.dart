import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/execution/execution_log_store.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_status_badge.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';

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

class TaskFolderLogDialog extends StatelessWidget {
  const TaskFolderLogDialog({
    super.key,
    required this.title,
    required this.tasks,
    required this.logStore,
  });

  final String title;
  final List<MediaTask> tasks;
  final ExecutionLogStore logStore;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<MediaTask> tasks,
    required ExecutionLogStore logStore,
  }) {
    return showDialog(
      context: context,
      builder: (context) =>
          TaskFolderLogDialog(title: title, tasks: tasks, logStore: logStore),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadAggregatedLog(),
      builder: (context, snapshot) {
        final content = snapshot.data ?? '正在读取日志...';
        return WorkbenchDialogFrame(
          maxWidth: 900,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
          child: SizedBox(
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkbenchDialogBackHeader(
                  title: title,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                Expanded(child: _FolderLogContent(content: content)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Spacer(),
                    WorkbenchDialogActionButton(
                      label: '关闭',
                      backgroundColor: context.frameLeanColors.primary,
                      onPressed: () => Navigator.of(context).pop(),
                      width: 75,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _loadAggregatedLog() async {
    final sections = <String>[];
    for (final task in tasks) {
      final snapshot = await logStore.readLatestForTask(task.id);
      final log = snapshot.content.trim();
      sections.add(
        [
          '===== ${task.fileName} · ${_statusLabel(task.status)} =====',
          log.isEmpty ? '暂无日志' : log,
        ].join('\n'),
      );
    }
    return sections.join('\n\n');
  }

  String _statusLabel(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => '等待中',
      TaskStatus.analyzing => '分析中',
      TaskStatus.running => '处理中',
      TaskStatus.paused => '已暂停',
      TaskStatus.completed => '已完成',
      TaskStatus.failed => '失败',
      TaskStatus.cancelled => '已取消',
      TaskStatus.missingSource => '源文件丢失',
    };
  }
}

class _FolderLogContent extends StatelessWidget {
  const _FolderLogContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: TextStyle(
            fontFamily: 'Courier New',
            fontSize: 12.flSp,
            color: colors.textPrimary,
            height: 1.5,
          ),
        ),
      ),
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
    final colors = context.frameLeanColors;
    final log = _liveLog;

    if (log == null || log.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
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
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12.flSp,
                    color: colors.textPrimary,
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
    final colors = context.frameLeanColors;

    return GestureDetector(
      onTap: () {
        setState(() {
          _autoScroll = true;
        });
        _scrollToBottom();
      },
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(7),
            bottomRight: Radius.circular(7),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '跟随最新日志',
          style: TextStyle(color: colors.onPrimary, fontSize: 12.flSp),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.frameLeanColors;
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
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: colors.textTertiary, fontSize: 14.flSp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final colors = context.frameLeanColors;
    final log = _liveLog;
    final hasLog = log != null && log.isNotEmpty;

    return Row(
      children: [
        Text(
          _getLogInfo(),
          style: TextStyle(color: colors.textTertiary, fontSize: 12.flSp),
        ),
        const Spacer(),
        if (hasLog) ...[
          WorkbenchDialogActionButton(
            label: '复制日志',
            backgroundColor: colors.statusCancelled,
            onPressed: _copyLog,
            width: 85,
          ),
          const SizedBox(width: 12),
        ],
        WorkbenchDialogActionButton(
          label: '关闭',
          backgroundColor: colors.primary,
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

    unawaited(_copyLogToClipboard(log));
  }

  Future<void> _copyLogToClipboard(String log) async {
    await Clipboard.setData(ClipboardData(text: log));
    await ref
        .read(appNotificationManagerProvider)
        .notify(
          level: AppNotificationLevel.success,
          title: '日志已复制到剪贴板',
          source: 'workbench',
        );
  }
}
