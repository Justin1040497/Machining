import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/input_runtime/media_folder_scanner.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/import_media_folder_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';

void main() {
  test(
    'folder import creates a normal task when one media file is found',
    () async {
      final mediaTasks = _FakeMediaTaskRepository();
      final folders = _FakeTaskFolderRepository();
      final useCase = _createUseCase(
        mediaTasks: mediaTasks,
        folders: folders,
        scanner: const _FakeFolderScanner(mediaFilePaths: ['/素材/clip.mp4']),
      );

      final result = await useCase.call(folderPath: '/素材', scanDepth: 2);

      expect(result.createdTasks, hasLength(1));
      expect(result.createdFolders, isEmpty);
      expect((await mediaTasks.loadAllTasks()).single.folderId, isNull);
    },
  );

  test('folder import keeps singleton media kinds as normal tasks', () async {
    final mediaTasks = _FakeMediaTaskRepository();
    final folders = _FakeTaskFolderRepository();
    final useCase = _createUseCase(
      mediaTasks: mediaTasks,
      folders: folders,
      scanner: const _FakeFolderScanner(
        mediaFilePaths: [
          '/素材/旅行素材/clip.mp4',
          '/素材/旅行素材/still.jpg',
          '/素材/旅行素材/audio.mp3',
        ],
      ),
    );

    final result = await useCase.call(folderPath: '/素材/旅行素材', scanDepth: 2);

    expect(result.createdTasks, hasLength(3));
    expect(result.createdFolders, isEmpty);

    final storedTasks = await mediaTasks.loadAllTasks();
    expect(storedTasks.every((task) => task.folderId == null), isTrue);
  });

  test(
    'folder import groups only media kinds with at least two files',
    () async {
      final mediaTasks = _FakeMediaTaskRepository();
      final folders = _FakeTaskFolderRepository();
      final useCase = _createUseCase(
        mediaTasks: mediaTasks,
        folders: folders,
        scanner: const _FakeFolderScanner(
          mediaFilePaths: [
            '/素材/旅行素材/clip.mp4',
            '/素材/旅行素材/first.mp3',
            '/素材/旅行素材/second.wav',
            '/素材/旅行素材/first.jpg',
            '/素材/旅行素材/second.png',
          ],
        ),
      );

      final result = await useCase.call(folderPath: '/素材/旅行素材', scanDepth: 2);

      expect(result.createdFolders.map((folder) => folder.name), [
        '旅行素材 - 音频',
        '旅行素材 - 图片',
      ]);
      final storedTasks = await mediaTasks.loadAllTasks();
      expect(
        storedTasks
            .singleWhere((task) => task.mediaKind == MediaKind.video)
            .folderId,
        isNull,
      );
      expect(
        storedTasks
            .where((task) => task.mediaKind != MediaKind.video)
            .every((task) => task.folderId != null),
        isTrue,
      );
    },
  );

  test(
    'folder import keeps one image loose and groups video and audio',
    () async {
      final mediaTasks = _FakeMediaTaskRepository();
      final folders = _FakeTaskFolderRepository();
      final useCase = _createUseCase(
        mediaTasks: mediaTasks,
        folders: folders,
        scanner: const _FakeFolderScanner(
          mediaFilePaths: [
            '/素材/cover.jpg',
            '/素材/a.mp4',
            '/素材/b.mov',
            '/素材/a.mp3',
            '/素材/b.wav',
            '/素材/c.flac',
            '/素材/d.aac',
          ],
        ),
      );

      final result = await useCase.call(folderPath: '/素材', scanDepth: 2);

      expect(result.createdFolders.map((folder) => folder.mediaKind), [
        MediaKind.video,
        MediaKind.audio,
      ]);
      final storedTasks = await mediaTasks.loadAllTasks();
      expect(
        storedTasks
            .singleWhere((task) => task.mediaKind == MediaKind.image)
            .folderId,
        isNull,
      );
    },
  );

  test('folder import appends an index when folder names conflict', () async {
    final mediaTasks = _FakeMediaTaskRepository();
    final folders = _FakeTaskFolderRepository([
      TaskFolder.create(
        name: '旅行素材 - 视频',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialVideo(),
      ),
    ]);
    final useCase = _createUseCase(
      mediaTasks: mediaTasks,
      folders: folders,
      scanner: const _FakeFolderScanner(
        mediaFilePaths: ['/素材/旅行素材/a.mp4', '/素材/旅行素材/b.mov'],
      ),
    );

    final result = await useCase.call(folderPath: '/素材/旅行素材', scanDepth: 2);

    expect(result.createdFolders.single.name, '旅行素材 - 视频 2');
  });
}

ImportMediaFolderUseCase _createUseCase({
  required _FakeMediaTaskRepository mediaTasks,
  required _FakeTaskFolderRepository folders,
  required MediaFolderScanner scanner,
}) {
  return ImportMediaFolderUseCase(
    mediaTaskRepository: mediaTasks,
    taskFolderRepository: folders,
    mediaKindResolver: FileExtensionMediaKindResolver(),
    fingerprintReader: const _FakeFingerprintReader(),
    settingsRepository: _FakeSettingsRepository(),
    folderScanner: scanner,
    now: () => DateTime.fromMillisecondsSinceEpoch(1),
  );
}

class _FakeFolderScanner implements MediaFolderScanner {
  const _FakeFolderScanner({required this.mediaFilePaths});

  final List<String> mediaFilePaths;

  @override
  Future<MediaFolderScanResult> scan({
    required String rootDirectory,
    required int maxDepth,
  }) async {
    return MediaFolderScanResult(
      mediaFilePaths: mediaFilePaths,
      issues: const [],
      unsupportedFileCount: 0,
    );
  }
}

class _FakeFingerprintReader implements SourceFileFingerprintReader {
  const _FakeFingerprintReader();

  @override
  Future<SourceFileFingerprint> read(String inputPath) async {
    return const SourceFileFingerprint(fileSize: 1024, lastModifiedAt: 1);
  }
}

class _FakeSettingsRepository implements AppSettingsRepository {
  AppSettings settings = AppSettings.initial();

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}

class _FakeMediaTaskRepository implements MediaTaskRepository {
  _FakeMediaTaskRepository([List<MediaTask>? tasks]) : _tasks = tasks ?? [];

  List<MediaTask> _tasks;

  @override
  Future<List<MediaTask>> loadAllTasks() async => List.of(_tasks)
    ..sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) {
        return order;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

  @override
  Future<void> saveTask(MediaTask task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      _tasks = [..._tasks, task];
      return;
    }
    _tasks = [..._tasks.take(index), task, ..._tasks.skip(index + 1)];
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    _tasks = List.of(tasks);
  }

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final task = _tasks.firstWhere((task) => task.id == update.taskId);
      await saveTask(task.copyWith(sortOrder: update.sortOrder));
    }
  }

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final task = _tasks.firstWhere((task) => task.id == update.taskId);
      await saveTask(task.copyWith(folderSortOrder: update.folderSortOrder));
    }
  }

  @override
  Future<void> deleteTaskById(String taskId) async {
    _tasks = _tasks.where((task) => task.id != taskId).toList();
  }

  @override
  Future<MediaTask?> loadTaskById(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return null;
    }
    return _tasks[index];
  }

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    final idSet = taskIds.toSet();
    return _tasks.where((task) => idSet.contains(task.id)).toList();
  }

  @override
  Future<void> insertTasks(List<MediaTask> newTasks) async {
    for (final task in newTasks) {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index == -1) {
        _tasks = [..._tasks, task];
      } else {
        _tasks = [..._tasks.take(index), task, ..._tasks.skip(index + 1)];
      }
    }
  }
}

class _FakeTaskFolderRepository implements TaskFolderRepository {
  _FakeTaskFolderRepository([List<TaskFolder>? folders])
    : _folders = folders ?? [];

  List<TaskFolder> _folders;

  @override
  Future<List<TaskFolder>> loadAllFolders() async =>
      List.of(_folders)..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) {
          return order;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

  @override
  Future<void> saveFolder(TaskFolder folder) async {
    final index = _folders.indexWhere((item) => item.id == folder.id);
    if (index == -1) {
      _folders = [..._folders, folder];
      return;
    }
    _folders = [..._folders.take(index), folder, ..._folders.skip(index + 1)];
  }

  @override
  Future<void> updateFolderSortOrders(
    List<TaskFolderSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final folder = _folders.firstWhere(
        (folder) => folder.id == update.folderId,
      );
      await saveFolder(folder.copyWith(sortOrder: update.sortOrder));
    }
  }

  @override
  Future<void> deleteFolderById(String folderId) async {
    _folders = _folders.where((folder) => folder.id != folderId).toList();
  }

  @override
  Future<void> clearAllFolders() async {
    _folders = [];
  }
}
