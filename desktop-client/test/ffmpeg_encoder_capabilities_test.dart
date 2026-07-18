import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';

void main() {
  group('FfmpegEncoderCapabilities', () {
    test('detects software encoders only when FFmpeg lists them', () {
      final capabilities = FfmpegEncoderCapabilities.fromEncodersOutput(
        '''
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10
 V..... h264_videotoolbox    VideoToolbox H.264 Encoder
 V..... hevc_videotoolbox    VideoToolbox H.265 Encoder
 A....D libmp3lame           libmp3lame MP3 (MPEG audio layer 3)
 A....D aac                  AAC (Advanced Audio Coding)
 A..... aac_at               aac (AudioToolbox) (codec aac)
 A....D libopus              libopus Opus (codec opus)
 A....D pcm_s16le            PCM signed 16-bit little-endian
 A....D flac                 FLAC (Free Lossless Audio Codec)
 A....D pcm_s16be            PCM signed 16-bit big-endian
 A....D wmav2                Windows Media Audio 2
 V....D libwebp              libwebp WebP image (codec webp)
''',
        autoBackendPriority: const [EncoderBackend.videotoolbox],
      );

      expect(capabilities.encoderNames, contains('libx264'));
      expect(capabilities.encoderNames, isNot(contains('libx265')));
      expect(capabilities.encoderNames, contains('h264_videotoolbox'));
      expect(capabilities.encoderNames, contains('hevc_videotoolbox'));
      expect(capabilities.supportsAudioEncoder('libmp3lame'), isTrue);
      expect(capabilities.supportsAudioEncoder('aac'), isTrue);
      expect(capabilities.supportsAudioEncoder('aac_at'), isTrue);
      expect(capabilities.supportsAudioEncoder('libopus'), isTrue);
      expect(capabilities.supportsAudioEncoder('pcm_s16le'), isTrue);
      expect(capabilities.supportsAudioEncoder('flac'), isTrue);
      expect(capabilities.supportsAudioEncoder('pcm_s16be'), isTrue);
      expect(capabilities.supportsAudioEncoder('wmav2'), isTrue);
      expect(capabilities.supportsImageEncoder('libwebp'), isTrue);
    });

    test('assumes current bundled runtime encoders when probing fails', () {
      final capabilities = FfmpegEncoderCapabilities.assumeBundledFallback(
        autoBackendPriority: const [EncoderBackend.videotoolbox],
      );

      expect(capabilities.supportsAudioEncoder('libmp3lame'), isTrue);
      expect(capabilities.supportsAudioEncoder('libopus'), isTrue);
      expect(capabilities.supportsImageEncoder('libwebp'), isTrue);
      expect(capabilities.autoBackendPriority, const [
        EncoderBackend.videotoolbox,
      ]);
    });
  });
}
