import 'package:machining/domain/entities/media_task.dart';

/// 任务存储抽象
abstract class MediaTaskRepository {
  /// 读取当前全部任务
  Future<List<MediaTask>> loadAllTasks();

  /// 保存单个任务
  Future<void> saveTask(MediaTask task);

  /// 用一整批任务覆盖当前任务列表
  Future<void> replaceAllTasks(List<MediaTask> tasks);

  /// 按任务 ID 删除任务
  Future<void> deleteTaskById(String taskId);
}
