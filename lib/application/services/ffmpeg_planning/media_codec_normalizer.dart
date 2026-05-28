import 'package:framelean/domain/enums/video_codec.dart';

class MediaCodecNormalizer {
  const MediaCodecNormalizer._();

  static String? normalize(String? codec) {
    final normalized = codec?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static bool isH264(String? codec) {
    return switch (normalize(codec)) {
      'h264' || 'avc1' => true,
      _ => false,
    };
  }

  static bool isHevc(String? codec) {
    return switch (normalize(codec)) {
      'hevc' || 'h265' || 'hvc1' || 'hev1' => true,
      _ => false,
    };
  }

  static VideoCodec? videoCodecForSource(String? codec) {
    if (isH264(codec)) {
      return VideoCodec.h264;
    }
    if (isHevc(codec)) {
      return VideoCodec.hevc;
    }
    return null;
  }

  static bool isUsableAudioForTranscode(String? codec) {
    return switch (normalize(codec)) {
      null || 'none' || 'apac' => false,
      _ => true,
    };
  }
}
