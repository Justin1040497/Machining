import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as path;

class ImportMediaTasksUseCase {
  const ImportMediaTasksUseCase({
    required this.repository,
    required this.mediaKindResolver,
    required this.fingerprintReader,
    required this.settingsRepository,
    required this.now,
  });

  final MediaTaskRepository repository;
  final MediaKindResolver mediaKindResolver;
  final SourceFileFingerprintReader fingerprintReader;
  final AppSettingsRepository settingsRepository;
  final DateTime Function() now;

  Future<List<MediaTask>> call(
    Iterable<String> inputPaths, {
    bool skipUnsupported = false,
  }) async {
    final settings = await settingsRepository.loadSettings();
    final existingTasks = await repository.loadAllTasks();
    var currentSortOrder = nextMediaTaskSortOrder(existingTasks);
    final createdTasks = <MediaTask>[];
    final importedAt = now();

    for (final rawInputPath in inputPaths) {
      final inputPath = rawInputPath.trim();
      if (inputPath.isEmpty) {
        continue;
      }

      late final MediaKind mediaKind;
      try {
        mediaKind = mediaKindResolver.resolve(inputPath);
        ensureSupportedImportedMediaKind(mediaKind);
      } on Object {
        if (skipUnsupported) {
          continue;
        }
        rethrow;
      }

      final fingerprint = await fingerprintReader.read(inputPath);
      final fileName = path.basename(inputPath);
      final version = processingVersionForTask(
        tasks: existingTasks,
        inputPath: inputPath,
        mediaKind: mediaKind,
        purpose: TaskPurpose.compression,
      );
      final initialConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: fileName,
        mediaKind: mediaKind,
        settings: settings,
        now: importedAt,
        version: version,
      );
      final task = MediaTask.draft(
        inputPath: inputPath,
        fileName: fileName,
        mediaKind: mediaKind,
        sortOrder: currentSortOrder,
        config: initialConfig,
      ).withSourceFileFingerprint(fingerprint);

      createdTasks.add(task);
      existingTasks.add(task);
      currentSortOrder += 1;
    }

    if (createdTasks.isNotEmpty) {
      await repository.insertTasks(createdTasks);
    }
    return createdTasks;
  }
}
