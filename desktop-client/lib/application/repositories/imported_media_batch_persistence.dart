import 'package:framelean/domain/library.dart';

/// Persists a newly organized import batch as one local transaction.
abstract interface class ImportedMediaBatchPersistence {
  Future<void> save({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
  });
}
