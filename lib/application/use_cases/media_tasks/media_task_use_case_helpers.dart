import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:path/path.dart' as path;

MediaTask findMediaTaskById(List<MediaTask> tasks, String taskId) {
  for (final task in tasks) {
    if (task.id == taskId) {
      return task;
    }
  }

  throw StateError('找不到任务: $taskId');
}

MediaTask? maybeFindMediaTaskById(List<MediaTask> tasks, String taskId) {
  for (final task in tasks) {
    if (task.id == taskId) {
      return task;
    }
  }

  return null;
}

List<MediaTask> replaceMediaTask(List<MediaTask> tasks, MediaTask updatedTask) {
  return tasks.map((task) {
    if (task.id == updatedTask.id) {
      return updatedTask;
    }

    return task;
  }).toList();
}

int nextMediaTaskSortOrder(List<MediaTask> tasks) {
  if (tasks.isEmpty) {
    return 0;
  }

  return tasks
          .map((task) => task.sortOrder)
          .reduce((value, element) => value > element ? value : element) +
      1;
}

void ensureSupportedImportedMediaKind(MediaKind mediaKind) {
  switch (mediaKind) {
    case MediaKind.video:
    case MediaKind.image:
    case MediaKind.audio:
      return;
  }
}

MediaTaskConfig buildInitialTaskConfigFromSettings({
  required String sourceFileName,
  required MediaKind mediaKind,
  required AppSettings settings,
  required DateTime now,
  TaskPurpose purpose = TaskPurpose.compression,
  int version = 1,
}) {
  final mediaConfig = resolveSourceOutputFormatForConfig(
    config: settings.defaultMediaConfig.forKind(mediaKind),
    sourceFileName: sourceFileName,
    mediaKind: mediaKind,
  );

  final config = mediaConfig.copyWith(
    outputDirectory: buildOutputDirectoryFromSettings(settings),
    outputFileName: buildDefaultOutputFileName(
      sourceFileName: sourceFileName,
      mediaKind: mediaKind,
      template: settings.defaultOutputFileNameTemplate,
      purpose: purpose,
      mediaConfig: mediaConfig,
      now: now,
      version: version,
    ),
  );

  return config;
}

MediaTaskConfig resolveSourceOutputFormatForConfig({
  required MediaTaskConfig config,
  required String sourceFileName,
  required MediaKind mediaKind,
}) {
  final sourceFormat = mediaOutputFormatForSourceFileName(
    sourceFileName: sourceFileName,
    mediaKind: mediaKind,
  );

  switch (mediaKind) {
    case MediaKind.video:
      final video = config.video;
      if (video?.keepOriginalOutputFormat != true) {
        return config;
      }
      return config.copyWith(
        video: video!.copyWith(
          outputFormat: sourceFormat ?? video.outputFormat,
          keepOriginalOutputFormat: sourceFormat != null,
        ),
      );
    case MediaKind.image:
      final image = config.image;
      if (image?.keepOriginalOutputFormat != true) {
        return config;
      }
      return config.copyWith(
        image: image!.copyWith(
          outputFormat: sourceFormat ?? image.outputFormat,
          keepOriginalOutputFormat: sourceFormat != null,
        ),
      );
    case MediaKind.audio:
      final audio = config.audio;
      if (audio?.keepOriginalOutputFormat != true) {
        return config;
      }
      return config.copyWith(
        audio: audio!.copyWith(
          outputFormat: sourceFormat ?? audio.outputFormat,
          keepOriginalOutputFormat: sourceFormat != null,
        ),
      );
  }
}

MediaOutputFormat? mediaOutputFormatForSourceFileName({
  required String sourceFileName,
  required MediaKind mediaKind,
}) {
  final extension = path.extension(sourceFileName).toLowerCase();
  final format = switch (extension) {
    '.mp4' => MediaOutputFormat.mp4,
    '.mov' => MediaOutputFormat.mov,
    '.mkv' => MediaOutputFormat.mkv,
    '.jpg' || '.jpeg' => MediaOutputFormat.jpg,
    '.png' => MediaOutputFormat.png,
    '.webp' => MediaOutputFormat.webp,
    '.bmp' => MediaOutputFormat.bmp,
    '.tif' || '.tiff' => MediaOutputFormat.tiff,
    '.gif' => MediaOutputFormat.gif,
    '.mp3' => MediaOutputFormat.mp3,
    '.m4a' => MediaOutputFormat.m4a,
    '.aac' => MediaOutputFormat.aac,
    '.wav' => MediaOutputFormat.wav,
    '.flac' => MediaOutputFormat.flac,
    '.aif' || '.aiff' => MediaOutputFormat.aiff,
    '.wma' => MediaOutputFormat.wma,
    '.opus' => MediaOutputFormat.opus,
    '.ogg' => MediaOutputFormat.oggOpus,
    _ => null,
  };

  if (format == null) {
    return null;
  }

  return MediaOutputFormat.formatsFor(mediaKind).contains(format)
      ? format
      : null;
}

MediaTaskConfig buildOutputTaskConfigFromSettings({
  required MediaTask task,
  required AppSettings settings,
  required DateTime now,
  int version = 1,
}) {
  return task.config.copyWith(
    outputDirectory: buildOutputDirectoryFromSettings(settings),
    outputFileName: buildDefaultOutputFileName(
      sourceFileName: path.basename(task.inputPath),
      mediaKind: task.mediaKind,
      template: settings.defaultOutputFileNameTemplate,
      purpose: task.purpose,
      mediaConfig: task.config,
      now: now,
      version: version,
    ),
  );
}

int processingVersionForTask({
  required List<MediaTask> tasks,
  required String inputPath,
  required MediaKind mediaKind,
  required TaskPurpose purpose,
  String? taskId,
}) {
  final matchingTasks =
      tasks.where((task) {
        return task.mediaKind == mediaKind &&
            task.purpose == purpose &&
            path.equals(
              path.normalize(task.inputPath),
              path.normalize(inputPath),
            );
      }).toList()..sort((first, second) {
        final createdOrder = first.createdAt.compareTo(second.createdAt);
        if (createdOrder != 0) {
          return createdOrder;
        }

        return first.sortOrder.compareTo(second.sortOrder);
      });

  if (taskId == null) {
    return matchingTasks.length + 1;
  }

  final taskIndex = matchingTasks.indexWhere((task) => task.id == taskId);
  if (taskIndex == -1) {
    return matchingTasks.length + 1;
  }

  return taskIndex + 1;
}

String buildOutputDirectoryFromSettings(AppSettings settings) {
  return settings.saveOutputToSourceDirectory
      ? ''
      : settings.defaultOutputDirectory ?? '';
}

String buildDefaultOutputFileName({
  required String sourceFileName,
  required MediaKind mediaKind,
  required String template,
  required TaskPurpose purpose,
  required DateTime now,
  MediaTaskConfig? mediaConfig,
  int version = 1,
}) {
  final baseName = path.basenameWithoutExtension(sourceFileName).trim();
  final normalizedVersion = version < 1 ? 1 : version;
  final dateStr = [
    now.year.toString().padLeft(4, '0'),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
  ].join();
  final tokens = {
    'source': baseName,
    'date': dateStr,
    'version': 'v$normalizedVersion',
    'action': actionFileNameToken(mediaKind: mediaKind, purpose: purpose),
    'codec': codecFileNameToken(
      mediaKind: mediaKind,
      mediaConfig: mediaConfig ?? MediaTaskConfig.initialFor(mediaKind),
    ),
    'encoder': encoderFileNameToken(
      mediaKind: mediaKind,
      mediaConfig: mediaConfig ?? MediaTaskConfig.initialFor(mediaKind),
    ),
  };

  final normalizedTemplate = normalizeDefaultOutputFileNameTemplate(template);
  final rendered = normalizedTemplate.replaceAllMapped(
    RegExp(r'\{([^{}]+)\}'),
    (match) {
      final key = match.group(1)?.trim() ?? '';
      return tokens[key] ?? tokens[key.toLowerCase()] ?? '';
    },
  );
  final safeName = sanitizeOutputFileNameStem(rendered);
  if (safeName.isEmpty) {
    return sanitizeOutputFileNameStem(baseName).ifEmpty('output');
  }

  return safeName;
}

String actionFileNameToken({
  required MediaKind mediaKind,
  required TaskPurpose purpose,
}) {
  if (purpose == TaskPurpose.conversion) {
    return '转换';
  }

  return switch (mediaKind) {
    MediaKind.video => '压缩',
    MediaKind.image => '处理',
    MediaKind.audio => '处理',
  };
}

String codecFileNameToken({
  required MediaKind mediaKind,
  required MediaTaskConfig mediaConfig,
}) {
  return switch (mediaKind) {
    MediaKind.video => videoCodecFileNameToken(
      mediaConfig.video?.videoCodec ?? VideoCodec.h264,
    ),
    MediaKind.image => mediaOutputFormatFileNameToken(
      mediaConfig.image?.outputFormat ?? MediaOutputFormat.jpg,
    ),
    MediaKind.audio => mediaOutputFormatFileNameToken(
      mediaConfig.audio?.outputFormat ?? MediaOutputFormat.m4a,
    ),
  };
}

String videoCodecFileNameToken(VideoCodec codec) {
  return switch (codec) {
    VideoCodec.source => 'h264',
    VideoCodec.h264 => 'h264',
    VideoCodec.hevc => 'h265',
  };
}

String encoderFileNameToken({
  required MediaKind mediaKind,
  required MediaTaskConfig mediaConfig,
}) {
  if (mediaKind != MediaKind.video) {
    return '';
  }

  return videoEncoderBackendFileNameToken(
    backend: mediaConfig.video?.encoderBackend ?? EncoderBackend.auto,
    videoCodec: mediaConfig.video?.videoCodec ?? VideoCodec.h264,
  );
}

String videoEncoderBackendFileNameToken({
  required EncoderBackend backend,
  required VideoCodec videoCodec,
}) {
  return switch (backend) {
    EncoderBackend.auto => switch (videoCodec) {
      VideoCodec.hevc => 'x265',
      VideoCodec.source || VideoCodec.h264 => 'x264',
    },
    EncoderBackend.libx264 => 'x264',
    EncoderBackend.libx265 => 'x265',
    EncoderBackend.videotoolbox => 'videotoolbox',
    EncoderBackend.nvenc => 'nvenc',
    EncoderBackend.qsv => 'qsv',
    EncoderBackend.amf => 'amf',
  };
}

String mediaOutputFormatFileNameToken(MediaOutputFormat format) {
  return switch (format) {
    MediaOutputFormat.oggOpus => 'ogg-opus',
    _ => format.name,
  };
}

String sanitizeOutputFileNameStem(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^[\s.-]+|[\s.-]+$'), '')
      .trim();
}

extension on String {
  String ifEmpty(String fallback) {
    if (isEmpty) {
      return fallback;
    }

    return this;
  }
}
