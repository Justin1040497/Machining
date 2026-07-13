import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_item_models.dart';

class MediaTaskStatusBadge extends StatelessWidget {
  const MediaTaskStatusBadge({super.key, required this.task});

  final MediaTask task;

  @override
  Widget build(BuildContext context) {
    final style = resolveStatusStyle(context, task);

    /// 自适应
    return UnconstrainedBox(
      child: Container(
        height: 15,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          style.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: style.foregroundColor,
            fontSize: 8.flSp,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  MediaTaskStatusStyle resolveStatusStyle(
    BuildContext context,
    MediaTask task,
  ) {
    final colors = context.frameLeanColors;

    switch (task.status) {
      case TaskStatus.awaitingAnalysis:
        return MediaTaskStatusStyle(
          label: '等待分析',
          backgroundColor: colors.statusPending,
          foregroundColor: colors.onWarning,
        );
      case TaskStatus.running:
        return MediaTaskStatusStyle(
          label: '运行中 ${(task.progress * 100).round()}%',
          backgroundColor: colors.statusRunning,
          foregroundColor: colors.onWarning,
        );
      case TaskStatus.pending:
        return MediaTaskStatusStyle(
          label: '等待开始',
          backgroundColor: colors.statusPending,
          foregroundColor: colors.onWarning,
        );
      case TaskStatus.completed:
        return MediaTaskStatusStyle(
          label: '已完成',
          backgroundColor: colors.progress,
          foregroundColor: colors.primary,
        );
      case TaskStatus.failed:
        return MediaTaskStatusStyle(
          label: '失败',
          backgroundColor: colors.statusFailed,
          foregroundColor: colors.onDanger,
        );
      case TaskStatus.cancelled:
        return MediaTaskStatusStyle(
          label: '已取消',
          backgroundColor: colors.statusCancelled,
          foregroundColor: colors.textPrimary,
        );
      case TaskStatus.missingSource:
        return MediaTaskStatusStyle(
          label: '找不到源文件',
          backgroundColor: colors.statusMissingSource,
          foregroundColor: colors.onPrimary,
        );
      case TaskStatus.analyzing:
        return MediaTaskStatusStyle(
          label: '分析中',
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        );
      case TaskStatus.paused:
        return MediaTaskStatusStyle(
          label: '暂停中',
          backgroundColor: colors.runningSoft,
          foregroundColor: colors.statusRunning,
        );
    }
  }
}
