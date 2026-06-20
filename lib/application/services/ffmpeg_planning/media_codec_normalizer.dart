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

  static bool isVp9(String? codec) => normalize(codec) == 'vp9';

  static bool isAv1(String? codec) => normalize(codec) == 'av1';

  static bool isProRes(String? codec) =>
      normalize(codec)?.startsWith('prores') == true;

  static bool isMpeg4(String? codec) {
    return switch (normalize(codec)) {
      'mpeg4' || 'mp4v' => true,
      _ => false,
    };
  }

  static bool isMjpeg(String? codec) => normalize(codec) == 'mjpeg';

  static VideoCodec? videoCodecForSource(String? codec) {
    if (isH264(codec)) {
      return VideoCodec.h264;
    }
    if (isHevc(codec)) {
      return VideoCodec.hevc;
    }
    if (isVp9(codec)) {
      return VideoCodec.vp9;
    }
    if (isAv1(codec)) {
      return VideoCodec.av1;
    }
    if (isProRes(codec)) {
      return VideoCodec.proRes;
    }
    if (isMpeg4(codec)) {
      return VideoCodec.mpeg4;
    }
    if (isMjpeg(codec)) {
      return VideoCodec.mjpeg;
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
