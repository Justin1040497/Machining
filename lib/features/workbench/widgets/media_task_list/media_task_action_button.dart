import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_item_models.dart';

class MediaTaskActionButton extends StatelessWidget {
  const MediaTaskActionButton({
    super.key,
    required this.task,
    this.onStart,
    this.onPause,
    this.onRetry,
    this.onRelink,
    this.tooltipsEnabled = true,
  });

  final MediaTask task;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onRetry;
  final VoidCallback? onRelink;
  final bool tooltipsEnabled;

  @override
  Widget build(BuildContext context) {
    final action = resolveTaskAction();

    if (action == null) {
      return const SizedBox(width: 36, height: 36);
    }

    return MediaTaskIconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      icon: action.icon,
      tooltipsEnabled: tooltipsEnabled,
    );
  }

  MediaTaskListAction? resolveTaskAction() {
    return switch (task.status) {
      TaskStatus.pending when task.analysisResult != null =>
        MediaTaskListAction(
          tooltip: '开始压缩',
          icon: Icons.play_circle_fill_rounded,
          onPressed: onStart,
        ),
      TaskStatus.running => MediaTaskListAction(
        tooltip: '暂停任务',
        icon: Icons.pause_rounded,
        onPressed: onPause,
      ),
      TaskStatus.paused => MediaTaskListAction(
        tooltip: '继续任务',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
      ),
      TaskStatus.completed => MediaTaskListAction(
        tooltip: '重来',
        icon: Icons.replay_rounded,
        onPressed: onRetry,
      ),
      TaskStatus.failed || TaskStatus.cancelled => MediaTaskListAction(
        tooltip: '重试任务',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
      TaskStatus.missingSource => MediaTaskListAction(
        tooltip: '重新链接源文件',
        icon: Icons.link_rounded,
        onPressed: onRelink,
      ),
      _ => null,
    };
  }
}

class MediaTaskIconButton extends StatelessWidget {
  const MediaTaskIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.tooltipsEnabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool tooltipsEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    final button = SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(icon, color: colors.iconMuted, size: 22),
      ),
    );

    if (!tooltipsEnabled) {
      return Semantics(label: tooltip, child: button);
    }

    return Tooltip(message: tooltip, child: button);
  }
}
