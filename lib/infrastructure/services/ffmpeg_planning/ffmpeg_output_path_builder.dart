import 'dart:io';

import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:path/path.dart' as path;

class FfmpegOutputPathBuilder {
  final bool Function(String outputPath) outputPathExists;
  final bool caseInsensitiveFileSystem;

  FfmpegOutputPathBuilder({
    bool Function(String outputPath)? pathExists,
    bool? caseInsensitiveFileSystem,
  }) : caseInsensitiveFileSystem =
           caseInsensitiveFileSystem ??
           (Platform.isMacOS || Platform.isWindows),
       outputPathExists =
           pathExists ?? ((outputPath) => File(outputPath).existsSync());

  String buildOutputPath(MediaTask task) {
    final inputDirectory = path.dirname(task.inputPath);
    final outputDirectory = task.config.outputDirectory.trim().isEmpty
        ? inputDirectory
        : task.config.outputDirectory;
    final extension = extensionForMedia(mediaOutputFormatFor(task));
    final outputFileName = buildOutputFileName(task, extension);
    final baseOutputPath = path.join(outputDirectory, outputFileName);

    return uniqueOutputPath(baseOutputPath, task.inputPath);
  }

  String buildOutputFileName(MediaTask task, String extension) {
    final customName = task.config.outputFileName.trim();
    if (customName.isNotEmpty) {
      final safeName = path.basename(customName);
      final baseName = outputFileNameStem(safeName, extension);
      if (baseName.isNotEmpty) {
        return '$baseName$extension';
      }
    }

    final inputBaseName = path.basenameWithoutExtension(task.inputPath);
    final suffix = switch (task.purpose) {
      TaskPurpose.compression => 'compressed',
      TaskPurpose.conversion => 'converted',
    };

    return '${inputBaseName}_$suffix$extension';
  }

  String outputFileNameStem(String safeName, String targetExtension) {
    final trimmed = safeName.trim();
    final existingExtension = path.extension(trimmed);
    if (existingExtension.isEmpty) {
      return trimmed;
    }

    if (existingExtension.toLowerCase() == targetExtension.toLowerCase() ||
        isKnownMediaFileExtension(existingExtension)) {
      return path.basenameWithoutExtension(trimmed).trim();
    }

    return trimmed;
  }

  bool isKnownMediaFileExtension(String extension) {
    return _mediaFileExtensions.contains(extension.toLowerCase());
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
      final candidate = path.join(directory, '$baseName（$index）$extension');
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
    final normalizedFirst = normalizeForComparison(first);
    final normalizedSecond = normalizeForComparison(second);
    return normalizedFirst == normalizedSecond;
  }

  String normalizeForComparison(String targetPath) {
    final normalized = path.normalize(path.absolute(targetPath));
    if (!caseInsensitiveFileSystem) {
      return normalized;
    }

    return normalized.toLowerCase();
  }

  String extensionFor(OutputFormat outputFormat) {
    return FfmpegCommandFormatters.extensionFor(outputFormat);
  }

  MediaOutputFormat mediaOutputFormatFor(MediaTask task) {
    return switch (task.mediaKind) {
      MediaKind.video => task.config.video!.outputFormat,
      MediaKind.image => task.config.image!.outputFormat,
      MediaKind.audio => task.config.audio!.outputFormat,
    };
  }

  String extensionForMedia(MediaOutputFormat outputFormat) {
    return switch (outputFormat) {
      MediaOutputFormat.mp4 => '.mp4',
      MediaOutputFormat.mov => '.mov',
      MediaOutputFormat.mkv => '.mkv',
      MediaOutputFormat.jpg => '.jpg',
      MediaOutputFormat.png => '.png',
      MediaOutputFormat.webp => '.webp',
      MediaOutputFormat.bmp => '.bmp',
      MediaOutputFormat.tiff => '.tiff',
      MediaOutputFormat.gif => '.gif',
      MediaOutputFormat.mp3 => '.mp3',
      MediaOutputFormat.m4a => '.m4a',
      MediaOutputFormat.aac => '.aac',
      MediaOutputFormat.wav => '.wav',
      MediaOutputFormat.flac => '.flac',
      MediaOutputFormat.aiff => '.aiff',
      MediaOutputFormat.wma => '.wma',
      MediaOutputFormat.opus => '.opus',
      MediaOutputFormat.oggOpus => '.ogg',
    };
  }
}

const _mediaFileExtensions = {
  '.mp4',
  '.mov',
  '.mkv',
  '.jpg',
  '.png',
  '.webp',
  '.bmp',
  '.tiff',
  '.gif',
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.flac',
  '.aiff',
  '.wma',
  '.opus',
  '.ogg',
};
