import 'package:framelean/domain/entities/media_task.dart';

class MediaTaskSortOrderUpdate {
  const MediaTaskSortOrderUpdate({
    required this.taskId,
    required this.sortOrder,
  });

  final String taskId;
  final int sortOrder;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MediaTaskSortOrderUpdate &&
            runtimeType == other.runtimeType &&
            taskId == other.taskId &&
            sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => Object.hash(taskId, sortOrder);
}

/// 任务存储抽象
abstract class MediaTaskRepository {
  /// 读取当前全部任务
  Future<List<MediaTask>> loadAllTasks();

  /// 保存单个任务
  Future<void> saveTask(MediaTask task);

  /// 用一整批任务覆盖当前任务列表
  Future<void> replaceAllTasks(List<MediaTask> tasks);

  /// 只更新任务排序字段，避免排序操作覆盖运行中任务状态。
  Future<void> updateTaskSortOrders(List<MediaTaskSortOrderUpdate> updates);

  /// 按任务 ID 删除任务
  Future<void> deleteTaskById(String taskId);
}
