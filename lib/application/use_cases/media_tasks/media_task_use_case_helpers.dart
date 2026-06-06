import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/media_kind.dart';
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
}) {
  final outputDirectory = settings.saveOutputToSourceDirectory
      ? ''
      : settings.defaultOutputDirectory ?? '';

  final config = settings.defaultMediaConfig
      .forKind(mediaKind)
      .copyWith(
        outputDirectory: outputDirectory,
        outputFileName: buildDefaultOutputFileName(
          sourceFileName: sourceFileName,
          mediaKind: mediaKind,
          codec: settings.defaultOutputVideoCodec,
          template: settings.defaultOutputFileNameTemplate,
          now: now,
        ),
      );

  return config;
}

String buildDefaultOutputFileName({
  required String sourceFileName,
  required MediaKind mediaKind,
  required VideoCodec codec,
  required DefaultOutputFileNameTemplate template,
  required DateTime now,
}) {
  final baseName = path.basenameWithoutExtension(sourceFileName).trim();
  final codecToken = switch (mediaKind) {
    MediaKind.video => codecFileNameToken(codec),
    MediaKind.image => 'image',
    MediaKind.audio => 'audio',
  };
  final dateStr = [
    now.year.toString().padLeft(4, '0'),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
  ].join();

  switch (template) {
    case DefaultOutputFileNameTemplate.sourceFileNameCodec:
      return '$baseName-$codecToken';
    case DefaultOutputFileNameTemplate.sourceFileNameDateCodec:
      return '$baseName-$dateStr-$codecToken';
    case DefaultOutputFileNameTemplate.sourceFileNameCompression:
      return '$baseName-Compression';
    case DefaultOutputFileNameTemplate.sourceFileNameCompressed:
      return '$baseName-已压缩';
    case DefaultOutputFileNameTemplate.sourceFileNameOnly:
      return baseName;
  }
}

String codecFileNameToken(VideoCodec codec) {
  switch (codec) {
    case VideoCodec.source:
      return 'source';
    case VideoCodec.h264:
      return 'h264';
    case VideoCodec.hevc:
      return 'hevc';
  }
}
