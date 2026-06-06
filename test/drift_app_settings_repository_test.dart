import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_app_settings_repository.dart';
import 'package:framelean/infrastructure/repositories/mappers/media_task_config_json_mapper.dart';

void main() {
  test('settings row maps persisted app defaults to domain', () {
    final row = SettingsRow(
      id: 1,
      defaultOutputDirectory: '/Users/leftzhou/Desktop',
      lastSelectedOutputDirectory: null,
      saveOutputToSourceDirectory: false,
      customFfmpegPath: '/opt/homebrew/bin/ffmpeg',
      customFfprobePath: '/opt/homebrew/bin/ffprobe',
      showRawLog: false,
      showAdvancedOptions: false,
      defaultOutputVideoCodec: 'hevc',
      defaultCompressionSmartPreset: 'chat',
      defaultOutputFileNameTemplate: 'sourceFileNameCodec',
      createdAt: 1,
      updatedAt: 2,
    );

    final settings = row.toDomain();

    expect(settings.defaultOutputDirectory, '/Users/leftzhou/Desktop');
    expect(settings.saveOutputToSourceDirectory, isFalse);
    expect(settings.defaultOutputVideoCodec, VideoCodec.hevc);
    expect(settings.defaultSmartPreset, SmartCompressionPreset.chat);
    expect(settings.defaultMediaConfig.video?.videoCodec, VideoCodec.hevc);
    expect(
      settings.defaultMediaConfig.video?.smartPreset,
      SmartCompressionPreset.chat,
    );
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.image), isTrue);
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.audio), isTrue);
    expect(
      settings.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.sourceFileNameCodec,
    );
  });

  test('settings row prefers default media config json over legacy fields', () {
    final mediaConfig = MediaTaskConfig.initialDefaults().copyWith(
      video: VideoProcessingConfig.initial().copyWith(
        videoCodec: VideoCodec.h264,
        smartPreset: SmartCompressionPreset.balanced,
      ),
      image: ImageProcessingConfig.initial().copyWith(imageQuality: 67),
    );
    final row = SettingsRow(
      id: 1,
      defaultOutputDirectory: null,
      lastSelectedOutputDirectory: null,
      saveOutputToSourceDirectory: true,
      customFfmpegPath: null,
      customFfprobePath: null,
      showRawLog: false,
      showAdvancedOptions: false,
      defaultOutputVideoCodec: 'hevc',
      defaultCompressionSmartPreset: 'chat',
      defaultOutputFileNameTemplate: 'sourceFileNameCodec',
      defaultMediaConfigJson: encodeMediaTaskConfig(mediaConfig),
      createdAt: 1,
      updatedAt: 2,
    );

    final settings = row.toDomain();

    expect(settings.defaultOutputVideoCodec, VideoCodec.h264);
    expect(settings.defaultSmartPreset, SmartCompressionPreset.balanced);
    expect(settings.defaultMediaConfig.image?.imageQuality, 67);
  });

  test(
    'repository saves default media config json and legacy video fields',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAppSettingsRepository(database);
      final mediaConfig = MediaTaskConfig.initialDefaults().copyWith(
        video: VideoProcessingConfig.initial().copyWith(
          videoCodec: VideoCodec.hevc,
          smartPreset: SmartCompressionPreset.chat,
        ),
        image: ImageProcessingConfig.initial().copyWith(imageQuality: 71),
      );

      await repository.saveSettings(
        AppSettings.initial().copyWith(defaultMediaConfig: mediaConfig),
      );

      final row = await database.select(database.settingsRows).getSingle();
      final savedConfig = decodeMediaTaskConfig(row.defaultMediaConfigJson!);

      expect(row.defaultOutputVideoCodec, 'hevc');
      expect(row.defaultCompressionSmartPreset, 'chat');
      expect(savedConfig.video?.videoCodec, VideoCodec.hevc);
      expect(savedConfig.image?.imageQuality, 71);
    },
  );
}
