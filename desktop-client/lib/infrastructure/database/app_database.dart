import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/database/app_notifications.dart';
import 'package:framelean/infrastructure/database/engine_analysis_projections.dart';
import 'package:framelean/infrastructure/database/settings.dart';
import 'package:framelean/infrastructure/database/task_folders.dart';
import 'package:framelean/infrastructure/database/workbench_order_states.dart';
import 'package:framelean/infrastructure/database/tasks.dart';
import 'package:path/path.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:framelean/infrastructure/database/persistence_compatibility.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// 数据库管理
@DriftDatabase(
  tables: [
    SettingsRows,
    TaskRows,
    TaskFolderRows,
    AppNotificationRows,
    EngineAnalysisProjectionRows,
    WorkbenchOrderStateRows,
  ],
)
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

  Future<void> _safeCreateTable(Migrator migrator, TableInfo table) async {
    try {
      await migrator.createTable(table);
    } catch (e) {
      final message = e.toString();
      if (message.contains('already exists')) {
        return;
      }
      rethrow;
    }
  }

  @override
  int get schemaVersion => 38;

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
        if (from < 22) {
          await customStatement(
            "UPDATE settings SET default_compression_smart_preset = 'chat' "
            "WHERE default_compression_smart_preset = 'balanced'",
          );
          await customStatement(
            "UPDATE settings SET default_output_file_name_template = '{source}-{action}' "
            "WHERE default_output_file_name_template = '{source}-{date}-{action}'",
          );
          await customStatement(
            "UPDATE settings SET task_completion_sound = 'clean_success' "
            "WHERE task_completion_sound = 'none'",
          );
        }
        if (from < 23) {
          await customStatement(
            "UPDATE settings SET default_output_file_name_template = '{source}-{action}' "
            "WHERE default_output_file_name_template = '{source}-{date}'",
          );
        }
        if (from < 24) {
          await _safeAddColumn(
            migrator,
            appNotificationRows,
            appNotificationRows.dedupeKey,
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_app_notifications_dedupe_key '
            'ON app_notifications (dedupe_key) WHERE dedupe_key IS NOT NULL',
          );
        }
        if (from < 25) {
          await _safeCreateTable(migrator, taskFolderRows);
          await _safeAddColumn(migrator, taskRows, taskRows.folderId);
          await _safeAddColumn(migrator, taskRows, taskRows.folderSortOrder);
          await _safeAddColumn(migrator, taskRows, taskRows.policyTagsJson);
        }
        if (from < 27) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.folderImportScanDepth,
          );
          await _safeAddColumn(
            migrator,
            taskRows,
            taskRows.analysisAudioStreamsJson,
          );
        }
        if (from < 28) {
          await _safeAddColumn(migrator, taskRows, taskRows.outputFileSize);
        }
        if (from < 29) {
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.notificationPoliciesJson,
          );
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.shortcutBindingsJson,
          );
          await _safeAddColumn(
            migrator,
            settingsRows,
            settingsRows.closeBehavior,
          );
        }
        if (from < 30) {
          await _safeAddColumn(migrator, taskRows, taskRows.failureJson);
        }
        if (from < 31) {
          await _safeCreateTable(migrator, engineAnalysisProjectionRows);
        }
        if (from < 32) {
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.analysisWorkId,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.analysisQueuePosition,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.analysisQueueRevision,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.executionId,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.executionQueuePosition,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.executionQueueRevision,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.executionState,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.pauseReason,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.preemptedByExecutionId,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.resumeDepth,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.mediaTimeUs,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.processedBytes,
          );
          await customStatement(
            "UPDATE tasks SET status = CASE "
            "WHEN status IN ('awaitingAnalysis', 'analysis_pending') THEN 'await_analysis' "
            "WHEN status = 'pending' THEN 'ready' "
            "WHEN status = 'failed' AND analysis_error_message IS NOT NULL THEN 'analysis_failed' "
            "WHEN status = 'failed' THEN 'execution_failed' "
            "WHEN status = 'missingSource' THEN 'missing_source' "
            "ELSE status END",
          );
        }
        if (from < 33) {
          await _safeCreateTable(migrator, workbenchOrderStateRows);
        }
        if (from < 34) {
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.analysisRequestId,
          );
          await _safeAddColumn(
            migrator,
            engineAnalysisProjectionRows,
            engineAnalysisProjectionRows.executionRequestId,
          );
        }
        if (from < 36) {
          final settingsColumns = await customSelect(
            'PRAGMA table_info(settings)',
          ).get();
          final hasLegacyConcurrencyColumn = settingsColumns.any(
            (row) => row.read<String>('name') == 'max_concurrent_executions',
          );
          if (hasLegacyConcurrencyColumn) {
            await customStatement(
              'ALTER TABLE settings DROP COLUMN max_concurrent_executions',
            );
          }
        }
        if (from < 37) {
          final folderColumns = await customSelect(
            'PRAGMA table_info(task_folders)',
          ).get();
          final names = folderColumns
              .map((row) => row.read<String>('name'))
              .toSet();
          if (names.contains('default_purpose')) {
            await customStatement(
              'ALTER TABLE task_folders DROP COLUMN default_purpose',
            );
          }
          if (names.contains('default_config_json')) {
            await customStatement(
              'ALTER TABLE task_folders DROP COLUMN default_config_json',
            );
          }
        }
        if (from < 38) {
          await _safeAddColumn(migrator, taskFolderRows, taskFolderRows.origin);
          await _safeAddColumn(
            migrator,
            taskFolderRows,
            taskFolderRows.compatibilityClass,
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
    final databasePath = join(directory.path, databaseFileName);
    final file = File(databasePath);

    /// 返回一个数据库 如果没有则创建一个
    return NativeDatabase.createInBackground(file);
  });
}
