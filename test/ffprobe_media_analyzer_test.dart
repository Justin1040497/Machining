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
      expect(
        arguments.join(' '),
        contains('stream=index,codec_type,codec_name'),
      );
      expect(arguments.join(' '), contains('pix_fmt'));
      expect(arguments.join(' '), contains('color_transfer'));
      expect(arguments.join(' '), contains('chroma_location'));
      expect(arguments.join(' '), contains('stream_side_data=side_data_type'));
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
            'chroma_location': 'left',
            'avg_frame_rate': '30000/1001',
            'r_frame_rate': '30000/1001',
            'sample_aspect_ratio': '1:1',
            'display_aspect_ratio': '16:9',
            'field_order': 'progressive',
            'tags': {'rotate': '90'},
          },
          {
            'index': 1,
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
      expect(result.chromaLocation, 'left');
      expect(result.averageFrameRate, '30000/1001');
      expect(result.realFrameRate, '30000/1001');
      expect(result.sampleAspectRatio, '1:1');
      expect(result.displayAspectRatio, '16:9');
      expect(result.videoRotationDegrees, 90);
      expect(result.fieldOrder, 'progressive');
      expect(result.audioChannels, 2);
      expect(result.audioSampleRate, 48000);
      expect(result.audioChannelLayout, 'stereo');
      expect(result.audioStreamIndex, 1);
      expect(result.containerBitrate, 1200000);
      expect(result.estimatedBitrate, 800000);
      expect(result.preferredBitrate, 900000);
    });

    test('selects the first usable audio stream and ignores APAC', () {
      final analyzer = FfprobeMediaAnalyzer();

      final result = analyzer.parseResult({
        'format': {'duration': '10.0'},
        'streams': [
          {
            'index': 0,
            'codec_type': 'video',
            'codec_name': 'hvc1',
            'width': 3840,
            'height': 2160,
          },
          {'index': 2, 'codec_type': 'audio', 'codec_name': 'none'},
          {
            'index': 1,
            'codec_type': 'audio',
            'codec_name': 'aac',
            'bit_rate': '192000',
            'channels': 2,
            'sample_rate': '48000',
          },
        ],
      });

      expect(result.videoCodec, 'hvc1');
      expect(result.audioCodec, 'aac');
      expect(result.audioBitrate, 192000);
      expect(result.audioStreamIndex, 1);
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
              {
                'side_data_type': 'Mastering display metadata',
                'red_x': '34000/50000',
                'red_y': '16000/50000',
                'green_x': '13250/50000',
                'green_y': '34500/50000',
                'blue_x': '7500/50000',
                'blue_y': '3000/50000',
                'white_point_x': '15635/50000',
                'white_point_y': '16450/50000',
                'min_luminance': '50/10000',
                'max_luminance': '10000000/10000',
              },
              {
                'side_data_type': 'Content light level metadata',
                'max_content': 1000,
                'max_average': 400,
              },
              {
                'side_data_type': 'DOVI configuration record',
                'dv_profile': 8,
                'dv_bl_signal_compatibility_id': 1,
              },
            ],
          },
        ],
      });

      expect(result.videoBitDepth, 10);
      expect(result.videoRotationDegrees, -90);
      expect(result.masteringDisplayMetadata, contains('red_x=34000/50000'));
      expect(result.masteringDisplayMaxLuminance, 1000);
      expect(result.maxContentLightLevel, 1000);
      expect(result.maxFrameAverageLightLevel, 400);
      expect(result.dolbyVisionProfile, 8);
      expect(result.dolbyVisionCompatibilityId, 1);
      expect(result.isHdr, isTrue);
    });

    test('parses audio-only files without requiring a video stream', () {
      final analyzer = FfprobeMediaAnalyzer();

      final result = analyzer.parseResult({
        'format': {
          'duration': '3.5',
          'bit_rate': '256000',
          'format_name': 'mp3',
        },
        'streams': [
          {
            'index': 0,
            'codec_type': 'audio',
            'codec_name': 'mp3',
            'bit_rate': '192000',
            'channels': 2,
            'channel_layout': 'stereo',
            'sample_rate': '44100',
          },
        ],
      }, fileSize: 112000);

      expect(result.durationMs, 3500);
      expect(result.videoCodec, isNull);
      expect(result.videoWidth, isNull);
      expect(result.audioCodec, 'mp3');
      expect(result.audioBitrate, 192000);
      expect(result.audioChannels, 2);
      expect(result.audioSampleRate, 44100);
      expect(result.audioChannelLayout, 'stereo');
      expect(result.audioStreamIndex, 0);
      expect(result.containerFormat, 'mp3');
      expect(result.preferredBitrate, 192000);
    });

    test('parses static image metadata from a video-type stream', () {
      final analyzer = FfprobeMediaAnalyzer();

      final result = analyzer.parseResult({
        'format': {'format_name': 'png_pipe'},
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'png',
            'width': 1200,
            'height': 800,
            'pix_fmt': 'rgba',
            'bits_per_raw_sample': '8',
            'side_data_list': [
              {'rotation': 180},
            ],
          },
        ],
      });

      expect(result.durationMs, isNull);
      expect(result.imageWidth, 1200);
      expect(result.imageHeight, 800);
      expect(result.imageCodec, 'png');
      expect(result.imagePixelFormat, 'rgba');
      expect(result.imageBitDepth, 8);
      expect(result.orientationDegrees, 180);
      expect(result.containerFormat, 'png_pipe');
    });
  });
}
