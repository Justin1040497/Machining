import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/mappers/compression_mode_mapper.dart';
import 'package:framelean/infrastructure/repositories/mappers/media_task_config_json_mapper.dart';
import 'package:framelean/infrastructure/repositories/mappers/task_failure_json_mapper.dart';

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
  Future<MediaTask?> loadTaskById(String taskId) async {
    final row = await (database.select(
      database.taskRows,
    )..where((table) => table.id.equals(taskId))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    final idSet = taskIds.toSet();
    if (idSet.isEmpty) {
      return const [];
    }
    final rows = await (database.select(
      database.taskRows,
    )..where((table) => table.id.isIn(idSet))).get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    await database
        .into(database.taskRows)
        .insertOnConflictUpdate(task.toCompanion());
  }

  @override
  Future<void> insertTasks(List<MediaTask> tasks) async {
    if (tasks.isEmpty) {
      return;
    }
    await database.transaction(() async {
      await database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          database.taskRows,
          tasks.map((task) => task.toCompanion()).toList(),
        );
      });
    });
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
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {
    if (updates.isEmpty) {
      return;
    }

    await database.transaction(() async {
      for (final update in updates) {
        await (database.update(database.taskRows)
              ..where((table) => table.id.equals(update.taskId)))
            .write(TaskRowsCompanion(sortOrder: Value(update.sortOrder)));
      }
    });
  }

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {
    if (updates.isEmpty) {
      return;
    }

    await database.transaction(() async {
      for (final update in updates) {
        await (database.update(
          database.taskRows,
        )..where((table) => table.id.equals(update.taskId))).write(
          TaskRowsCompanion(folderSortOrder: Value(update.folderSortOrder)),
        );
      }
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
      folderId: Value(folderId),
      folderSortOrder: Value(folderSortOrder),
      outputPath: Value(outputPath),
      outputFileSize: Value(outputFileSize),
      errorMessage: Value(errorMessage),
      failureJson: Value(encodeTaskFailure(failure)),
      policyTagsJson: Value(encodePolicyTags(policyTags)),
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
      analysisChromaLocation: Value(analysisResult?.chromaLocation),
      analysisMasteringDisplayMetadata: Value(
        analysisResult?.masteringDisplayMetadata,
      ),
      analysisMasteringDisplayMaxLuminance: Value(
        analysisResult?.masteringDisplayMaxLuminance,
      ),
      analysisMaxContentLightLevel: Value(analysisResult?.maxContentLightLevel),
      analysisMaxFrameAverageLightLevel: Value(
        analysisResult?.maxFrameAverageLightLevel,
      ),
      analysisDolbyVisionProfile: Value(analysisResult?.dolbyVisionProfile),
      analysisDolbyVisionCompatibilityId: Value(
        analysisResult?.dolbyVisionCompatibilityId,
      ),
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
      analysisAudioStreamsJson: Value(
        encodeAudioStreams(analysisResult?.audioStreams ?? const []),
      ),
      mediaConfigJson: Value(encodeMediaTaskConfig(config)),
      analysisImageWidth: Value(analysisResult?.imageWidth),
      analysisImageHeight: Value(analysisResult?.imageHeight),
      analysisImageCodec: Value(analysisResult?.imageCodec),
      analysisImagePixelFormat: Value(analysisResult?.imagePixelFormat),
      analysisImageBitDepth: Value(analysisResult?.imageBitDepth),
      analysisUpdatedAt: Value(analysisUpdatedAt),
      analysisErrorMessage: Value(
        failure?.stage == TaskFailureStage.analysis
            ? failure?.userMessage
            : null,
      ),
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
    final resolvedStatus = enumValueByName(TaskStatus.values, status);
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: resolvedMediaKind,
      purpose: enumValueByName(TaskPurpose.values, purpose),
      status: resolvedStatus,
      config: toMediaTaskConfig(resolvedMediaKind),
      progress: progress,
      sortOrder: sortOrder,
      folderId: folderId,
      folderSortOrder: folderSortOrder,
      outputPath: outputPath,
      outputFileSize: outputFileSize,
      failure: decodeTaskFailure(
        failureJson,
        status: resolvedStatus,
        legacyErrorMessage: errorMessage,
        legacyAnalysisErrorMessage: analysisErrorMessage,
        failedAt: failedAt,
      ),
      policyTags: decodePolicyTags(policyTagsJson),
      sourceFileFingerprint: toSourceFileFingerprint(),
      analysisResult: toMediaAnalysisResult(),
      analysisUpdatedAt: analysisUpdatedAt,
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
        analysisChromaLocation != null ||
        analysisMasteringDisplayMetadata != null ||
        analysisMasteringDisplayMaxLuminance != null ||
        analysisMaxContentLightLevel != null ||
        analysisMaxFrameAverageLightLevel != null ||
        analysisDolbyVisionProfile != null ||
        analysisDolbyVisionCompatibilityId != null ||
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
        analysisAudioStreamsJson != null ||
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
      chromaLocation: analysisChromaLocation,
      masteringDisplayMetadata: analysisMasteringDisplayMetadata,
      masteringDisplayMaxLuminance: analysisMasteringDisplayMaxLuminance,
      maxContentLightLevel: analysisMaxContentLightLevel,
      maxFrameAverageLightLevel: analysisMaxFrameAverageLightLevel,
      dolbyVisionProfile: analysisDolbyVisionProfile,
      dolbyVisionCompatibilityId: analysisDolbyVisionCompatibilityId,
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
      audioStreams: decodeAudioStreams(analysisAudioStreamsJson),
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

class DriftTaskFolderRepository implements TaskFolderRepository {
  final AppDatabase database;

  DriftTaskFolderRepository(this.database);

  @override
  Future<List<TaskFolder>> loadAllFolders() async {
    final rows =
        await (database.select(database.taskFolderRows)..orderBy([
              (table) => OrderingTerm.asc(table.sortOrder),
              (table) => OrderingTerm.asc(table.createdAt),
            ]))
            .get();

    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> saveFolder(TaskFolder folder) async {
    await database
        .into(database.taskFolderRows)
        .insertOnConflictUpdate(folder.toCompanion());
  }

  @override
  Future<void> updateFolderSortOrders(
    List<TaskFolderSortOrderUpdate> updates,
  ) async {
    if (updates.isEmpty) {
      return;
    }

    await database.transaction(() async {
      for (final update in updates) {
        await (database.update(database.taskFolderRows)
              ..where((table) => table.id.equals(update.folderId)))
            .write(TaskFolderRowsCompanion(sortOrder: Value(update.sortOrder)));
      }
    });
  }

  @override
  Future<void> deleteFolderById(String folderId) async {
    await (database.delete(
      database.taskFolderRows,
    )..where((table) => table.id.equals(folderId))).go();
  }

  @override
  Future<void> clearAllFolders() async {
    await database.delete(database.taskFolderRows).go();
  }
}

extension TaskFolderMapper on TaskFolder {
  TaskFolderRowsCompanion toCompanion() {
    return TaskFolderRowsCompanion(
      id: Value(id),
      name: Value(name),
      mediaKind: Value(mediaKind.name),
      defaultPurpose: Value(defaultPurpose.name),
      sortOrder: Value(sortOrder),
      defaultConfigJson: Value(encodeMediaTaskConfig(defaultConfig)),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

extension TaskFolderRowMapper on TaskFolderRow {
  TaskFolder toDomain() {
    final resolvedMediaKind = enumValueByName(MediaKind.values, mediaKind);
    return TaskFolder(
      id: id,
      name: name,
      mediaKind: resolvedMediaKind,
      defaultPurpose: enumValueByName(TaskPurpose.values, defaultPurpose),
      sortOrder: sortOrder,
      defaultConfig: decodeMediaTaskConfig(defaultConfigJson),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

String? encodePolicyTags(Set<MediaTaskPolicyTag> tags) {
  if (tags.isEmpty) {
    return null;
  }
  return jsonEncode(tags.map((tag) => tag.name).toList());
}

Set<MediaTaskPolicyTag> decodePolicyTags(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const {};
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      return const {};
    }
    return decoded
        .whereType<String>()
        .map((name) => nullableEnumValueByName(MediaTaskPolicyTag.values, name))
        .whereType<MediaTaskPolicyTag>()
        .toSet();
  } on Object {
    return const {};
  }
}

String? encodeAudioStreams(List<MediaAudioStreamInfo> streams) {
  if (streams.isEmpty) {
    return null;
  }

  return jsonEncode(
    streams
        .map(
          (stream) => {
            'index': stream.index,
            'codec': stream.codec,
            'channels': stream.channels,
            'sampleRate': stream.sampleRate,
            'channelLayout': stream.channelLayout,
            'language': stream.language,
            'title': stream.title,
          },
        )
        .toList(),
  );
}

List<MediaAudioStreamInfo> decodeAudioStreams(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const [];
  }

  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) {
          return MediaAudioStreamInfo(
            index: item['index'] is int ? item['index'] as int : 0,
            codec: item['codec']?.toString(),
            channels: item['channels'] is int ? item['channels'] as int : null,
            sampleRate: item['sampleRate'] is int
                ? item['sampleRate'] as int
                : null,
            channelLayout: item['channelLayout']?.toString(),
            language: item['language']?.toString(),
            title: item['title']?.toString(),
          );
        })
        .toList(growable: false);
  } on Object {
    return const [];
  }
}
