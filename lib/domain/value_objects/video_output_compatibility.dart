import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/video_codec.dart';

abstract final class VideoOutputCompatibility {
  static List<VideoCodec> codecsFor(OutputFormat format) {
    return switch (format) {
      OutputFormat.mp4 => const [
        VideoCodec.h264,
        VideoCodec.hevc,
        VideoCodec.av1,
      ],
      OutputFormat.mov => const [
        VideoCodec.h264,
        VideoCodec.hevc,
        VideoCodec.proRes,
      ],
      OutputFormat.mkv => const [
        VideoCodec.h264,
        VideoCodec.hevc,
        VideoCodec.vp9,
        VideoCodec.av1,
        VideoCodec.proRes,
      ],
      OutputFormat.webm => const [VideoCodec.vp9, VideoCodec.av1],
      OutputFormat.avi => const [VideoCodec.mpeg4, VideoCodec.mjpeg],
    };
  }

  static bool supports(OutputFormat format, VideoCodec codec) {
    return codecsFor(format).contains(codec);
  }

  static VideoCodec defaultCodecFor(OutputFormat format) {
    return switch (format) {
      OutputFormat.webm => VideoCodec.vp9,
      OutputFormat.avi => VideoCodec.mpeg4,
      _ => VideoCodec.h264,
    };
  }

  static bool supportsTargetSize(VideoCodec codec) {
    return codec != VideoCodec.proRes && codec != VideoCodec.mjpeg;
  }
}
