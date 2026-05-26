import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_item_models.dart';

class MediaTaskStatusBadge extends StatelessWidget {
  const MediaTaskStatusBadge({super.key, required this.task});

  final MediaTask task;

  @override
  Widget build(BuildContext context) {
    final style = resolveStatusStyle(task);

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
            fontSize: 8,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  MediaTaskStatusStyle resolveStatusStyle(MediaTask task) {
    switch (task.status) {
      case TaskStatus.running:
        return MediaTaskStatusStyle(
          label: '运行中 ${(task.progress * 100).round()}%',
          backgroundColor: const Color(0xFFFF7A00),
          foregroundColor: Colors.white,
        );
      case TaskStatus.pending:
        return const MediaTaskStatusStyle(
          label: '等待中',
          backgroundColor: Color(0xFFE9D900),
          foregroundColor: Colors.white,
        );
      case TaskStatus.completed:
        return const MediaTaskStatusStyle(
          label: '已完成',
          backgroundColor: Color(0xFFD7D7D7),
          foregroundColor: Colors.white,
        );
      case TaskStatus.failed:
        return const MediaTaskStatusStyle(
          label: '失败',
          backgroundColor: Color(0xFFFF6B73),
          foregroundColor: Colors.white,
        );
      case TaskStatus.cancelled:
        return const MediaTaskStatusStyle(
          label: '已取消',
          backgroundColor: Color(0xFFD7D7D7),
          foregroundColor: Colors.white,
        );
      case TaskStatus.missingSource:
        return const MediaTaskStatusStyle(
          label: '找不到源文件',
          backgroundColor: Color(0xFFD7D7D7),
          foregroundColor: Colors.white,
        );
      case TaskStatus.analyzing:
        return const MediaTaskStatusStyle(
          label: '分析中',
          backgroundColor: Color(0xFF74A2FF),
          foregroundColor: Colors.white,
        );
      case TaskStatus.paused:
        return const MediaTaskStatusStyle(
          label: '暂停中',
          backgroundColor: Color(0xFFFFA6AF),
          foregroundColor: Colors.white,
        );
    }
  }
}
