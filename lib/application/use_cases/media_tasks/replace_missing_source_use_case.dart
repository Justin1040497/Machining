import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:path/path.dart' as path;

class ReplaceMissingSourceUseCase {
  final MediaTaskRepository repository;
  final MediaKindResolver mediaKindResolver;
  final SourceFileChecker sourceFileChecker;
  final SourceFileFingerprintReader fingerprintReader;

  const ReplaceMissingSourceUseCase({
    required this.repository,
    required this.mediaKindResolver,
    required this.sourceFileChecker,
    required this.fingerprintReader,
  });

  Future<MediaTask> call({
    required String taskId,
    required String newInputPath,
  }) async {
    final tasks = await repository.loadAllTasks();
    final task = findMediaTaskById(tasks, taskId);
    final mediaKind = mediaKindResolver.resolve(newInputPath);
    ensureSupportedImportedMediaKind(mediaKind);
    if (!await sourceFileChecker.exists(newInputPath)) {
      throw StateError('源文件不存在: $newInputPath');
    }

    final fingerprint = await fingerprintReader.read(newInputPath);
    final updatedTask = task
        .replaceInputFile(
          newInputPath: newInputPath,
          newFileName: path.basename(newInputPath),
          newMediaKind: mediaKind,
        )
        .withSourceFileFingerprint(fingerprint);

    await repository.saveTask(updatedTask);
    return updatedTask;
  }
}
