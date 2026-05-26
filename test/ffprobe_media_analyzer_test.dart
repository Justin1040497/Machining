import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart';

void main() {
  group('FfprobeMediaAnalyzer', () {
    test('asks ffprobe for only fields needed by the analyzer', () {
      final analyzer = FfprobeMediaAnalyzer();
      const inputPath = r'C:\Users\left\Videos\第二节课实操-口播.mp4';

      final arguments = analyzer.buildArguments(inputPath);

      expect(arguments, contains('-show_entries'));
      expect(arguments, isNot(contains('-show_format')));
      expect(arguments, isNot(contains('-show_streams')));
      expect(arguments.join(' '), contains('format=duration,bit_rate'));
      expect(arguments.join(' '), contains('stream=codec_type,codec_name'));
      expect(arguments.last, inputPath);
    });

    test('parses direct and estimated bitrate fields', () {
      final analyzer = FfprobeMediaAnalyzer();

      final result = analyzer.parseResult({
        'format': {'duration': '10.0', 'bit_rate': '1200000'},
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'h264',
            'width': 1920,
            'height': 1080,
            'bit_rate': '900000',
          },
          {'codec_type': 'audio', 'codec_name': 'aac', 'bit_rate': '128000'},
        ],
      }, fileSize: 1000000);

      expect(result.videoBitrate, 900000);
      expect(result.audioBitrate, 128000);
      expect(result.containerBitrate, 1200000);
      expect(result.estimatedBitrate, 800000);
      expect(result.preferredBitrate, 900000);
    });

    test('uses estimated bitrate when direct bitrate fields are missing', () {
      final analyzer = FfprobeMediaAnalyzer();

      final result = analyzer.parseResult({
        'format': {'duration': '20.0'},
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'h264',
            'width': 1280,
            'height': 720,
          },
        ],
      }, fileSize: 2000000);

      expect(result.videoBitrate, isNull);
      expect(result.containerBitrate, isNull);
      expect(result.estimatedBitrate, 800000);
      expect(result.preferredBitrate, 800000);
    });
  });
}
