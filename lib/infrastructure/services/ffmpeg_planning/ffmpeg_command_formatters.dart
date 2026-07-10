import 'package:framelean/domain/library.dart';

abstract final class FfmpegCommandFormatters {
  static String formatBitrate(int bitrate) {
    if (bitrate % 1000000 == 0) {
      return '${bitrate ~/ 1000000}M';
    }

    return '${(bitrate / 1000).round()}k';
  }

  static String formatSeconds(double seconds) {
    if (seconds <= 0) {
      return '0';
    }

    return seconds.toStringAsFixed(3);
  }

  static String extensionFor(OutputFormat outputFormat) {
    return switch (outputFormat) {
      OutputFormat.mp4 => '.mp4',
      OutputFormat.mov => '.mov',
      OutputFormat.mkv => '.mkv',
      OutputFormat.webm => '.webm',
      OutputFormat.avi => '.avi',
    };
  }

  static String videoCodecLabel(VideoCodec codec) {
    return switch (codec) {
      VideoCodec.source => '跟随源文件',
      VideoCodec.h264 => 'H.264',
      VideoCodec.hevc => 'H.265 / HEVC',
      VideoCodec.vp9 => 'VP9',
      VideoCodec.av1 => 'AV1',
      VideoCodec.proRes => 'Apple ProRes',
      VideoCodec.mpeg4 => 'MPEG-4 Part 2',
      VideoCodec.mjpeg => 'Motion JPEG',
    };
  }

  static String encoderBackendLabel(EncoderBackend backend) {
    return switch (backend) {
      EncoderBackend.auto => '自动选择',
      EncoderBackend.libx264 => 'libx264',
      EncoderBackend.libx265 => 'libx265',
      EncoderBackend.libvpxVp9 => 'libvpx-vp9',
      EncoderBackend.libsvtav1 => 'SVT-AV1',
      EncoderBackend.proresKs => 'ProRes KS',
      EncoderBackend.nativeMpeg4 => 'MPEG-4',
      EncoderBackend.nativeMjpeg => 'MJPEG',
      EncoderBackend.videotoolbox => 'VideoToolbox',
      EncoderBackend.nvenc => 'NVIDIA NVENC',
      EncoderBackend.qsv => 'Intel Quick Sync',
      EncoderBackend.amf => 'AMD AMF',
    };
  }

  static String resolutionPresetLabel(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.original => '保持原始',
      ResolutionPreset.p2160 => '3840x2160',
      ResolutionPreset.p1080 => '1920x1080',
      ResolutionPreset.p720 => '1280x720',
      ResolutionPreset.p480 => '854x480',
    };
  }
}
