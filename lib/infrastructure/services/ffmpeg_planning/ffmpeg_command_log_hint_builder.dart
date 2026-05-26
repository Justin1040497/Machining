import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';

class FfmpegCommandLogHintBuilder {
  const FfmpegCommandLogHintBuilder();

  String buildLogHint(
    MediaTask task,
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
    String videoEncoder,
  ) {
    return switch (task.purpose) {
      TaskPurpose.compression => buildCompressionLogHint(
        recommendation,
        targetCodec,
        videoEncoder,
        task.config.resolutionPreset,
      ),
      TaskPurpose.conversion =>
        '使用 ${FfmpegCommandFormatters.videoCodecLabel(targetCodec)} / '
            '$videoEncoder 路线生成目标封装格式文件',
    };
  }

  String buildCompressionLogHint(
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
    String videoEncoder,
    ResolutionPreset resolutionPreset,
  ) {
    if (recommendation.profile == CompressionProfile.extreme ||
        recommendation.profile == CompressionProfile.targetSize) {
      final strategy =
          recommendation.profile == CompressionProfile.targetSize &&
              !FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(
                videoEncoder,
              )
          ? '使用指定目标体积两遍压缩策略'
          : recommendation.message;
      return '$strategy，目标分辨率 '
          '${FfmpegCommandFormatters.resolutionPresetLabel(resolutionPreset)}，'
          '目标编码 ${FfmpegCommandFormatters.videoCodecLabel(targetCodec)} / '
          '$videoEncoder，'
          '目标视频码率 '
          '${FfmpegCommandFormatters.formatBitrate(recommendation.targetVideoBitrate!)}，'
          '目标音频码率 '
          '${FfmpegCommandFormatters.formatBitrate(recommendation.targetAudioBitrate!)}';
    }

    return '${recommendation.message}，'
        '使用 ${FfmpegCommandFormatters.videoCodecLabel(targetCodec)} / '
        '$videoEncoder CRF ${recommendation.crf} 生成输出文件';
  }
}
