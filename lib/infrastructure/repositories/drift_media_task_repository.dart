import 'package:drift/drift.dart';
import 'package:machining/application/repositories/media_task_repository.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/infrastructure/database/app_database.dart';

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
      analysisVideoBitrate: Value(analysisResult?.videoBitrate),
      analysisAudioBitrate: Value(analysisResult?.audioBitrate),
      analysisContainerBitrate: Value(analysisResult?.containerBitrate),
      analysisEstimatedBitrate: Value(analysisResult?.estimatedBitrate),
      analysisContainerFormat: Value(analysisResult?.containerFormat),
      analysisAudioChannels: Value(analysisResult?.audioChannels),
      analysisAudioSampleRate: Value(analysisResult?.audioSampleRate),
      analysisUpdatedAt: Value(analysisUpdatedAt),
      analysisErrorMessage: Value(analysisErrorMessage),
      outputFormat: Value(config.outputFormat.name),
      videoCodec: Value(config.videoCodec.name),
      encoderBackend: Value(config.encoderBackend.name),
      resolutionPreset: Value(config.resolutionPreset.name),
      outputDirectory: Value(config.outputDirectory),
      compressionCrf: Value(config.compressionCrf),
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
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: enumValueByName(MediaKind.values, mediaKind),
      purpose: enumValueByName(TaskPurpose.values, purpose),
      status: enumValueByName(TaskStatus.values, status),
      config: VideoTaskConfig(
        outputFormat: enumValueByName(OutputFormat.values, outputFormat),
        videoCodec: enumValueByName(VideoCodec.values, videoCodec),
        encoderBackend: enumValueByName(EncoderBackend.values, encoderBackend),
        resolutionPreset: enumValueByName(
          ResolutionPreset.values,
          resolutionPreset,
        ),
        outputDirectory: outputDirectory,
        compressionCrf: compressionCrf,
        outputFileName: outputFileName,
      ),
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
        analysisVideoBitrate != null ||
        analysisAudioBitrate != null ||
        analysisContainerBitrate != null ||
        analysisEstimatedBitrate != null ||
        analysisContainerFormat != null ||
        analysisAudioChannels != null ||
        analysisAudioSampleRate != null;

    if (!hasAnalysis) {
      return null;
    }

    return MediaAnalysisResult(
      durationMs: analysisDurationMs,
      videoWidth: analysisVideoWidth,
      videoHeight: analysisVideoHeight,
      videoCodec: analysisVideoCodec,
      audioCodec: analysisAudioCodec,
      videoBitrate: analysisVideoBitrate,
      audioBitrate: analysisAudioBitrate,
      containerBitrate: analysisContainerBitrate,
      estimatedBitrate: analysisEstimatedBitrate,
      containerFormat: analysisContainerFormat,
      audioChannels: analysisAudioChannels,
      audioSampleRate: analysisAudioSampleRate,
    );
  }
}

T enumValueByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  throw StateError('未知的枚举值: $name');
}
