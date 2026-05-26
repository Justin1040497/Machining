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
@DriftDatabase(tables: [SettingsRows, TaskRows])
class AppDatabase extends _$AppDatabase {
  /// 创建AppDatabase时 自动打开数据库
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.addColumn(taskRows, taskRows.mediaKind);
        }
        if (from < 3) {
          await migrator.addColumn(taskRows, taskRows.sourceFileSize);
          await migrator.addColumn(taskRows, taskRows.sourceLastModifiedAt);
          await migrator.addColumn(taskRows, taskRows.analysisDurationMs);
          await migrator.addColumn(taskRows, taskRows.analysisVideoWidth);
          await migrator.addColumn(taskRows, taskRows.analysisVideoHeight);
          await migrator.addColumn(taskRows, taskRows.analysisVideoCodec);
          await migrator.addColumn(taskRows, taskRows.analysisAudioCodec);
          await migrator.addColumn(taskRows, taskRows.analysisContainerFormat);
          await migrator.addColumn(taskRows, taskRows.analysisAudioChannels);
          await migrator.addColumn(taskRows, taskRows.analysisAudioSampleRate);
          await migrator.addColumn(taskRows, taskRows.analysisUpdatedAt);
          await migrator.addColumn(taskRows, taskRows.analysisErrorMessage);
        }
        if (from < 4) {
          await migrator.addColumn(taskRows, taskRows.analysisVideoBitrate);
          await migrator.addColumn(taskRows, taskRows.analysisContainerBitrate);
          await migrator.addColumn(taskRows, taskRows.analysisEstimatedBitrate);
        }
        if (from < 5) {
          await migrator.addColumn(taskRows, taskRows.analysisAudioBitrate);
        }
        if (from < 6) {
          await migrator.addColumn(
            settingsRows,
            settingsRows.defaultOutputVideoCodec,
          );
        }
        if (from < 7) {
          await migrator.addColumn(taskRows, taskRows.compressionCrf);
          await migrator.addColumn(taskRows, taskRows.outputFileName);
        }
        if (from < 8) {
          await migrator.addColumn(taskRows, taskRows.compressionMode);
          await migrator.addColumn(taskRows, taskRows.targetSizeRatio);
        }
        if (from < 9) {
          await migrator.addColumn(taskRows, taskRows.smartPreset);
          await migrator.addColumn(taskRows, taskRows.targetSizeBytes);
        }
        if (from < 10) {
          await migrator.addColumn(
            settingsRows,
            settingsRows.saveOutputToSourceDirectory,
          );
          await migrator.addColumn(
            settingsRows,
            settingsRows.defaultCompressionSmartPreset,
          );
          await migrator.addColumn(
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
