import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';

void main() {
  test('initial settings expose application defaults', () {
    final settings = AppSettings.initial();

    expect(settings.defaultOutputVideoCodec, VideoCodec.h264);
    expect(settings.defaultSmartPreset, SmartCompressionPreset.chat);
    expect(settings.saveOutputToSourceDirectory, isTrue);
    expect(
      settings.defaultOutputFileNameTemplate,
      defaultOutputFileNameTemplatePattern,
    );
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.video), isTrue);
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.image), isTrue);
    expect(settings.defaultMediaConfig.isValidFor(MediaKind.audio), isTrue);
    expect(settings.defaultMediaConfig.video?.keepOriginalOutputFormat, isTrue);
    expect(
      settings.defaultMediaConfig.video?.smartPreset,
      SmartCompressionPreset.chat,
    );
    expect(settings.defaultMediaConfig.image?.keepOriginalOutputFormat, isTrue);
    expect(settings.defaultMediaConfig.image?.imageQuality, 80);
    expect(settings.defaultMediaConfig.image?.preserveMetadata, isTrue);
    expect(settings.defaultMediaConfig.audio?.keepOriginalOutputFormat, isTrue);
    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.hideNotificationBadge, isTrue);
    expect(settings.taskCompletionSound, TaskCompletionSound.cleanSuccess);
    expect(settings.maxConcurrentExecutions, defaultMaxConcurrentExecutions);
  });

  test('copyWith can clear nullable output path and update defaults', () {
    final settings = AppSettings.initial().copyWith(
      defaultOutputDirectory: '/Users/leftzhou/Desktop',
      saveOutputToSourceDirectory: true,
      defaultSmartPreset: SmartCompressionPreset.chat,
      defaultOutputVideoCodec: VideoCodec.hevc,
      themeMode: AppThemeMode.dark,
      hideNotificationBadge: false,
      taskCompletionSound: TaskCompletionSound.originalSoftA,
      maxConcurrentExecutions: 3,
    );

    final cleared = settings.copyWith(
      defaultOutputDirectory: null,
      saveOutputToSourceDirectory: false,
    );

    expect(cleared.defaultOutputDirectory, isNull);
    expect(cleared.saveOutputToSourceDirectory, isFalse);
    expect(cleared.defaultSmartPreset, SmartCompressionPreset.chat);
    expect(cleared.defaultOutputVideoCodec, VideoCodec.hevc);
    expect(cleared.themeMode, AppThemeMode.dark);
    expect(cleared.hideNotificationBadge, isFalse);
    expect(cleared.taskCompletionSound, TaskCompletionSound.originalSoftA);
    expect(cleared.maxConcurrentExecutions, 3);
    expect(
      cleared.defaultMediaConfig.video?.smartPreset,
      SmartCompressionPreset.chat,
    );
    expect(cleared.defaultMediaConfig.video?.videoCodec, VideoCodec.hevc);
  });

  test('normalizes max concurrent executions to supported bounds', () {
    expect(
      AppSettings.initial()
          .copyWith(maxConcurrentExecutions: 0)
          .maxConcurrentExecutions,
      1,
    );
    expect(
      AppSettings.initial()
          .copyWith(maxConcurrentExecutions: 4)
          .maxConcurrentExecutions,
      3,
    );
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

  test(
    'normalizes empty output file name templates to the default pattern',
    () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputFileNameTemplate: '   ',
      );

      expect(
        settings.defaultOutputFileNameTemplate,
        defaultOutputFileNameTemplatePattern,
      );
    },
  );

  test('normalizes dimension separators and duplicate token prefixes', () {
    final settings = AppSettings.initial().copyWith(
      defaultOutputFileNameTemplate:
          '{source}-1920x1080-4 X 3-x{codec}-x{encoder}-x264',
    );

    expect(
      settings.defaultOutputFileNameTemplate,
      '{source}-1920×1080-4 × 3-{codec}-{encoder}-x264',
    );
  });
}
