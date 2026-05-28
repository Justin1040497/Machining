import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_app_settings_repository.dart';

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
    expect(
      settings.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.sourceFileNameCodec,
    );
  });
}
