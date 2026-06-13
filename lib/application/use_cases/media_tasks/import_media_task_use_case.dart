import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:path/path.dart' as path;

class ImportMediaTaskUseCase {
  final MediaTaskRepository repository;
  final MediaKindResolver mediaKindResolver;
  final SourceFileFingerprintReader fingerprintReader;
  final AppSettingsRepository settingsRepository;
  final DateTime Function() now;

  const ImportMediaTaskUseCase({
    required this.repository,
    required this.mediaKindResolver,
    required this.fingerprintReader,
    required this.settingsRepository,
    required this.now,
  });

  Future<MediaTask> call(String inputPath) async {
    final tasks = await repository.loadAllTasks();
    final mediaKind = mediaKindResolver.resolve(inputPath);
    ensureSupportedImportedMediaKind(mediaKind);
    final fingerprint = await fingerprintReader.read(inputPath);
    final fileName = path.basename(inputPath);
    final settings = await settingsRepository.loadSettings();
    final version = processingVersionForTask(
      tasks: tasks,
      inputPath: inputPath,
      mediaKind: mediaKind,
      purpose: TaskPurpose.compression,
    );
    final initialConfig = buildInitialTaskConfigFromSettings(
      sourceFileName: fileName,
      mediaKind: mediaKind,
      settings: settings,
      now: now(),
      version: version,
    );

    final task =
        MediaTask.draft(
              inputPath: inputPath,
              fileName: fileName,
              mediaKind: mediaKind,
              sortOrder: nextMediaTaskSortOrder(tasks),
              config: initialConfig,
            )
            .withSourceFileFingerprint(fingerprint)
            .copyWith(status: TaskStatus.analyzing);

    await repository.saveTask(task);
    return task;
  }
}
