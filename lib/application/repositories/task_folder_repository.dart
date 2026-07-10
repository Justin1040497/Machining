import 'package:framelean/domain/library.dart';

class TaskFolderSortOrderUpdate {
  const TaskFolderSortOrderUpdate({
    required this.folderId,
    required this.sortOrder,
  });

  final String folderId;
  final int sortOrder;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskFolderSortOrderUpdate &&
            runtimeType == other.runtimeType &&
            folderId == other.folderId &&
            sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => Object.hash(folderId, sortOrder);
}

abstract class TaskFolderRepository {
  Future<List<TaskFolder>> loadAllFolders();

  Future<void> saveFolder(TaskFolder folder);

  Future<void> updateFolderSortOrders(List<TaskFolderSortOrderUpdate> updates);

  Future<void> deleteFolderById(String folderId);

  Future<void> clearAllFolders();
}
