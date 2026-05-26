import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';

typedef WorkbenchTaskPositionCallback =
    void Function(MediaTask task, Offset position);

class WorkbenchTaskListCard extends StatelessWidget {
  const WorkbenchTaskListCard({
    super.key,
    required this.taskList,
    required this.selectedTask,
    required this.thumbnailForTask,
    required this.onReorder,
    required this.onOpenTask,
    required this.onStart,
    required this.onPause,
    required this.onRemove,
    required this.onRetry,
    required this.onRelink,
    required this.onContextMenu,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final MediaTask? selectedTask;
  final ImageProvider? Function(MediaTask task) thumbnailForTask;
  final ReorderCallback onReorder;
  final ValueChanged<MediaTask> onOpenTask;
  final ValueChanged<MediaTask> onStart;
  final ValueChanged<MediaTask> onPause;
  final ValueChanged<MediaTask> onRemove;
  final ValueChanged<MediaTask> onRetry;
  final ValueChanged<MediaTask> onRelink;
  final WorkbenchTaskPositionCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(27, 31, 27, 0),
      child: taskList.when(
        loading: _buildLoading,
        error: (error, stackTrace) => _buildError(error),
        data: _buildList,
      ),
    );
  }

  Widget _buildList(List<MediaTask> tasks) {
    if (tasks.isEmpty) {
      return _buildEmpty();
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: tasks.length,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.02).animate(animation),
            child: child,
          ),
        );
      },
      itemBuilder: (context, index) {
        final task = tasks[index];

        return Padding(
          key: ValueKey(task.id),
          padding: EdgeInsets.only(bottom: index == tasks.length - 1 ? 0 : 13),
          child: MediaTaskListTile(
            task: task,
            selected: selectedTask?.id == task.id,
            thumbnail: thumbnailForTask(task),
            onTap: () => onOpenTask(task),
            onStart: () => onStart(task),
            onPause: () => onPause(task),
            onRemove: () => onRemove(task),
            onRetry: () => onRetry(task),
            onRelink: () => onRelink(task),
            onSecondaryTapDown: (details) {
              onContextMenu(task, details.globalPosition);
            },
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Text(
        '任务列表读取失败\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        '暂无任务\n点击左下角 + 添加视频',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12, height: 1.5),
      ),
    );
  }
}
