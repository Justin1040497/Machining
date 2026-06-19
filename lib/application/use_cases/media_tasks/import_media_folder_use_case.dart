import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/input_runtime/media_folder_scanner.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/import_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/place_workbench_top_level_item_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/task_folder_use_cases.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:path/path.dart' as path;

class ImportMediaFolderFailure {
  const ImportMediaFolderFailure({required this.path, required this.reason});

  final String path;
  final String reason;
}

class ImportMediaFolderResult {
  const ImportMediaFolderResult({
    required this.createdTasks,
    required this.createdFolders,
    required this.failures,
    required this.unsupportedFileCount,
  });

  final List<MediaTask> createdTasks;
  final List<TaskFolder> createdFolders;
  final List<ImportMediaFolderFailure> failures;
  final int unsupportedFileCount;

  bool get foundNoMedia => createdTasks.isEmpty && failures.isEmpty;
}

class ImportMediaFolderUseCase {
  const ImportMediaFolderUseCase({
    required this.mediaTaskRepository,
    required this.taskFolderRepository,
    required this.mediaKindResolver,
    required this.fingerprintReader,
    required this.settingsRepository,
    required this.folderScanner,
    required this.now,
  });

  final MediaTaskRepository mediaTaskRepository;
  final TaskFolderRepository taskFolderRepository;
  final MediaKindResolver mediaKindResolver;
  final SourceFileFingerprintReader fingerprintReader;
  final AppSettingsRepository settingsRepository;
  final MediaFolderScanner folderScanner;
  final DateTime Function() now;

  Future<ImportMediaFolderResult> call({
    required String folderPath,
    required int scanDepth,
  }) async {
    final scanResult = await folderScanner.scan(
      rootDirectory: folderPath,
      maxDepth: scanDepth,
    );
    final failures = [
      for (final issue in scanResult.issues)
        ImportMediaFolderFailure(path: issue.path, reason: issue.reason),
    ];
    final createdTasks = <MediaTask>[];

    final importer = ImportMediaTaskUseCase(
      repository: mediaTaskRepository,
      mediaKindResolver: mediaKindResolver,
      fingerprintReader: fingerprintReader,
      settingsRepository: settingsRepository,
      now: now,
    );
    for (final inputPath in scanResult.mediaFilePaths) {
      try {
        createdTasks.add(await importer.call(inputPath));
      } on Object catch (error) {
        failures.add(
          ImportMediaFolderFailure(
            path: inputPath,
            reason: _formatImportFailureReason(error),
          ),
        );
      }
    }

    if (createdTasks.length == 1) {
      await PlaceWorkbenchTopLevelItemUseCase(
        mediaTaskRepository: mediaTaskRepository,
        taskFolderRepository: taskFolderRepository,
      ).call(WorkbenchInsertedItem.task(createdTasks.single.id));
      return ImportMediaFolderResult(
        createdTasks: createdTasks,
        createdFolders: const [],
        failures: failures,
        unsupportedFileCount: scanResult.unsupportedFileCount,
      );
    }

    final createdFolders = <TaskFolder>[];
    if (createdTasks.length > 1) {
      final tasksByKind = <MediaKind, List<MediaTask>>{};
      for (final task in createdTasks) {
        tasksByKind.putIfAbsent(task.mediaKind, () => []).add(task);
      }
      final baseName = path.basename(folderPath.trim());
      for (final entry in tasksByKind.entries) {
        final folderResult =
            await CreateTaskFolderFromTasksUseCase(
              mediaTaskRepository: mediaTaskRepository,
              taskFolderRepository: taskFolderRepository,
            ).call(
              taskIds: entry.value.map((task) => task.id).toList(),
              name:
                  '${baseName.isEmpty ? '导入文件夹' : baseName} - '
                  '${_mediaKindLabel(entry.key)}',
            );
        createdFolders.add(folderResult.folder);
      }
    }

    return ImportMediaFolderResult(
      createdTasks: createdTasks,
      createdFolders: createdFolders,
      failures: failures,
      unsupportedFileCount: scanResult.unsupportedFileCount,
    );
  }

  String _mediaKindLabel(MediaKind mediaKind) {
    return switch (mediaKind) {
      MediaKind.video => '视频',
      MediaKind.image => '图片',
      MediaKind.audio => '音频',
    };
  }

  String _formatImportFailureReason(Object error) {
    const stateErrorPrefix = 'Bad state: ';
    final message = error.toString();
    if (message.startsWith(stateErrorPrefix)) {
      return message.substring(stateErrorPrefix.length);
    }
    return message;
  }
}
