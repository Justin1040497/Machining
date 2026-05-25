import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

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
    };
  }

  static String videoCodecLabel(VideoCodec codec) {
    return switch (codec) {
      VideoCodec.source => '跟随源文件',
      VideoCodec.h264 => 'H.264',
      VideoCodec.hevc => 'H.265 / HEVC',
    };
  }

  static String encoderBackendLabel(EncoderBackend backend) {
    return switch (backend) {
      EncoderBackend.auto => '自动选择',
      EncoderBackend.libx264 => 'libx264',
      EncoderBackend.libx265 => 'libx265',
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
