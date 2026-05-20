import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

void main() {
  test('initial settings expose application defaults', () {
    final settings = AppSettings.initial();

    expect(settings.defaultOutputVideoCodec, VideoCodec.h264);
    expect(settings.defaultSmartPreset, SmartCompressionPreset.balanced);
    expect(settings.saveOutputToSourceDirectory, isTrue);
    expect(
      settings.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.datetimeOriginalCodec,
    );
  });

  test('copyWith can clear nullable paths and update default fields', () {
    final settings = AppSettings.initial().copyWith(
      defaultOutputDirectory: '/Users/leftzhou/Desktop',
      customFfmpegPath: '/usr/local/bin/ffmpeg',
      saveOutputToSourceDirectory: true,
      defaultSmartPreset: SmartCompressionPreset.chat,
      defaultOutputVideoCodec: VideoCodec.hevc,
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
  });
}
