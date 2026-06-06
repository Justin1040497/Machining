import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';

void main() {
  group('buildInitialTaskConfigFromSettings', () {
    test('uses image defaults from app media config', () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputDirectory: '/tmp/output',
        saveOutputToSourceDirectory: false,
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          image: ImageProcessingConfig.initial().copyWith(imageQuality: 61),
        ),
      );

      final config = buildInitialTaskConfigFromSettings(
        sourceFileName: 'photo.png',
        mediaKind: MediaKind.image,
        settings: settings,
        now: DateTime(2026),
      );

      expect(config.outputDirectory, '/tmp/output');
      expect(config.outputFileName, 'photo-image');
      expect(config.video, isNull);
      expect(config.audio, isNull);
      expect(config.image?.imageQuality, 61);
    });

    test('uses audio defaults from app media config', () {
      final settings = AppSettings.initial().copyWith(
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          audio: AudioProcessingConfig.initial().copyWith(
            bitratePreset: AudioBitratePreset.k128,
          ),
        ),
      );

      final config = buildInitialTaskConfigFromSettings(
        sourceFileName: 'track.wav',
        mediaKind: MediaKind.audio,
        settings: settings,
        now: DateTime(2026),
      );

      expect(config.outputDirectory, isEmpty);
      expect(config.outputFileName, 'track-audio');
      expect(config.video, isNull);
      expect(config.image, isNull);
      expect(config.audio?.bitratePreset, AudioBitratePreset.k128);
    });
  });
}
