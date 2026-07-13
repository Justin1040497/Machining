import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';
import 'package:framelean/features/workbench/guide/content/import_group.dart';
import 'package:framelean/features/workbench/guide/content/start_all_group.dart';
import 'package:framelean/features/workbench/guide/content/task_operation_group.dart';

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

class TaskWorkspaceGuideGroup extends CompositeGuideGroup {
  TaskWorkspaceGuideGroup({super.key, required super.geometry})
    : super(
        groupId: 'task-workspace',
        children: [
          TaskOperationGuideGroup(geometry: geometry),
          StartAllGuideGroup(geometry: geometry),
        ],
      );
}
