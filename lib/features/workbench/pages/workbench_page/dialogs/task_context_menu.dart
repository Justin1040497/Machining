import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';

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
        value: TaskContextMenuAction.showLog,
        child: Text('查看日志'),
      ),
      const PopupMenuItem(
        value: TaskContextMenuAction.delete,
        child: Text('删除任务'),
      ),
    ],
  );
}
