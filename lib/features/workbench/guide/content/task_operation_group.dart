import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';

class TaskOperationGuideGroup extends GuideContentGroup {
  const TaskOperationGuideGroup({super.key, required super.geometry});

  @override
  String get id => 'task-operation';

  @override
  Widget build(BuildContext context) {
    final lastTaskRect = geometry.lastTaskRect;
    if (lastTaskRect == null) {
      return const SizedBox.shrink();
    }
    const textWidth = 228.0;
    final textLeft = (lastTaskRect.left + 36)
        .clamp(32.0, geometry.workbenchSize.width - textWidth - 32)
        .toDouble();
    final textTop = lastTaskRect.bottom + 24;
    final arrowStart = Offset(textLeft + textWidth + 8, textTop + 17);
    final arrowTarget = Offset(
      lastTaskRect.right - 24,
      lastTaskRect.bottom + 10,
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DoodleArrow(
            key: const ValueKey('task-operation-guide-arrow'),
            startPoint: arrowStart,
            targetPoint: arrowTarget,
            color: color,
            seed: 1401,
          ),
        ),
        Positioned(
          key: const ValueKey('task-operation-guide-text'),
          left: textLeft,
          top: textTop,
          width: textWidth,
          child: const GuideText(text: '这里可以操作任务，\n点击任务块可以打开配置'),
        ),
      ],
    );
  }
}
