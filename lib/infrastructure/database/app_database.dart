import 'package:framelean/infrastructure/database/app_notifications.dart';
import 'package:framelean/infrastructure/database/settings.dart';
import 'package:framelean/infrastructure/database/tasks.dart';
import 'package:path/path.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:framelean/infrastructure/database/persistence_compatibility.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// 数据库管理
@DriftDatabase(tables: [SettingsRows, TaskRows, AppNotificationRows])
class AppDatabase extends _$AppDatabase {
  /// 创建AppDatabase时 自动打开数据库
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.e);

  /// 安全添加列 - 如果列已存在则跳过，确保迁移幂等。
  /// 用于处理某些边缘情况（如开发阶段 onCreate 已创建完整表结构后
  /// 迁移再次触发）导致的 "duplicate column name" 错误。
  Future<void> _safeAddColumn(
    Migrator migrator,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    try {
      await migrator.addColumn(table, column);
    } catch (e) {
      final message = e.toString();
      if (message.contains('duplicate column')) {
        return; // 列已存在，安全跳过
      }
      rethrow;
    }
  }

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await _safeAddColumn(migrator, taskRows, taskRows.mediaKind);
        }
        if (from < 3) {
          await _safeAddColumn(migrator, taskRows, taskRows.sourceFileSize);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.sourceLastModifiedAt,
          );
          await _safeAddColumn(migrator, taskRows, taskRows.analysisDurationMs);
          await _safeAddColumn(migrator, taskRows, taskRows.analysisVideoWidth);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisVideoHeight,
          );
          await _safeAddColumn(migrator, taskRows, taskRows.analysisVideoCodec);
          await _safeAddColumn(migrator, taskRows, taskRows.analysisAudioCodec);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisContainerFormat,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAudioChannels,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAudioSampleRate,
          );
          await _safeAddColumn(migrator, taskRows, taskRows.analysisUpdatedAt);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisErrorMessage,
          );
        }
        if (from < 4) {
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisVideoBitrate,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisContainerBitrate,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisEstimatedBitrate,
          );
        }
        if (from < 5) {
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAudioBitrate,
          );
        }
        if (from < 6) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.defaultOutputVideoCodec,
          );
        }
        if (from < 7) {
          await _safeAddColumn(migrator, taskRows, taskRows.compressionCrf);
          await _safeAddColumn(migrator, taskRows, taskRows.outputFileName);
        }
        if (from < 8) {
          await _safeAddColumn(migrator, taskRows, taskRows.compressionMode);
          await _safeAddColumn(migrator, taskRows, taskRows.targetSizeRatio);
        }
        if (from < 9) {
          await _safeAddColumn(migrator, taskRows, taskRows.smartPreset);
          await _safeAddColumn(migrator, taskRows, taskRows.targetSizeBytes);
        }
        if (from < 10) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.saveOutputToSourceDirectory,
          );
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.defaultCompressionSmartPreset,
          );
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.defaultOutputFileNameTemplate,
          );
        }
        if (from < 11) {
          await customStatement(
            "UPDATE tasks SET compression_mode = '${PersistenceCompatibility.compressionModePreset}' "
            "WHERE compression_mode IN ("
            "'${PersistenceCompatibility.legacyCompressionModeSmart}', "
            "'${PersistenceCompatibility.legacyCompressionModeQuality}'"
            ")",
          );
        }
        if (from < 12) {
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisVideoPixelFormat,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisVideoBitDepth,
          );
          await _safeAddColumn(migrator, taskRows, taskRows.analysisColorRange);
          await _safeAddColumn(migrator, taskRows, taskRows.analysisColorSpace);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisColorTransfer,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisColorPrimaries,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAverageFrameRate,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisRealFrameRate,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisSampleAspectRatio,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisDisplayAspectRatio,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisVideoRotationDegrees,
          );
          await _safeAddColumn(migrator, taskRows, taskRows.analysisFieldOrder);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAudioChannelLayout,
          );
        }
        if (from < 13) {
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAudioStreamIndex,
          );
        }
        if (from < 14) {
          await _safeAddColumn(migrator, taskRows, taskRows.mediaConfigJson);
          await _safeAddColumn(migrator, taskRows, taskRows.analysisImageWidth);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisImageHeight,
          );
          await _safeAddColumn(migrator, taskRows, taskRows.analysisImageCodec);
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisImagePixelFormat,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisImageBitDepth,
          );
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.defaultMediaConfigJson,
          );
        }
        if (from < 15) {
          await _safeAddColumn(migrator, settingsRows, settingsRows.themeMode);
        }
        if (from < 16) {
          await migrator.createTable(appNotificationRows);
        }
        if (from < 17) {
          await _safeAddColumn(
            migrator,
            appNotificationRows,
            appNotificationRows.kind,
          );
        }
        if (from < 18) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.hideNotificationBadge,
          );
        }
        if (from < 19) {
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisChromaLocation,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisMasteringDisplayMetadata,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisMasteringDisplayMaxLuminance,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisMaxContentLightLevel,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisMaxFrameAverageLightLevel,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisDolbyVisionProfile,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisDolbyVisionCompatibilityId,
          );
        }
        if (from < 20) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.taskCompletionSound,
          );
        }
        if (from < 21) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.showTaskCompletionDialog,
          );
        }
      },
    );
  }
}

/// 连接数据库的方法 这个方法是一个顶层函数
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    /// 获取系统目录
    final directory = await getApplicationSupportDirectory();

    /// 拼接系统目录和数据库文件名
    final databasePath = join(directory.path, 'framelean.sqlite');
    final file = File(databasePath);

    /// 返回一个数据库 如果没有则创建一个
    return NativeDatabase.createInBackground(file);
  });
}
