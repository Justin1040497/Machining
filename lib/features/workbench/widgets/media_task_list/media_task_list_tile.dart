import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_action_button.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_status_badge.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_thumbnail.dart';

class MediaTaskListTile extends StatelessWidget {
  final MediaTask task;
  final bool selected;
  final ImageProvider? thumbnail;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onRetry;
  final VoidCallback? onRelink;
  final VoidCallback? onShowLog;
  final VoidCallback? onRemove;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Widget? dragHandle;
  final bool tooltipsEnabled;

  const MediaTaskListTile({
    super.key,
    required this.task,
    this.selected = false,
    this.thumbnail,
    this.onTap,
    this.onStart,
    this.onPause,
    this.onRetry,
    this.onRelink,
    this.onShowLog,
    this.onRemove,
    this.onSecondaryTapDown,
    this.dragHandle,
    this.tooltipsEnabled = true,
  });

  bool get hasProgressBackground =>
      task.status == TaskStatus.running && task.progress > 0;

  bool _shouldShowLogButton() {
    return task.status == TaskStatus.running ||
        task.status == TaskStatus.completed ||
        task.status == TaskStatus.failed ||
        task.status == TaskStatus.paused;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 86,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.borderStrong : colors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (hasProgressBackground) _buildProgressBackground(),
              Row(
                children: [
                  const SizedBox(width: 10),
                  dragHandle ?? const SizedBox(width: 24),
                  const SizedBox(width: 4),
                  MediaTaskThumbnail(thumbnail: thumbnail),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTaskText(context)),
                  MediaTaskActionButton(
                    task: task,
                    onStart: onStart,
                    onPause: onPause,
                    onRetry: onRetry,
                    onRelink: onRelink,
                    tooltipsEnabled: tooltipsEnabled,
                  ),
                  const SizedBox(width: 4),
                  if (_shouldShowLogButton())
                    MediaTaskIconButton(
                      tooltip: '查看日志',
                      onPressed: onShowLog,
                      icon: Icons.description_outlined,
                      tooltipsEnabled: tooltipsEnabled,
                    ),
                  const SizedBox(width: 4),
                  MediaTaskIconButton(
                    tooltip: '移除任务',
                    onPressed: onRemove,
                    icon: Icons.close_rounded,
                    tooltipsEnabled: tooltipsEnabled,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBackground() {
    final progress = task.progress.clamp(0, 1).toDouble();

    return Positioned.fill(
      child: Builder(
        builder: (context) {
          final colors = context.frameLeanColors;

          return AnimatedFractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: colors.progress,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskText(BuildContext context) {
    final colors = context.frameLeanColors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MaybeTooltip(
          enabled: tooltipsEnabled,
          message: task.fileName,
          child: Semantics(
            label: task.fileName,
            child: Text(
              task.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.flSp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            MediaTaskStatusBadge(task: task),
            const SizedBox(width: 10),
            Text(
              _formatBytes(task.sourceFileFingerprint?.fileSize),
              style: TextStyle(color: colors.textTertiary, fontSize: 11.flSp),
            ),
          ],
        ),
      ],
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) {
      return '-';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    if (unitIndex == 0) {
      return '${value.round()}${units[unitIndex]}';
    }

    final text = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text${units[unitIndex]}';
  }
}

class _MaybeTooltip extends StatelessWidget {
  const _MaybeTooltip({
    required this.enabled,
    required this.message,
    required this.child,
  });

  final bool enabled;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 500),
      child: child,
    );
  }
}
