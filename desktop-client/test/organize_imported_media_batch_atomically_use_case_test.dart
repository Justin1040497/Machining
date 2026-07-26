import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

void main() {
  test('organizes V1 A1 V2 I1 I2 and flattens without duplicates', () async {
    final imported = <MediaTask>[
      _task('V1', MediaKind.video, 0),
      _task('A1', MediaKind.audio, 1),
      _task('V2', MediaKind.video, 2),
      _task('I1', MediaKind.image, 3),
      _task('I2', MediaKind.image, 4),
    ];
    final tasks = _TaskRepository();
    final folders = _FolderRepository();
    final persistence = _Persistence();

    final result = await OrganizeImportedMediaBatchAtomicallyUseCase(
      mediaTaskRepository: tasks,
      taskFolderRepository: folders,
      persistence: persistence,
    ).call(imported);

    expect(persistence.calls, 1);
    expect(result.createdFolders.map((folder) => folder.mediaKind), [
      MediaKind.video,
      MediaKind.image,
    ]);
    final videoFolder = result.createdFolders.firstWhere(
      (folder) => folder.mediaKind == MediaKind.video,
    );
    final imageFolder = result.createdFolders.firstWhere(
      (folder) => folder.mediaKind == MediaKind.image,
    );
    expect(
      result.createdTasks
          .where((task) => task.folderId == videoFolder.id)
          .map((task) => task.id),
      ['V1', 'V2'],
    );
    expect(
      result.createdTasks
          .where((task) => task.folderId == imageFolder.id)
          .map((task) => task.id),
      ['I1', 'I2'],
    );
    expect(
      result.createdTasks.singleWhere((task) => task.id == 'A1').folderId,
      isNull,
    );
    expect(result.orderedImportedTaskIds, ['V1', 'V2', 'A1', 'I1', 'I2']);
    expect(result.orderedImportedTaskIds.toSet(), hasLength(5));
    expect(
      result.createdTasks.every(
        (task) => task.status == TaskStatus.awaitAnalysis,
      ),
      isTrue,
    );
  });
}

MediaTask _task(String id, MediaKind kind, int order) {
  return MediaTask.draft(
    inputPath: '/$id',
    fileName: id,
    mediaKind: kind,
    sortOrder: order,
  ).copyWith(id: id, createdAt: order);
}

final class _TaskRepository implements MediaTaskRepository {
  @override
  Future<List<MediaTask>> loadAllTasks() async => const <MediaTask>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FolderRepository implements TaskFolderRepository {
  @override
  Future<List<TaskFolder>> loadAllFolders() async => const <TaskFolder>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Persistence implements ImportedMediaBatchPersistence {
  int calls = 0;

  @override
  Future<void> save({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
  }) async {
    calls += 1;
  }
}
