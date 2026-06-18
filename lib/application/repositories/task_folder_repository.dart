import 'package:framelean/domain/entities/task_folder.dart';

abstract class TaskFolderRepository {
  Future<List<TaskFolder>> loadAllFolders();

  Future<void> saveFolder(TaskFolder folder);

  Future<void> deleteFolderById(String folderId);
}
