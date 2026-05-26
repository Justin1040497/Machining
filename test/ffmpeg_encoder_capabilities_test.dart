import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:machining/domain/enums/encoder_backend.dart';

void main() {
  group('FfmpegEncoderCapabilities', () {
    test('detects software encoders only when FFmpeg lists them', () {
      final capabilities = FfmpegEncoderCapabilities.fromEncodersOutput(
        '''
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10
 V..... h264_videotoolbox    VideoToolbox H.264 Encoder
 V..... hevc_videotoolbox    VideoToolbox H.265 Encoder
''',
        autoBackendPriority: const [EncoderBackend.videotoolbox],
      );

      expect(capabilities.encoderNames, contains('libx264'));
      expect(capabilities.encoderNames, isNot(contains('libx265')));
      expect(capabilities.encoderNames, contains('h264_videotoolbox'));
      expect(capabilities.encoderNames, contains('hevc_videotoolbox'));
    });
  });
}
