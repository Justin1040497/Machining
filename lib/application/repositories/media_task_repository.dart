import 'package:framelean/domain/library.dart';

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

class MediaTaskFolderSortOrderUpdate {
  const MediaTaskFolderSortOrderUpdate({
    required this.taskId,
    required this.folderSortOrder,
  });

  final String taskId;
  final int folderSortOrder;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MediaTaskFolderSortOrderUpdate &&
            runtimeType == other.runtimeType &&
            taskId == other.taskId &&
            folderSortOrder == other.folderSortOrder;
  }

  @override
  int get hashCode => Object.hash(taskId, folderSortOrder);
}

/// 任务存储抽象
abstract class MediaTaskRepository {
  /// 读取当前全部任务
  Future<List<MediaTask>> loadAllTasks();

  /// 按 ID 读取单个任务，不存在时返回 null
  Future<MediaTask?> loadTaskById(String taskId);

  /// 按一组 ID 批量读取任务
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds);

  /// 保存单个任务
  Future<void> saveTask(MediaTask task);

  /// 批量插入新任务（单事务内完成），已存在的 ID 将被覆盖
  Future<void> insertTasks(List<MediaTask> tasks);

  /// 用一整批任务覆盖当前任务列表
  Future<void> replaceAllTasks(List<MediaTask> tasks);

  /// 只更新任务排序字段，避免排序操作覆盖运行中任务状态。
  Future<void> updateTaskSortOrders(List<MediaTaskSortOrderUpdate> updates);

  /// 只更新夹内任务排序字段，避免排序操作覆盖运行中任务状态。
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  );

  /// 按任务 ID 删除任务
  Future<void> deleteTaskById(String taskId);
}
