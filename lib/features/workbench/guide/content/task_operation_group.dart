import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';
import 'package:framelean/features/workbench/guide/models/task_workspace_guide_layout.dart';

class TaskOperationGuideGroup extends GuideContentGroup {
  const TaskOperationGuideGroup({
    super.key,
    required super.geometry,
    required this.placement,
  });

  final TaskOperationGuidePlacement placement;

  @override
  String get id => 'task-operation';

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.42);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DoodleArrow(
            key: const ValueKey('task-operation-guide-arrow'),
            startPoint: placement.arrowStart,
            targetPoint: placement.arrowTarget,
            color: color,
            seed: TaskOperationGuidePlacement.arrowSeed,
            maxLength: TaskOperationGuidePlacement.maxArrowLength,
            curveBias: TaskOperationGuidePlacement.curveBias,
            targetDirection: TaskOperationGuidePlacement.targetDirection,
            clipRect: placement.lane,
          ),
        ),
        Positioned(
          key: const ValueKey('task-operation-guide-text'),
          left: placement.textRect.left,
          top: placement.textRect.top,
          width: placement.textRect.width,
          child: const GuideText(
            text: '这里可以操作任务\n点击任务块可以打开配置',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
