import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/media_codec_normalizer.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';

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

  List<String> buildOutputStreamSelectionArgs(MediaTask task) {
    return [
      '-map',
      '0:v:0',
      ...buildAudioStreamSelectionArgs(task),
      '-map_metadata',
      '0:g',
      '-map_chapters',
      '0',
    ];
  }

  List<String> buildAudioStreamSelectionArgs(MediaTask task) {
    final analysis = task.analysisResult;
    if (analysis == null) {
      return const ['-map', '0:a:0?'];
    }

    final audioStreamIndex = analysis.audioStreamIndex;
    if (audioStreamIndex != null && audioStreamIndex >= 0) {
      return ['-map', '0:$audioStreamIndex?'];
    }

    if (MediaCodecNormalizer.isUsableAudioForTranscode(analysis.audioCodec)) {
      return const ['-map', '0:a:0?'];
    }

    return const [];
  }

  List<String> buildVideoOnlyStreamSelectionArgs() {
    return const ['-map', '0:v:0'];
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

  List<String> buildVideoFilterArgs(MediaTask task, String videoEncoder) {
    return ['-vf', buildVideoFilter(task, videoEncoder)];
  }

  String buildVideoFilter(MediaTask task, String videoEncoder) {
    final analysis = task.analysisResult;
    final scaleFilter =
        analysis?.isHdr == true && videoEncoder.endsWith('_videotoolbox')
        ? buildVideoToolboxScaleFilter(task.config.resolutionPreset)
        : buildSoftwareScaleFilter(task.config.resolutionPreset);

    return '$scaleFilter,format=yuv420p,setsar=1';
  }

  List<String> buildCommonOutputArgs(
    MediaTask task,
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
    String videoEncoder,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    final args = <String>[
      '-pix_fmt',
      'yuv420p',
      ...buildColorMetadataArgs(),
      ...buildVideoCompatibilityArgs(targetCodec, videoEncoder),
      ...buildAudioArgs(task, recommendation, encoderCapabilities),
      ...buildFrameTimingArgs(task),
    ];

    if (targetCodec == VideoCodec.hevc &&
        (task.config.outputFormat == OutputFormat.mp4 ||
            task.config.outputFormat == OutputFormat.mov)) {
      args.addAll(['-tag:v', 'hvc1']);
    }

    if (task.config.outputFormat == OutputFormat.mp4 ||
        task.config.outputFormat == OutputFormat.mov) {
      args.addAll(['-movflags', '+faststart']);
    }

    return args;
  }

  String buildSoftwareScaleFilter(ResolutionPreset preset) {
    final size = scaleSizeExpression(preset);
    return 'scale=${size.width}:${size.height}:flags=lanczos:'
        'in_range=auto:out_range=tv:'
        'in_color_matrix=auto:out_color_matrix=bt709';
  }

  String buildVideoToolboxScaleFilter(ResolutionPreset preset) {
    final size = scaleSizeExpression(preset);
    return 'scale_vt=w=${size.width}:h=${size.height}:'
        'color_matrix=bt709:color_primaries=bt709:color_transfer=bt709';
  }

  ({String width, String height}) scaleSizeExpression(ResolutionPreset preset) {
    final targetHeight = switch (preset) {
      ResolutionPreset.original => null,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };

    if (targetHeight == null) {
      return (width: 'trunc(iw/2)*2', height: 'trunc(ih/2)*2');
    }

    return (width: '-2', height: 'trunc(min($targetHeight\\,ih)/2)*2');
  }

  List<String> buildColorMetadataArgs() {
    return const [
      '-color_range',
      'tv',
      '-colorspace',
      'bt709',
      '-color_trc',
      'bt709',
      '-color_primaries',
      'bt709',
    ];
  }

  List<String> buildVideoCompatibilityArgs(
    VideoCodec targetCodec,
    String videoEncoder,
  ) {
    final args = <String>[];
    if (targetCodec == VideoCodec.h264) {
      args.addAll(['-profile:v', 'high']);
    } else {
      args.addAll(['-profile:v', 'main']);
    }

    if (videoEncoder.endsWith('_videotoolbox')) {
      args.addAll(['-power_efficient', '1']);
    }

    return args;
  }

  List<String> buildAudioArgs(
    MediaTask task,
    CompressionRecommendation recommendation,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    if (recommendation.targetAudioBitrate == 0) {
      return const ['-an'];
    }

    final audioBitrate = recommendation.targetAudioBitrate == null
        ? '128k'
        : FfmpegCommandFormatters.formatBitrate(
            recommendation.targetAudioBitrate!,
          );
    final channels = targetAudioChannels(task, recommendation);
    final sampleRate = targetAudioSampleRate(task);

    return [
      '-c:a',
      'aac',
      '-b:a',
      audioBitrate,
      if (channels != null) ...['-ac', channels.toString()],
      if (sampleRate != null) ...['-ar', sampleRate.toString()],
    ];
  }

  List<String> buildFrameTimingArgs(MediaTask task) {
    final analysis = task.analysisResult;
    if (analysis?.averageFrameRate == null && analysis?.realFrameRate == null) {
      return const [];
    }

    return const ['-fps_mode', 'passthrough'];
  }

  int? targetAudioChannels(
    MediaTask task,
    CompressionRecommendation recommendation,
  ) {
    final targetAudioBitrate = recommendation.targetAudioBitrate;
    if (targetAudioBitrate != null && targetAudioBitrate <= 48000) {
      return 1;
    }

    final sourceChannels = task.analysisResult?.audioChannels;
    if (sourceChannels == null || sourceChannels <= 0) {
      return null;
    }

    return sourceChannels > 2 ? 2 : sourceChannels;
  }

  int? targetAudioSampleRate(MediaTask task) {
    final sampleRate = task.analysisResult?.audioSampleRate;
    if (sampleRate == null || sampleRate <= 0) {
      return null;
    }

    if (sampleRate >= 8000 && sampleRate <= 96000) {
      return sampleRate;
    }

    return 48000;
  }
}
