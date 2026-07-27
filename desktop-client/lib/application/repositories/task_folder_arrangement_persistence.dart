import 'package:framelean/domain/library.dart';

abstract interface class TaskFolderArrangementPersistence {
  Future<void> apply({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
    required Set<String> deletedFolderIds,
  });
}
