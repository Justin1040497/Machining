import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';

void main() {
  test('initial settings expose application defaults', () {
    final settings = AppSettings.initial();

    expect(settings.defaultOutputVideoCodec, VideoCodec.h264);
    expect(settings.defaultSmartPreset, SmartCompressionPreset.balanced);
    expect(settings.saveOutputToSourceDirectory, isTrue);
    expect(
      settings.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.sourceFileNameCodec,
    );
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.video), isTrue);
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.image), isTrue);
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.audio), isTrue);
    expect(settings.defaultMediaConfig.image?.imageQuality, 100);
    expect(settings.defaultMediaConfig.image?.preserveMetadata, isFalse);
    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.hideNotificationBadge, isTrue);
  });

  test('copyWith can clear nullable paths and update default fields', () {
    final settings = AppSettings.initial().copyWith(
      defaultOutputDirectory: '/Users/leftzhou/Desktop',
      customFfmpegPath: '/usr/local/bin/ffmpeg',
      saveOutputToSourceDirectory: true,
      defaultSmartPreset: SmartCompressionPreset.chat,
      defaultOutputVideoCodec: VideoCodec.hevc,
      themeMode: AppThemeMode.dark,
      hideNotificationBadge: false,
    );

    final cleared = settings.copyWith(
      defaultOutputDirectory: null,
      customFfmpegPath: null,
      saveOutputToSourceDirectory: false,
    );

    expect(cleared.defaultOutputDirectory, isNull);
    expect(cleared.customFfmpegPath, isNull);
    expect(cleared.saveOutputToSourceDirectory, isFalse);
    expect(cleared.defaultSmartPreset, SmartCompressionPreset.chat);
    expect(cleared.defaultOutputVideoCodec, VideoCodec.hevc);
    expect(cleared.themeMode, AppThemeMode.dark);
    expect(cleared.hideNotificationBadge, isFalse);
    expect(
      cleared.defaultMediaConfig.video?.smartPreset,
      SmartCompressionPreset.chat,
    );
    expect(cleared.defaultMediaConfig.video?.videoCodec, VideoCodec.hevc);
  });

  test('default media config updates legacy video getters', () {
    final mediaConfig = MediaTaskConfig.initialDefaults().copyWith(
      video: VideoProcessingConfig.initial().copyWith(
        videoCodec: VideoCodec.hevc,
        smartPreset: SmartCompressionPreset.chat,
      ),
      image: ImageProcessingConfig.initial().copyWith(imageQuality: 64),
      audio: AudioProcessingConfig.initial(),
    );

    final settings = AppSettings.initial().copyWith(
      defaultMediaConfig: mediaConfig,
    );
    final imageConfig = settings.defaultMediaConfig.forKind(MediaKind.image);

    expect(settings.defaultOutputVideoCodec, VideoCodec.hevc);
    expect(settings.defaultSmartPreset, SmartCompressionPreset.chat);
    expect(imageConfig.video, isNull);
    expect(imageConfig.image?.imageQuality, 64);
  });
}
