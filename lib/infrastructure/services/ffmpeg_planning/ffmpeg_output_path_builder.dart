import 'dart:io';

import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:path/path.dart' as path;

class FfmpegOutputPathBuilder {
  final bool Function(String outputPath) outputPathExists;

  FfmpegOutputPathBuilder({bool Function(String outputPath)? pathExists})
    : outputPathExists =
          pathExists ?? ((outputPath) => File(outputPath).existsSync());

  String buildOutputPath(MediaTask task) {
    final inputDirectory = path.dirname(task.inputPath);
    final outputDirectory = task.config.outputDirectory.trim().isEmpty
        ? inputDirectory
        : task.config.outputDirectory;
    final extension = extensionFor(task.config.outputFormat);
    final outputFileName = buildOutputFileName(task, extension);
    final baseOutputPath = path.join(outputDirectory, outputFileName);

    return uniqueOutputPath(baseOutputPath, task.inputPath);
  }

  String buildOutputFileName(MediaTask task, String extension) {
    final customName = task.config.outputFileName.trim();
    if (customName.isNotEmpty) {
      final safeName = path.basename(customName);
      final baseName = path.basenameWithoutExtension(safeName).trim();
      if (baseName.isNotEmpty) {
        return '$baseName$extension';
      }
    }

    final inputBaseName = path.basenameWithoutExtension(task.fileName);
    final suffix = switch (task.purpose) {
      TaskPurpose.compression => 'compressed',
      TaskPurpose.conversion => 'converted',
    };

    return '${inputBaseName}_$suffix$extension';
  }

  String uniqueOutputPath(String preferredPath, String inputPath) {
    if (!isUnsafeOutputPath(preferredPath, inputPath)) {
      return preferredPath;
    }

    final directory = path.dirname(preferredPath);
    final baseName = path.basenameWithoutExtension(preferredPath);
    final extension = path.extension(preferredPath);

    var index = 1;
    while (true) {
      final candidate = path.join(directory, '$baseName-$index$extension');
      if (!isUnsafeOutputPath(candidate, inputPath)) {
        return candidate;
      }
      index += 1;
    }
  }

  bool isUnsafeOutputPath(String outputPath, String inputPath) {
    return isSamePath(outputPath, inputPath) || outputPathExists(outputPath);
  }

  bool isSamePath(String first, String second) {
    return path.normalize(path.absolute(first)) ==
        path.normalize(path.absolute(second));
  }

  String extensionFor(OutputFormat outputFormat) {
    return FfmpegCommandFormatters.extensionFor(outputFormat);
  }
}
