import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
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
  final VoidCallback? onRemove;
  final GestureTapDownCallback? onSecondaryTapDown;

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
    this.onRemove,
    this.onSecondaryTapDown,
  });

  bool get hasProgressBackground =>
      task.status == TaskStatus.running && task.progress > 0;

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
              if (hasProgressBackground) _buildProgressBackground(),
              Row(
                children: [
                  const SizedBox(width: 14),
                  MediaTaskThumbnail(thumbnail: thumbnail),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTaskText()),
                  MediaTaskActionButton(
                    task: task,
                    onStart: onStart,
                    onPause: onPause,
                    onRetry: onRetry,
                    onRelink: onRelink,
                  ),
                  const SizedBox(width: 4),
                  MediaTaskIconButton(
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

  Widget _buildProgressBackground() {
    final progress = task.progress.clamp(0, 1).toDouble();

    return Positioned.fill(
      child: AnimatedFractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        duration: const Duration(milliseconds: 500),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: const Color(0xFFEAF2FF),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskText() {
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
            MediaTaskStatusBadge(task: task),
            const SizedBox(width: 10),
            Text(
              _formatBytes(task.sourceFileFingerprint?.fileSize),
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
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
