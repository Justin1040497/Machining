import 'package:machining/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';

class FfmpegVideoArgumentBuilder {
  const FfmpegVideoArgumentBuilder();

  List<String> buildPurposeArgs(
    MediaTask task,
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    return switch (task.purpose) {
      TaskPurpose.compression => buildCompressionArgs(
        recommendation,
        videoEncoder,
      ),
      TaskPurpose.conversion => ['-c:v', videoEncoder],
    };
  }

  List<String> buildCompressionArgs(
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    if (FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(
      videoEncoder,
    )) {
      return buildHardwareCompressionArgs(recommendation, videoEncoder);
    }

    final baseArgs = <String>[
      '-c:v',
      videoEncoder,
      '-preset',
      recommendation.preset,
    ];

    if (recommendation.profile == CompressionProfile.normal) {
      return [...baseArgs, '-crf', recommendation.crf.toString()];
    }

    final targetVideoBitrate = recommendation.targetVideoBitrate;
    if (targetVideoBitrate == null) {
      return [...baseArgs, '-crf', recommendation.crf.toString()];
    }

    return [
      ...baseArgs,
      '-b:v',
      FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
      '-maxrate',
      FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
      '-bufsize',
      FfmpegCommandFormatters.formatBitrate(targetVideoBitrate * 2),
    ];
  }

  List<String> buildHardwareCompressionArgs(
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    final targetVideoBitrate = recommendation.targetVideoBitrate;
    final quality = recommendation.crf.toString();

    if (videoEncoder.endsWith('_videotoolbox')) {
      return [
        '-c:v',
        videoEncoder,
        if (targetVideoBitrate == null) ...['-q:v', quality],
        if (targetVideoBitrate != null) ...[
          '-b:v',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
        ],
      ];
    }

    if (videoEncoder.endsWith('_nvenc')) {
      return [
        '-c:v',
        videoEncoder,
        '-preset',
        'p5',
        '-rc',
        'vbr',
        if (targetVideoBitrate == null) ...['-cq', quality, '-b:v', '0'],
        if (targetVideoBitrate != null) ...[
          '-b:v',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
          '-maxrate',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
          '-bufsize',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate * 2),
        ],
      ];
    }

    if (videoEncoder.endsWith('_qsv')) {
      return [
        '-c:v',
        videoEncoder,
        if (targetVideoBitrate == null) ...['-global_quality', quality],
        if (targetVideoBitrate != null) ...[
          '-b:v',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
          '-maxrate',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
          '-bufsize',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate * 2),
        ],
      ];
    }

    if (videoEncoder.endsWith('_amf')) {
      return [
        '-c:v',
        videoEncoder,
        '-quality',
        'balanced',
        if (targetVideoBitrate == null) ...[
          '-rc',
          'cqp',
          '-qp_i',
          quality,
          '-qp_p',
          quality,
        ],
        if (targetVideoBitrate != null) ...[
          '-rc',
          'vbr_peak',
          '-b:v',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
          '-maxrate',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
          '-bufsize',
          FfmpegCommandFormatters.formatBitrate(targetVideoBitrate * 2),
        ],
      ];
    }

    return ['-c:v', videoEncoder];
  }

  List<String> buildResolutionArgs(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.original => const [],
      ResolutionPreset.p2160 => const ['-vf', 'scale=-2:2160'],
      ResolutionPreset.p1080 => const ['-vf', 'scale=-2:1080'],
      ResolutionPreset.p720 => const ['-vf', 'scale=-2:720'],
      ResolutionPreset.p480 => const ['-vf', 'scale=-2:480'],
    };
  }

  List<String> buildCommonOutputArgs(
    OutputFormat outputFormat,
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
  ) {
    final audioBitrate = recommendation.targetAudioBitrate == null
        ? '128k'
        : FfmpegCommandFormatters.formatBitrate(
            recommendation.targetAudioBitrate!,
          );
    final args = <String>[
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      audioBitrate,
    ];

    if (targetCodec == VideoCodec.hevc &&
        (outputFormat == OutputFormat.mp4 ||
            outputFormat == OutputFormat.mov)) {
      args.addAll(['-tag:v', 'hvc1']);
    }

    if (outputFormat == OutputFormat.mp4 || outputFormat == OutputFormat.mov) {
      args.addAll(['-movflags', '+faststart']);
    }

    return args;
  }
}
