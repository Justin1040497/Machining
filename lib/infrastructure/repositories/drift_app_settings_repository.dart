import 'package:drift/drift.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/media_processing_preset.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/app_compression_settings.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/mappers/media_task_config_json_mapper.dart'
    as media_config_json;

/// 用 Drift + SQLite 实现应用设置的读取和保存
class DriftAppSettingsRepository implements AppSettingsRepository {
  /// settings 表只保存一份全局设置，所以固定使用 id = 1
  static const settingsId = 1;

  final AppDatabase database;

  /// 这里把数据库对象当作参数传进来 是因为要保证这个数据库对象是唯一的 是由外面用一个实例统一管理的 而不是每个Repository都创建一个
  DriftAppSettingsRepository(this.database);

  @override
  Future<AppSettings> loadSettings() async {
    final row = await (database.select(
      database.settingsRows,
    )..where((table) => table.id.equals(settingsId))).getSingleOrNull();

    if (row == null) {
      /// 如果没有在数据库获取到数据 那就返回一个默认的设置
      return AppSettings.initial();
    }

    return row.toDomain();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (database.select(
      database.settingsRows,
    )..where((table) => table.id.equals(settingsId))).getSingleOrNull();

    /// Value是字段包装器 比如Value(null) 表示即使这个字段我填写的null 也要更新到数据库
    /// 如果这个字段不传 就是不更新 这么写就是保证当前这个字段参与本次更新
    await database
        .into(database.settingsRows)
        .insertOnConflictUpdate(
          SettingsRowsCompanion(
            id: const Value(settingsId),
            defaultOutputDirectory: Value(settings.defaultOutputDirectory),
            lastSelectedOutputDirectory: Value(
              settings.lastSelectedOutputDirectory,
            ),
            saveOutputToSourceDirectory: Value(
              settings.saveOutputToSourceDirectory,
            ),
            customFfmpegPath: Value(settings.customFfmpegPath),
            customFfprobePath: Value(settings.customFfprobePath),
            showRawLog: Value(settings.showRawLog),
            showAdvancedOptions: Value(settings.showAdvancedOptions),
            defaultOutputVideoCodec: Value(
              settings.defaultOutputVideoCodec.name,
            ),
            defaultCompressionSmartPreset: Value(
              settings.defaultSmartPreset.name,
            ),
            defaultOutputFileNameTemplate: Value(
              settings.defaultOutputFileNameTemplate,
            ),
            defaultMediaConfigJson: Value(
              media_config_json.encodeMediaTaskConfig(
                settings.defaultMediaConfig,
              ),
            ),
            themeMode: Value(settings.themeMode.name),
            hideNotificationBadge: Value(settings.hideNotificationBadge),
            showTaskCompletionDialog: Value(settings.showTaskCompletionDialog),
            taskCompletionSound: Value(settings.taskCompletionSound.id),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }
}

/// 数据库Setting表转AppSetting实体类
extension SettingsRowMapper on SettingsRow {
  AppSettings toDomain() {
    final defaultMediaConfig = defaultMediaConfigJson;
    if (defaultMediaConfig != null && defaultMediaConfig.isNotEmpty) {
      final decodedDefaultMediaConfig = media_config_json.decodeMediaTaskConfig(
        defaultMediaConfig,
      );
      return AppSettings(
        defaultOutputDirectory: defaultOutputDirectory,
        lastSelectedOutputDirectory: lastSelectedOutputDirectory,
        saveOutputToSourceDirectory: saveOutputToSourceDirectory,
        customFfmpegPath: customFfmpegPath,
        customFfprobePath: customFfprobePath,
        showRawLog: showRawLog,
        showAdvancedOptions: showAdvancedOptions,
        defaultMediaConfig: upgradeLegacyInitialDefaultMediaConfig(
          decodedDefaultMediaConfig,
        ),
        defaultOutputFileNameTemplate: outputFileNameTemplateFromSettings(
          defaultOutputFileNameTemplate,
        ),
        themeMode: appThemeModeFromSettings(themeMode),
        hideNotificationBadge: hideNotificationBadge,
        showTaskCompletionDialog: showTaskCompletionDialog,
        taskCompletionSound: TaskCompletionSound.fromId(taskCompletionSound),
      );
    }

    return AppSettings(
      defaultOutputDirectory: defaultOutputDirectory,
      lastSelectedOutputDirectory: lastSelectedOutputDirectory,
      saveOutputToSourceDirectory: saveOutputToSourceDirectory,
      customFfmpegPath: customFfmpegPath,
      customFfprobePath: customFfprobePath,
      showRawLog: showRawLog,
      showAdvancedOptions: showAdvancedOptions,
      compressionSettings: AppCompressionSettings(
        defaultOutputVideoCodec: enumValueByNameInSettings(
          VideoCodec.values,
          defaultOutputVideoCodec,
        ),
        defaultSmartPreset: enumValueByNameInSettings(
          SmartCompressionPreset.values,
          defaultCompressionSmartPreset,
        ),
      ),
      defaultOutputFileNameTemplate: outputFileNameTemplateFromSettings(
        defaultOutputFileNameTemplate,
      ),
      themeMode: appThemeModeFromSettings(themeMode),
      hideNotificationBadge: hideNotificationBadge,
      showTaskCompletionDialog: showTaskCompletionDialog,
      taskCompletionSound: TaskCompletionSound.fromId(taskCompletionSound),
    );
  }
}

MediaTaskConfig upgradeLegacyInitialDefaultMediaConfig(MediaTaskConfig config) {
  if (!_isLegacyInitialDefaultMediaConfig(config)) {
    return config;
  }

  return MediaTaskConfig.initialDefaults();
}

bool _isLegacyInitialDefaultMediaConfig(MediaTaskConfig config) {
  final video = config.video;
  final image = config.image;
  final audio = config.audio;

  return config.outputDirectory.isEmpty &&
      config.outputFileName.isEmpty &&
      config.compressionMode == CompressionMode.preset &&
      config.preset == MediaProcessingPreset.balanced &&
      config.targetSizeBytes == null &&
      config.targetSizeRatio == null &&
      video != null &&
      video.outputFormat == MediaOutputFormat.mp4 &&
      !video.keepOriginalOutputFormat &&
      video.videoCodec == VideoCodec.h264 &&
      video.encoderBackend == EncoderBackend.auto &&
      video.hdrOutputMode == HdrOutputMode.convertToSdr &&
      video.videoCodecBeforePreserveHdr == null &&
      video.encoderBackendBeforePreserveHdr == null &&
      video.resolutionPreset == ResolutionPreset.original &&
      video.compressionCrf == 28 &&
      video.smartPreset == SmartCompressionPreset.balanced &&
      video.preserveMetadata &&
      image != null &&
      image.outputFormat == MediaOutputFormat.jpg &&
      !image.keepOriginalOutputFormat &&
      image.imageQuality == 100 &&
      image.resizePreset == ImageResizePreset.original &&
      !image.preserveMetadata &&
      audio != null &&
      audio.outputFormat == MediaOutputFormat.m4a &&
      !audio.keepOriginalOutputFormat &&
      audio.bitratePreset == AudioBitratePreset.k192 &&
      audio.sampleRate == AudioSampleRatePreset.source &&
      audio.channels == AudioChannelsPreset.source &&
      audio.preserveMetadata;
}

AppThemeMode appThemeModeFromSettings(String name) {
  for (final value in AppThemeMode.values) {
    if (value.name == name) {
      return value;
    }
  }

  return AppThemeMode.system;
}

T enumValueByNameInSettings<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  throw StateError('未知的枚举值: $name');
}

String outputFileNameTemplateFromSettings(String value) {
  return switch (value) {
    'sourceFileNameCodec' => defaultOutputFileNameTemplatePattern,
    'sourceFileNameDateCodec' => defaultOutputFileNameTemplatePattern,
    'sourceFileNameCompression' => '{source}-{action}',
    'sourceFileNameCompressed' => '{source}-{action}',
    'sourceFileNameOnly' => '{source}',
    _ => normalizeDefaultOutputFileNameTemplate(value),
  };
}
