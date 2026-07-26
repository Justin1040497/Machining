import 'package:framelean/application/repositories/imported_media_batch_persistence.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_media_task_repository.dart';

final class DriftImportedMediaBatchPersistence
    implements ImportedMediaBatchPersistence {
  const DriftImportedMediaBatchPersistence(this.database);

  final AppDatabase database;

  @override
  Future<void> save({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
  }) {
    return database.transaction(() async {
      await database.batch((batch) {
        if (folders.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            database.taskFolderRows,
            folders.map((folder) => folder.toCompanion()).toList(),
          );
        }
        if (tasks.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            database.taskRows,
            tasks.map((task) => task.toCompanion()).toList(),
          );
        }
      });
    });
  }
}
