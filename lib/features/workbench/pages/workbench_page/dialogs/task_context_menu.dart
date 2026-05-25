import 'package:flutter/material.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_models.dart';

Future<TaskContextMenuAction?> showWorkbenchTaskContextMenu({
  required BuildContext context,
  required MediaTask task,
  required Offset globalPosition,
}) {
  return showMenu<TaskContextMenuAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    items: [
      if (task.status == TaskStatus.missingSource)
        const PopupMenuItem(
          value: TaskContextMenuAction.relinkSource,
          child: Text('重新链接源文件'),
        ),
      const PopupMenuItem(
        value: TaskContextMenuAction.revealInFileManager,
        child: Text('打开文件所在位置'),
      ),
      const PopupMenuItem(
        value: TaskContextMenuAction.rename,
        child: Text('任务重命名'),
      ),
      const PopupMenuItem(
        value: TaskContextMenuAction.delete,
        child: Text('删除任务'),
      ),
    ],
  );
}
