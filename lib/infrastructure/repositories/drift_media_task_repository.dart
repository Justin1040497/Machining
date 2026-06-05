import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/audio_codec.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/image_codec.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/media_processing_preset.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/mappers/compression_mode_mapper.dart';

/// 用 Drift + SQLite 实现任务列表的读取、保存和删除
class DriftMediaTaskRepository implements MediaTaskRepository {
  final AppDatabase database;

  DriftMediaTaskRepository(this.database);

  @override
  Future<List<MediaTask>> loadAllTasks() async {
    final rows =
        /// SELECT * FROM tasks
        /// 读取数据库的taskRows表的全部内容 并排序
        /// ORDER BY sort_order ASC, created_at ASC
        /// 先用sortOrder从小到大排 如果两个任务的sortOrder一样 那就用创建时间排
        await (database.select(database.taskRows)..orderBy([
              (table) => OrderingTerm.asc(table.sortOrder),
              (table) => OrderingTerm.asc(table.createdAt),
            ]))
            .get();

    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    await database
        .into(database.taskRows)
        .insertOnConflictUpdate(task.toCompanion());
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    await database.transaction(() async {
      await database.delete(database.taskRows).go();

      if (tasks.isEmpty) {
        return;
      }

      await database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          database.taskRows,
          tasks.map((task) => task.toCompanion()).toList(),
        );
      });
    });
  }

  @override
  Future<void> deleteTaskById(String taskId) async {
    await (database.delete(
      database.taskRows,
    )..where((table) => table.id.equals(taskId))).go();
  }
}

/// MediaTask 实体类转数据库 TaskRows 表数据
extension MediaTaskMapper on MediaTask {
  TaskRowsCompanion toCompanion() {
    final legacyVideoConfig = config.video ?? VideoProcessingConfig.initial();
    return TaskRowsCompanion(
      id: Value(id),
      inputPath: Value(inputPath),
      fileName: Value(fileName),
      mediaKind: Value(mediaKind.name),
      purpose: Value(purpose.name),
      status: Value(status.name),
      progress: Value(progress),
      sortOrder: Value(sortOrder),
      outputPath: Value(outputPath),
      errorMessage: Value(errorMessage),
      sourceFileSize: Value(sourceFileFingerprint?.fileSize),
      sourceLastModifiedAt: Value(sourceFileFingerprint?.lastModifiedAt),
      analysisDurationMs: Value(analysisResult?.durationMs),
      analysisVideoWidth: Value(analysisResult?.videoWidth),
      analysisVideoHeight: Value(analysisResult?.videoHeight),
      analysisVideoCodec: Value(analysisResult?.videoCodec),
      analysisAudioCodec: Value(analysisResult?.audioCodec),
      analysisVideoPixelFormat: Value(analysisResult?.videoPixelFormat),
      analysisVideoBitDepth: Value(analysisResult?.videoBitDepth),
      analysisColorRange: Value(analysisResult?.colorRange),
      analysisColorSpace: Value(analysisResult?.colorSpace),
      analysisColorTransfer: Value(analysisResult?.colorTransfer),
      analysisColorPrimaries: Value(analysisResult?.colorPrimaries),
      analysisAverageFrameRate: Value(analysisResult?.averageFrameRate),
      analysisRealFrameRate: Value(analysisResult?.realFrameRate),
      analysisSampleAspectRatio: Value(analysisResult?.sampleAspectRatio),
      analysisDisplayAspectRatio: Value(analysisResult?.displayAspectRatio),
      analysisVideoRotationDegrees: Value(analysisResult?.videoRotationDegrees),
      analysisFieldOrder: Value(analysisResult?.fieldOrder),
      analysisVideoBitrate: Value(analysisResult?.videoBitrate),
      analysisAudioBitrate: Value(analysisResult?.audioBitrate),
      analysisContainerBitrate: Value(analysisResult?.containerBitrate),
      analysisEstimatedBitrate: Value(analysisResult?.estimatedBitrate),
      analysisContainerFormat: Value(analysisResult?.containerFormat),
      analysisAudioChannels: Value(analysisResult?.audioChannels),
      analysisAudioSampleRate: Value(analysisResult?.audioSampleRate),
      analysisAudioChannelLayout: Value(analysisResult?.audioChannelLayout),
      analysisAudioStreamIndex: Value(analysisResult?.audioStreamIndex),
      mediaConfigJson: Value(encodeMediaTaskConfig(config)),
      analysisImageWidth: Value(analysisResult?.imageWidth),
      analysisImageHeight: Value(analysisResult?.imageHeight),
      analysisImageCodec: Value(analysisResult?.imageCodec),
      analysisImagePixelFormat: Value(analysisResult?.imagePixelFormat),
      analysisImageBitDepth: Value(analysisResult?.imageBitDepth),
      analysisUpdatedAt: Value(analysisUpdatedAt),
      analysisErrorMessage: Value(analysisErrorMessage),
      outputFormat: Value(
        legacyVideoConfig.outputFormat.toVideoOutputFormat().name,
      ),
      videoCodec: Value(legacyVideoConfig.videoCodec.name),
      encoderBackend: Value(legacyVideoConfig.encoderBackend.name),
      resolutionPreset: Value(legacyVideoConfig.resolutionPreset.name),
      outputDirectory: Value(config.outputDirectory),
      compressionCrf: Value(legacyVideoConfig.compressionCrf),
      compressionMode: Value(
        CompressionModeMapper.toStorage(config.compressionMode),
      ),
      smartPreset: Value(legacyVideoConfig.smartPreset?.name),
      targetSizeBytes: Value(config.targetSizeBytes),
      targetSizeRatio: Value(config.targetSizeRatio),
      outputFileName: Value(config.outputFileName),
      createdAt: Value(createdAt),
      startedAt: Value(startedAt),
      completedAt: Value(completedAt),
      failedAt: Value(failedAt),
    );
  }
}

/// 数据库 TaskRows 表数据转 MediaTask 实体类
extension TaskRowMapper on TaskRow {
  MediaTask toDomain() {
    final resolvedMediaKind = enumValueByName(MediaKind.values, mediaKind);
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: resolvedMediaKind,
      purpose: enumValueByName(TaskPurpose.values, purpose),
      status: enumValueByName(TaskStatus.values, status),
      config: toMediaTaskConfig(resolvedMediaKind),
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: toSourceFileFingerprint(),
      analysisResult: toMediaAnalysisResult(),
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  SourceFileFingerprint? toSourceFileFingerprint() {
    if (sourceFileSize == null || sourceLastModifiedAt == null) {
      return null;
    }

    return SourceFileFingerprint(
      fileSize: sourceFileSize!,
      lastModifiedAt: sourceLastModifiedAt!,
    );
  }

  MediaAnalysisResult? toMediaAnalysisResult() {
    final hasAnalysis =
        analysisDurationMs != null ||
        analysisVideoWidth != null ||
        analysisVideoHeight != null ||
        analysisVideoCodec != null ||
        analysisAudioCodec != null ||
        analysisVideoPixelFormat != null ||
        analysisVideoBitDepth != null ||
        analysisColorRange != null ||
        analysisColorSpace != null ||
        analysisColorTransfer != null ||
        analysisColorPrimaries != null ||
        analysisAverageFrameRate != null ||
        analysisRealFrameRate != null ||
        analysisSampleAspectRatio != null ||
        analysisDisplayAspectRatio != null ||
        analysisVideoRotationDegrees != null ||
        analysisFieldOrder != null ||
        analysisVideoBitrate != null ||
        analysisAudioBitrate != null ||
        analysisContainerBitrate != null ||
        analysisEstimatedBitrate != null ||
        analysisContainerFormat != null ||
        analysisAudioChannels != null ||
        analysisAudioSampleRate != null ||
        analysisAudioChannelLayout != null ||
        analysisAudioStreamIndex != null ||
        analysisImageWidth != null ||
        analysisImageHeight != null ||
        analysisImageCodec != null ||
        analysisImagePixelFormat != null ||
        analysisImageBitDepth != null;

    if (!hasAnalysis) {
      return null;
    }

    return MediaAnalysisResult(
      durationMs: analysisDurationMs,
      videoWidth: analysisVideoWidth,
      videoHeight: analysisVideoHeight,
      videoCodec: analysisVideoCodec,
      audioCodec: analysisAudioCodec,
      videoPixelFormat: analysisVideoPixelFormat,
      videoBitDepth: analysisVideoBitDepth,
      colorRange: analysisColorRange,
      colorSpace: analysisColorSpace,
      colorTransfer: analysisColorTransfer,
      colorPrimaries: analysisColorPrimaries,
      averageFrameRate: analysisAverageFrameRate,
      realFrameRate: analysisRealFrameRate,
      sampleAspectRatio: analysisSampleAspectRatio,
      displayAspectRatio: analysisDisplayAspectRatio,
      videoRotationDegrees: analysisVideoRotationDegrees,
      fieldOrder: analysisFieldOrder,
      videoBitrate: analysisVideoBitrate,
      audioBitrate: analysisAudioBitrate,
      containerBitrate: analysisContainerBitrate,
      estimatedBitrate: analysisEstimatedBitrate,
      containerFormat: analysisContainerFormat,
      audioChannels: analysisAudioChannels,
      audioSampleRate: analysisAudioSampleRate,
      audioChannelLayout: analysisAudioChannelLayout,
      audioStreamIndex: analysisAudioStreamIndex,
      imageWidth: analysisImageWidth,
      imageHeight: analysisImageHeight,
      imageCodec: analysisImageCodec,
      imagePixelFormat: analysisImagePixelFormat,
      imageBitDepth: analysisImageBitDepth,
      orientationDegrees: analysisVideoRotationDegrees,
    );
  }

  MediaTaskConfig toMediaTaskConfig(MediaKind mediaKind) {
    final json = mediaConfigJson;
    if (json != null && json.isNotEmpty) {
      return decodeMediaTaskConfig(json);
    }

    if (mediaKind != MediaKind.video) {
      return MediaTaskConfig.initialFor(mediaKind).copyWith(
        outputDirectory: outputDirectory,
        outputFileName: outputFileName,
        compressionMode: CompressionModeMapper.fromStorage(compressionMode),
        targetSizeBytes: targetSizeBytes,
        targetSizeRatio: targetSizeRatio,
      );
    }

    return MediaTaskConfig.fromVideoTaskConfig(
      VideoTaskConfig(
        outputFormat: enumValueByName(OutputFormat.values, outputFormat),
        videoCodec: enumValueByName(VideoCodec.values, videoCodec),
        encoderBackend: enumValueByName(EncoderBackend.values, encoderBackend),
        resolutionPreset: enumValueByName(
          ResolutionPreset.values,
          resolutionPreset,
        ),
        outputDirectory: outputDirectory,
        compressionCrf: compressionCrf,
        compressionMode: CompressionModeMapper.fromStorage(compressionMode),
        smartPreset: nullableEnumValueByName(
          SmartCompressionPreset.values,
          smartPreset,
        ),
        targetSizeBytes: targetSizeBytes,
        targetSizeRatio: targetSizeRatio,
        outputFileName: outputFileName,
      ),
    );
  }
}

String encodeMediaTaskConfig(MediaTaskConfig config) {
  return jsonEncode(mediaTaskConfigToJson(config));
}

MediaTaskConfig decodeMediaTaskConfig(String text) {
  final json = jsonDecode(text);
  if (json is! Map<String, dynamic>) {
    throw StateError('媒体配置 JSON 格式无效');
  }

  return mediaTaskConfigFromJson(json);
}

Map<String, Object?> mediaTaskConfigToJson(MediaTaskConfig config) {
  return {
    'configVersion': 1,
    'outputDirectory': config.outputDirectory,
    'outputFileName': config.outputFileName,
    'compressionMode': config.compressionMode.name,
    'preset': config.preset?.name,
    'targetSizeBytes': config.targetSizeBytes,
    'targetSizeRatio': config.targetSizeRatio,
    'video': videoConfigToJson(config.video),
    'image': imageConfigToJson(config.image),
    'audio': audioConfigToJson(config.audio),
  };
}

MediaTaskConfig mediaTaskConfigFromJson(Map<String, dynamic> json) {
  return MediaTaskConfig(
    outputDirectory: stringValue(json['outputDirectory']) ?? '',
    outputFileName: stringValue(json['outputFileName']) ?? '',
    compressionMode:
        nullableEnumValueByName(
          CompressionMode.values,
          stringValue(json['compressionMode']),
        ) ??
        CompressionMode.preset,
    preset: nullableEnumValueByName(
      MediaProcessingPreset.values,
      stringValue(json['preset']),
    ),
    targetSizeBytes: intValue(json['targetSizeBytes']),
    targetSizeRatio: doubleValue(json['targetSizeRatio']),
    video: videoConfigFromJson(mapValue(json['video'])),
    image: imageConfigFromJson(mapValue(json['image'])),
    audio: audioConfigFromJson(mapValue(json['audio'])),
  );
}

Map<String, Object?>? videoConfigToJson(VideoProcessingConfig? config) {
  if (config == null) {
    return null;
  }

  return {
    'outputFormat': config.outputFormat.name,
    'videoCodec': config.videoCodec.name,
    'encoderBackend': config.encoderBackend.name,
    'resolutionPreset': config.resolutionPreset.name,
    'compressionCrf': config.compressionCrf,
    'smartPreset': config.smartPreset?.name,
  };
}

VideoProcessingConfig? videoConfigFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  return VideoProcessingConfig(
    outputFormat:
        nullableEnumValueByName(
          MediaOutputFormat.values,
          stringValue(json['outputFormat']),
        ) ??
        MediaOutputFormat.mp4,
    videoCodec:
        nullableEnumValueByName(
          VideoCodec.values,
          stringValue(json['videoCodec']),
        ) ??
        VideoCodec.h264,
    encoderBackend:
        nullableEnumValueByName(
          EncoderBackend.values,
          stringValue(json['encoderBackend']),
        ) ??
        EncoderBackend.auto,
    resolutionPreset:
        nullableEnumValueByName(
          ResolutionPreset.values,
          stringValue(json['resolutionPreset']),
        ) ??
        ResolutionPreset.original,
    compressionCrf: intValue(json['compressionCrf']) ?? 28,
    smartPreset: nullableEnumValueByName(
      SmartCompressionPreset.values,
      stringValue(json['smartPreset']),
    ),
  );
}

Map<String, Object?>? imageConfigToJson(ImageProcessingConfig? config) {
  if (config == null) {
    return null;
  }

  return {
    'outputFormat': config.outputFormat.name,
    'imageCodec': config.imageCodec.name,
    'imageQuality': config.imageQuality,
    'resizePreset': config.resizePreset.name,
    'preserveMetadata': config.preserveMetadata,
  };
}

ImageProcessingConfig? imageConfigFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  return ImageProcessingConfig(
    outputFormat:
        nullableEnumValueByName(
          MediaOutputFormat.values,
          stringValue(json['outputFormat']),
        ) ??
        MediaOutputFormat.jpg,
    imageCodec:
        nullableEnumValueByName(
          ImageCodec.values,
          stringValue(json['imageCodec']),
        ) ??
        ImageCodec.jpeg,
    imageQuality: intValue(json['imageQuality']) ?? 82,
    resizePreset:
        nullableEnumValueByName(
          ImageResizePreset.values,
          stringValue(json['resizePreset']),
        ) ??
        ImageResizePreset.original,
    preserveMetadata: boolValue(json['preserveMetadata']) ?? false,
  );
}

Map<String, Object?>? audioConfigToJson(AudioProcessingConfig? config) {
  if (config == null) {
    return null;
  }

  return {
    'outputFormat': config.outputFormat.name,
    'audioCodec': config.audioCodec.name,
    'bitratePreset': config.bitratePreset.name,
    'sampleRate': config.sampleRate.name,
    'channels': config.channels.name,
  };
}

AudioProcessingConfig? audioConfigFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  return AudioProcessingConfig(
    outputFormat:
        nullableEnumValueByName(
          MediaOutputFormat.values,
          stringValue(json['outputFormat']),
        ) ??
        MediaOutputFormat.m4a,
    audioCodec:
        nullableEnumValueByName(
          AudioCodec.values,
          stringValue(json['audioCodec']),
        ) ??
        AudioCodec.aac,
    bitratePreset:
        nullableEnumValueByName(
          AudioBitratePreset.values,
          stringValue(json['bitratePreset']),
        ) ??
        AudioBitratePreset.k192,
    sampleRate:
        nullableEnumValueByName(
          AudioSampleRatePreset.values,
          stringValue(json['sampleRate']),
        ) ??
        AudioSampleRatePreset.source,
    channels:
        nullableEnumValueByName(
          AudioChannelsPreset.values,
          stringValue(json['channels']),
        ) ??
        AudioChannelsPreset.source,
  );
}

Map<String, dynamic>? mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? stringValue(Object? value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

int? intValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

double? doubleValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

bool? boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  return switch (value?.toString()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

T enumValueByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  throw StateError('未知的枚举值: $name');
}

T? nullableEnumValueByName<T extends Enum>(List<T> values, String? name) {
  if (name == null || name.trim().isEmpty) {
    return null;
  }

  return enumValueByName(values, name);
}
