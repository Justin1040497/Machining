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
    final arrowTarget = Offset(
      lastTaskRect.right - 42,
      lastTaskRect.bottom + 30,
    );
    final arrowStart = Offset(arrowTarget.dx - 250, lastTaskRect.bottom + 48);
    // 只允许绘制在最后一个任务底部以下，作为最后一层安全保护。
    final arrowClipRect = Rect.fromLTRB(
      geometry.listViewportRect.left,
      lastTaskRect.bottom + 16,
      geometry.listViewportRect.right,
      geometry.listViewportRect.bottom,
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
            maxLength: 270,
            curveBias: const Offset(0, 24),
            clipRect: arrowClipRect,
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
