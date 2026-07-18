import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as path;

typedef TemporaryDirectoryFactory =
    Future<Directory> Function(MediaTask task, ProprietaryAudioFormat format);

class DefaultMediaInputPreparer implements MediaInputPreparer {
  final ProprietaryAudioFormatResolver proprietaryAudioFormatResolver;
  final ProprietaryAudioAdapterRegistry proprietaryAudioAdapterRegistry;
  final ProprietaryAudioDecoder proprietaryAudioDecoder;
  final TemporaryDirectoryFactory temporaryDirectoryFactory;

  DefaultMediaInputPreparer({
    required this.proprietaryAudioFormatResolver,
    required this.proprietaryAudioAdapterRegistry,
    required this.proprietaryAudioDecoder,
    TemporaryDirectoryFactory? temporaryDirectoryFactory,
  }) : temporaryDirectoryFactory =
           temporaryDirectoryFactory ?? createDefaultTemporaryDirectory;

  @override
  Future<PreparedMediaInput> prepare(
    MediaTask task, {
    required MediaInputPreparationPurpose purpose,
  }) async {
    final format = proprietaryAudioFormatResolver.resolve(task.inputPath);
    if (format == null) {
      return PreparedMediaInput(task: task);
    }

    final runtime = await proprietaryAudioAdapterRegistry.resolveRuntime(
      format,
    );
    final temporaryDirectory = await temporaryDirectoryFactory(task, format);
    final result = await proprietaryAudioDecoder.decode(
      runtime: runtime,
      inputPath: task.inputPath,
      temporaryDirectory: temporaryDirectory.path,
    );
    final preparedTask = task.copyWith(
      inputPath: result.decodedPath,
      config: purpose == MediaInputPreparationPurpose.execution
          ? task.config.copyWith(
              outputDirectory: task.config.outputDirectory.trim().isEmpty
                  ? path.dirname(task.inputPath)
                  : task.config.outputDirectory,
            )
          : task.config,
    );

    return PreparedMediaInput(
      task: preparedTask,
      proprietaryAudioDecodeResult: result,
    );
  }

  @override
  Future<void> cleanup(PreparedMediaInput preparedInput) async {
    final result = preparedInput.proprietaryAudioDecodeResult;
    if (result == null) {
      return;
    }

    for (final cleanupPath in result.cleanupPaths) {
      try {
        final type = await FileSystemEntity.type(cleanupPath);
        switch (type) {
          case FileSystemEntityType.directory:
            await Directory(cleanupPath).delete(recursive: true);
          case FileSystemEntityType.file:
            await File(cleanupPath).delete();
          case FileSystemEntityType.link:
            await Link(cleanupPath).delete();
          case FileSystemEntityType.pipe:
          case FileSystemEntityType.unixDomainSock:
          case FileSystemEntityType.notFound:
            break;
        }
      } on Object {
        // 临时文件清理是尽力而为，不应改变任务最终状态。
      }
    }
  }
}

Future<Directory> createDefaultTemporaryDirectory(
  MediaTask task,
  ProprietaryAudioFormat format,
) {
  final safeTaskId = task.id.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return Directory(
    path.join(
      Directory.systemTemp.path,
      tempDirPrefix,
      'audio-adapters',
      '${timestamp}_${format.adapterId}_$safeTaskId',
    ),
  ).create(recursive: true);
}
