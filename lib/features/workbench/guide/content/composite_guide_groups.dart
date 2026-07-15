import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';
import 'package:framelean/features/workbench/guide/content/import_group.dart';
import 'package:framelean/features/workbench/guide/content/start_all_group.dart';
import 'package:framelean/features/workbench/guide/content/task_operation_group.dart';
import 'package:framelean/features/workbench/guide/models/task_workspace_guide_layout.dart';

class EmptyQueueGuideGroup extends CompositeGuideGroup {
  EmptyQueueGuideGroup({super.key, required super.geometry})
    : super(
        groupId: 'empty-queue',
        children: [
          ImportGuideGroup(geometry: geometry),
          AddButtonArrowGroup(geometry: geometry),
        ],
      );
}

class TaskWorkspaceGuideGroup extends GuideContentGroup {
  const TaskWorkspaceGuideGroup({super.key, required super.geometry});

  @override
  String get id => 'task-workspace';

  @override
  Widget build(BuildContext context) {
    final layout = TaskWorkspaceGuideLayout.resolve(geometry);
    final taskPlacement = layout.taskOperation;
    final startPlacement = layout.startAll;
    if (startPlacement == null) {
      return const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: taskPlacement == null
              ? const SizedBox.shrink(
                  key: ValueKey('task-operation-guide-hidden'),
                )
              : TaskOperationGuideGroup(
                  key: const ValueKey('task-operation-guide-visible'),
                  geometry: geometry,
                  placement: taskPlacement,
                ),
        ),
        StartAllGuideGroup(geometry: geometry, placement: startPlacement),
      ],
    );
  }
}
