import 'package:framelean/domain/library.dart';

/// Flattens the Client-only folder model into independent engine task ids.
final class TaskFolderQueueProjection {
  const TaskFolderQueueProjection();

  List<String> orderedTaskIds(List<MediaTask> tasks, List<TaskFolder> folders) {
    final folderTasks = <String, List<MediaTask>>{};
    for (final task in tasks) {
      final folderId = task.folderId;
      if (folderId != null) {
        folderTasks.putIfAbsent(folderId, () => <MediaTask>[]).add(task);
      }
    }
    for (final children in folderTasks.values) {
      children.sort(_compareFolderTasks);
    }

    final topLevel = <_TopLevelItem>[
      for (final folder in folders)
        _TopLevelItem(
          sortOrder: folder.sortOrder,
          createdAt: folder.createdAt,
          taskIds:
              folderTasks[folder.id]
                  ?.map((task) => task.id)
                  .toList(growable: false) ??
              const <String>[],
        ),
      for (final task in tasks.where((task) => task.folderId == null))
        _TopLevelItem(
          sortOrder: task.sortOrder,
          createdAt: task.createdAt,
          taskIds: <String>[task.id],
        ),
    ]..sort(_compareTopLevel);

    final seen = <String>{};
    return <String>[
      for (final item in topLevel)
        for (final taskId in item.taskIds)
          if (seen.add(taskId)) taskId,
    ];
  }
}

final class _TopLevelItem {
  const _TopLevelItem({
    required this.sortOrder,
    required this.createdAt,
    required this.taskIds,
  });

  final int sortOrder;
  final int createdAt;
  final List<String> taskIds;
}

int _compareTopLevel(_TopLevelItem left, _TopLevelItem right) {
  final order = left.sortOrder.compareTo(right.sortOrder);
  return order != 0 ? order : left.createdAt.compareTo(right.createdAt);
}

int _compareFolderTasks(MediaTask left, MediaTask right) {
  final order = (left.folderSortOrder ?? left.sortOrder).compareTo(
    right.folderSortOrder ?? right.sortOrder,
  );
  return order != 0 ? order : left.createdAt.compareTo(right.createdAt);
}
