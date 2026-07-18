import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/import_media_tasks_use_case.dart';
import 'package:framelean/domain/library.dart';

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
    final tasks = await ImportMediaTasksUseCase(
      repository: repository,
      mediaKindResolver: mediaKindResolver,
      fingerprintReader: fingerprintReader,
      settingsRepository: settingsRepository,
      now: now,
    ).call([inputPath]);
    if (tasks.isEmpty) {
      throw StateError('导入路径不能为空');
    }
    return tasks.single;
  }
}
