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
      expect(arguments.join(' '), contains('pix_fmt'));
      expect(arguments.join(' '), contains('color_transfer'));
      expect(arguments.join(' '), contains('avg_frame_rate'));
      expect(arguments.join(' '), contains('stream_tags=rotate'));
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
            'pix_fmt': 'yuv420p10le',
            'color_range': 'tv',
            'color_space': 'bt709',
            'color_transfer': 'bt709',
            'color_primaries': 'bt709',
            'avg_frame_rate': '30000/1001',
            'r_frame_rate': '30000/1001',
            'sample_aspect_ratio': '1:1',
            'display_aspect_ratio': '16:9',
            'field_order': 'progressive',
            'tags': {'rotate': '90'},
          },
          {
            'codec_type': 'audio',
            'codec_name': 'aac',
            'bit_rate': '128000',
            'channels': 2,
            'channel_layout': 'stereo',
            'sample_rate': '48000',
          },
        ],
      }, fileSize: 1000000);

      expect(result.videoBitrate, 900000);
      expect(result.audioBitrate, 128000);
      expect(result.videoPixelFormat, 'yuv420p10le');
      expect(result.videoBitDepth, 10);
      expect(result.colorRange, 'tv');
      expect(result.colorSpace, 'bt709');
      expect(result.colorTransfer, 'bt709');
      expect(result.colorPrimaries, 'bt709');
      expect(result.averageFrameRate, '30000/1001');
      expect(result.realFrameRate, '30000/1001');
      expect(result.sampleAspectRatio, '1:1');
      expect(result.displayAspectRatio, '16:9');
      expect(result.videoRotationDegrees, 90);
      expect(result.fieldOrder, 'progressive');
      expect(result.audioChannels, 2);
      expect(result.audioSampleRate, 48000);
      expect(result.audioChannelLayout, 'stereo');
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

    test('detects HDR metadata from video stream color fields', () {
      final analyzer = FfprobeMediaAnalyzer();

      final result = analyzer.parseResult({
        'format': {'duration': '5.0'},
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'hevc',
            'width': 3840,
            'height': 2160,
            'pix_fmt': 'p010le',
            'color_space': 'bt2020nc',
            'color_transfer': 'smpte2084',
            'color_primaries': 'bt2020',
            'side_data_list': [
              {'rotation': -90},
            ],
          },
        ],
      });

      expect(result.videoBitDepth, 10);
      expect(result.videoRotationDegrees, -90);
      expect(result.isHdr, isTrue);
    });
  });
}
