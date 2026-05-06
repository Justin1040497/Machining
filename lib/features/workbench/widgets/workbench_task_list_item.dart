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
    this.onRemove,
    this.onSecondaryTapDown,
  });

  bool get canDrag => task.status != TaskStatus.running;

  bool get hasProgressBackground =>
      task.status == TaskStatus.running && task.progress > 0;

  bool get canShowTaskAction {
    return switch (task.status) {
      TaskStatus.failed ||
      TaskStatus.cancelled ||
      TaskStatus.missingSource => true,
      TaskStatus.pending ||
      TaskStatus.paused ||
      TaskStatus.running => task.analysisResult != null,
      TaskStatus.completed => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5F8CFF)
                  : const Color(0xFFE3E3E3),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1F5F8CFF),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (hasProgressBackground) buildProgressBackground(),
              Row(
                children: [
                  if (canDrag) buildDragHandle() else SizedBox(width: 12),
                  buildThumbnail(),
                  const SizedBox(width: 12),
                  Expanded(child: buildTaskText()),
                  if (canShowTaskAction) buildTaskActionButton(),
                  IconButton(
                    tooltip: '移除任务',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF9A9A9A),
                      size: 18,
                    ),
                  ),
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
            color: Color(0xFFCBEAFF),
          ),
        ),
      ),
    );
  }

  Widget buildTaskActionButton() {
    final action = resolveTaskAction();

    return IconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      icon: Icon(action.icon, color: const Color(0xFF9A9A9A), size: 18),
    );
  }

  TaskAction resolveTaskAction() {
    return switch (task.status) {
      TaskStatus.running => TaskAction(
        tooltip: '暂停任务',
        icon: Icons.pause_rounded,
        onPressed: onPause,
      ),
      TaskStatus.completed ||
      TaskStatus.failed ||
      TaskStatus.cancelled ||
      TaskStatus.missingSource => TaskAction(
        tooltip: '重试任务',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
      _ => TaskAction(
        tooltip: '启动任务',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
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
        color: const Color(0xFFE8EFF4),
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            buildStatusBadge(),
            SizedBox(width: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 7),
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
            fontSize: 9,
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
          backgroundColor: Color(0xFF45C46B),
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
