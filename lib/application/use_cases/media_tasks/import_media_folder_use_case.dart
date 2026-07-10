import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/services/input_runtime/media_folder_scanner.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/import_media_task_use_case.dart';
import 'package:framelean/application/use_cases/media_tasks/task_folder_use_cases.dart';
import 'package:framelean/domain/library.dart';
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

    final sourceFolderName = path.basename(folderPath.trim());
    final organized =
        await OrganizeImportedMediaBatchUseCase(
          mediaTaskRepository: mediaTaskRepository,
          taskFolderRepository: taskFolderRepository,
        ).call(
          taskIds: createdTasks.map((task) => task.id).toList(),
          sourceFolderName: sourceFolderName.isEmpty
              ? '导入文件夹'
              : sourceFolderName,
        );

    return ImportMediaFolderResult(
      createdTasks: createdTasks,
      createdFolders: organized.folders,
      failures: failures,
      unsupportedFileCount: scanResult.unsupportedFileCount,
    );
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
