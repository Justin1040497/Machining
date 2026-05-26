import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
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
  if (mediaKind != MediaKind.video) {
    throw StateError('当前版本暂时只支持视频文件');
  }
}

VideoTaskConfig buildInitialTaskConfigFromSettings({
  required String sourceFileName,
  required AppSettings settings,
  required DateTime now,
}) {
  final outputDirectory = settings.saveOutputToSourceDirectory
      ? ''
      : settings.defaultOutputDirectory ?? '';

  return VideoTaskConfig.initial().copyWith(
    outputDirectory: outputDirectory,
    videoCodec: settings.defaultOutputVideoCodec,
    smartPreset: settings.defaultSmartPreset,
    outputFileName: buildDefaultOutputFileName(
      sourceFileName: sourceFileName,
      codec: settings.defaultOutputVideoCodec,
      template: settings.defaultOutputFileNameTemplate,
      now: now,
    ),
  );
}

String buildDefaultOutputFileName({
  required String sourceFileName,
  required VideoCodec codec,
  required DefaultOutputFileNameTemplate template,
  required DateTime now,
}) {
  switch (template) {
    case DefaultOutputFileNameTemplate.datetimeOriginalCodec:
      final timestamp = [
        now.year.toString().padLeft(4, '0'),
        now.month.toString().padLeft(2, '0'),
        now.day.toString().padLeft(2, '0'),
        now.hour.toString().padLeft(2, '0'),
        now.minute.toString().padLeft(2, '0'),
      ].join();
      final baseName = path.basenameWithoutExtension(sourceFileName).trim();
      return '${timestamp}_${baseName}_${codecFileNameToken(codec)}';
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
