import 'package:framelean/application/repositories/task_folder_arrangement_persistence.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_media_task_repository.dart';

final class DriftTaskFolderArrangementPersistence
    implements TaskFolderArrangementPersistence {
  const DriftTaskFolderArrangementPersistence(this.database);

  final AppDatabase database;

  @override
  Future<void> apply({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
    required Set<String> deletedFolderIds,
  }) {
    return database.transaction(() async {
      await database.batch((batch) {
        if (tasks.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            database.taskRows,
            tasks.map((task) => task.toCompanion()).toList(),
          );
        }
        if (folders.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            database.taskFolderRows,
            folders.map((folder) => folder.toCompanion()).toList(),
          );
        }
      });
      for (final folderId in deletedFolderIds) {
        await (database.delete(
          database.taskFolderRows,
        )..where((table) => table.id.equals(folderId))).go();
      }
    });
  }
}
