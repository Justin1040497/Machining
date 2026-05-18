import 'package:flutter/material.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/task_status.dart';

class WorkbenchTaskListItem extends StatelessWidget {
  final MediaTask task;
  final bool selected;
  final int? reorderIndex;
  final ImageProvider? thumbnail;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onRetry;
  final VoidCallback? onRelink;
  final VoidCallback? onRemove;
  final GestureTapDownCallback? onSecondaryTapDown;

  const WorkbenchTaskListItem({
    super.key,
    required this.task,
    this.selected = false,
    this.reorderIndex,
    this.thumbnail,
    this.onTap,
    this.onStart,
    this.onPause,
    this.onRetry,
    this.onRelink,
    this.onRemove,
    this.onSecondaryTapDown,
  });

  bool get canDrag => task.status != TaskStatus.running;

  bool get hasProgressBackground =>
      task.status == TaskStatus.running && task.progress > 0;

  bool get canShowTaskAction => true;

  @override
  Widget build(BuildContext context) {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFDBDBDB)
                  : const Color(0xFFE3E3E3),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (hasProgressBackground) buildProgressBackground(),
              Row(
                children: [
                  const SizedBox(width: 14),
                  buildThumbnail(),
                  const SizedBox(width: 12),
                  Expanded(child: buildTaskText()),
                  if (canShowTaskAction) buildTaskActionButton(),
                  const SizedBox(width: 4),
                  buildTaskIconButton(
                    tooltip: '移除任务',
                    onPressed: onRemove,
                    icon: Icons.close_rounded,
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

  Widget buildProgressBackground() {
    final progress = task.progress.clamp(0, 1).toDouble();

    return Positioned.fill(
      child: AnimatedFractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        duration: Duration(milliseconds: 500),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: Color(0xFFEAF2FF),
          ),
        ),
      ),
    );
  }

  Widget buildTaskActionButton() {
    final action = resolveTaskAction();

    return buildTaskIconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      icon: action.icon,
    );
  }

  Widget buildTaskIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          splashRadius: 18,
          icon: Icon(icon, color: const Color(0xFF9A9A9A), size: 22),
        ),
      ),
    );
  }

  TaskAction resolveTaskAction() {
    return switch (task.status) {
      TaskStatus.running => TaskAction(
        tooltip: '暂停任务',
        icon: Icons.pause_rounded,
        onPressed: onPause,
      ),
      TaskStatus.paused => TaskAction(
        tooltip: '继续任务',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
      ),
      TaskStatus.missingSource => TaskAction(
        tooltip: '重新链接源文件',
        icon: Icons.link_rounded,
        onPressed: onRelink,
      ),
      _ => TaskAction(
        tooltip: '重试任务',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    };
  }

  Widget buildDragHandle() {
    final handle = MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Tooltip(
        message: '长按拖动排序',
        waitDuration: const Duration(milliseconds: 500),
        child: SizedBox(
          width: 28,
          height: 60,
          child: Center(
            child: Icon(
              Icons.drag_indicator_rounded,
              color: Color(0xFFCFCFCF),
              size: 18,
            ),
          ),
        ),
      ),
    );
    final index = reorderIndex;
    if (index == null) {
      return handle;
    }

    return ReorderableDragStartListener(index: index, child: handle);
  }

  Widget buildThumbnail() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFFE7EEF5),
        image: thumbnail == null
            ? null
            : DecorationImage(image: thumbnail!, fit: BoxFit.cover),
      ),
      child: thumbnail == null
          ? const Icon(
              Icons.movie_creation_outlined,
              size: 18,
              color: Color(0xFF7D8B95),
            )
          : null,
    );
  }

  Widget buildTaskText() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: task.fileName,
          waitDuration: const Duration(milliseconds: 500),
          child: Text(
            task.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            buildStatusBadge(),
            SizedBox(width: 10),
            Text(
              formatBytes(task.sourceFileFingerprint?.fileSize),
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildStatusBadge() {
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

  TaskStatusStyle resolveStatusStyle(MediaTask task) {
    switch (task.status) {
      case TaskStatus.running:
        return TaskStatusStyle(
          label: '运行中 ${(task.progress * 100).round()}%',
          backgroundColor: const Color(0xFFFF7A00),
          foregroundColor: Colors.white,
        );
      case TaskStatus.pending:
        return const TaskStatusStyle(
          label: '等待中',
          backgroundColor: Color(0xFFE9D900),
          foregroundColor: Colors.white,
        );
      case TaskStatus.completed:
        return const TaskStatusStyle(
          label: '已完成',
          backgroundColor: Color(0xFFD7D7D7),
          foregroundColor: Colors.white,
        );
      case TaskStatus.failed:
        return const TaskStatusStyle(
          label: '失败',
          backgroundColor: Color(0xFFFF6B73),
          foregroundColor: Colors.white,
        );
      case TaskStatus.cancelled:
        return const TaskStatusStyle(
          label: '已取消',
          backgroundColor: Color(0xFFD7D7D7),
          foregroundColor: Colors.white,
        );
      case TaskStatus.missingSource:
        return const TaskStatusStyle(
          label: '找不到源文件',
          backgroundColor: Color(0xFFD7D7D7),
          foregroundColor: Colors.white,
        );
      case TaskStatus.analyzing:
        return const TaskStatusStyle(
          label: '分析中',
          backgroundColor: Color(0xFF74A2FF),
          foregroundColor: Colors.white,
        );
      case TaskStatus.paused:
        return const TaskStatusStyle(
          label: '暂停中',
          backgroundColor: Color(0xFFFFA6AF),
          foregroundColor: Colors.white,
        );
    }
  }

  String formatBytes(int? bytes) {
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

class TaskStatusStyle {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const TaskStatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}

class TaskAction {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const TaskAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
}
