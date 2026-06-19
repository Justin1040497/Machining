import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/ffmpeg_planning/media_codec_normalizer.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';

class FfmpegVideoArgumentBuilder {
  const FfmpegVideoArgumentBuilder();

  List<String> buildPurposeArgs(
    MediaTask task,
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    if (shouldPreserveAlpha(task)) {
      return const ['-c:v', 'prores_ks', '-profile:v', '4', '-qscale:v', '9'];
    }

    return switch (task.purpose) {
      TaskPurpose.compression => buildCompressionArgs(
        recommendation,
        videoEncoder,
      ),
      TaskPurpose.conversion => buildConversionArgs(videoEncoder),
    };
  }

  List<String> buildConversionArgs(String videoEncoder) {
    if (videoEncoder.endsWith('_videotoolbox')) {
      return ['-c:v', videoEncoder, '-q:v', '80'];
    }
    if (videoEncoder.endsWith('_nvenc')) {
      return [
        '-c:v',
        videoEncoder,
        '-preset',
        'p7',
        '-rc',
        'vbr',
        '-cq',
        '16',
        '-b:v',
        '0',
      ];
    }
    if (videoEncoder.endsWith('_qsv')) {
      return ['-c:v', videoEncoder, '-global_quality', '16'];
    }
    if (videoEncoder.endsWith('_amf')) {
      return [
        '-c:v',
        videoEncoder,
        '-quality',
        'quality',
        '-rc',
        'cqp',
        '-qp_i',
        '16',
        '-qp_p',
        '16',
      ];
    }
    return ['-c:v', videoEncoder, '-preset', 'slow', '-crf', '18'];
  }

  List<String> buildOutputStreamSelectionArgs(MediaTask task) {
    final metadataArgs = task.config.video?.preserveMetadata == false
        ? const ['-map_metadata', '-1']
        : const ['-map_metadata', '0:g'];

    return [
      '-map',
      '0:v:0',
      ...buildAudioStreamSelectionArgs(task),
      ...metadataArgs,
      '-map_chapters',
      '0',
    ];
  }

  List<String> buildAudioStreamSelectionArgs(MediaTask task) {
    final selectedAudioStreamIndex =
        task.config.video?.selectedAudioStreamIndex;
    if (selectedAudioStreamIndex != null && selectedAudioStreamIndex >= 0) {
      return ['-map', '0:$selectedAudioStreamIndex?'];
    }

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

  List<String> buildThreadArgs(MediaTask task) {
    final threadLimit = task.config.threadLimit;
    if (threadLimit == null) {
      return const [];
    }

    return ['-threads', threadLimit.toString()];
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
      return [
        ...baseArgs,
        '-crf',
        softwareCrfFor(recommendation.crf).toString(),
      ];
    }

    final targetVideoBitrate = recommendation.targetVideoBitrate;
    if (targetVideoBitrate == null) {
      return [
        ...baseArgs,
        '-crf',
        softwareCrfFor(recommendation.crf).toString(),
      ];
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
    final crf = recommendation.crf;

    if (videoEncoder.endsWith('_videotoolbox')) {
      final quality = videoToolboxQualityFor(crf).toString();
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
      final quality = nvencQualityFor(crf).toString();
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
      final quality = qsvQualityFor(crf).toString();
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
      final quality = amfQualityFor(crf).toString();
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
    final resolutionPreset = task.purpose == TaskPurpose.conversion
        ? ResolutionPreset.original
        : task.config.resolutionPreset;
    ensureSupportedColorInput(analysis);
    if (shouldPreserveAlpha(task)) {
      return buildPreserveAlphaFilter(resolutionPreset);
    }
    if (analysis?.isHdr == true) {
      if (shouldPreserveHdr(task)) {
        return buildPreserveHdrFilter(resolutionPreset, task);
      }
      return buildHdrToSdrFilter(resolutionPreset, analysis!);
    }

    final colorProfile = resolveOutputColorProfile(task);
    final scaleFilter = buildSoftwareScaleFilter(
      resolutionPreset,
      colorProfile,
    );
    return '$scaleFilter,format=yuv420p,setsar=1';
  }

  List<String> buildCommonOutputArgs(
    MediaTask task,
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
    String videoEncoder,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    ensureSupportedColorInput(task.analysisResult);
    if (shouldPreserveAlpha(task)) {
      return [
        '-pix_fmt',
        'yuva444p10le',
        ...buildAudioArgs(task, recommendation, encoderCapabilities),
        ...buildFrameTimingArgs(task),
        '-movflags',
        '+faststart',
      ];
    }
    final preserveHdr = shouldPreserveHdr(task);
    final args = <String>[
      '-pix_fmt',
      preserveHdr ? 'yuv420p10le' : 'yuv420p',
      ...buildColorMetadataArgs(task),
      ...buildVideoCompatibilityArgs(task, targetCodec, videoEncoder),
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

  bool shouldPreserveHdr(MediaTask task) {
    return task.analysisResult?.isHdr == true &&
        (task.purpose == TaskPurpose.conversion ||
            task.config.video?.hdrOutputMode == HdrOutputMode.preserveHdr);
  }

  bool shouldPreserveAlpha(MediaTask task) {
    final pixelFormat = task.analysisResult?.videoPixelFormat
        ?.trim()
        .toLowerCase();
    if (pixelFormat == null || pixelFormat.isEmpty) {
      return false;
    }

    return pixelFormat.startsWith('yuva') ||
        pixelFormat == 'rgba' ||
        pixelFormat == 'bgra' ||
        pixelFormat == 'argb' ||
        pixelFormat == 'abgr' ||
        pixelFormat.startsWith('gbrap');
  }

  String buildPreserveAlphaFilter(ResolutionPreset preset) {
    final size = scaleSizeExpression(preset);
    return 'scale=${size.width}:${size.height}:flags=lanczos,'
        'format=yuva444p10le,setsar=1';
  }

  String buildSoftwareScaleFilter(
    ResolutionPreset preset,
    VideoColorProfile colorProfile,
  ) {
    final size = scaleSizeExpression(preset);
    return 'scale=${size.width}:${size.height}:flags=lanczos:'
        'in_range=auto:out_range=${colorProfile.range}:'
        'in_color_matrix=auto:out_color_matrix=${colorProfile.matrix}';
  }

  String buildHdrToSdrFilter(
    ResolutionPreset preset,
    MediaAnalysisResult analysis,
  ) {
    final size = scaleSizeExpression(preset);
    final peak = formatToneMapPeak(toneMapPeakFor(analysis));
    return 'zscale=t=linear:npl=100,format=gbrpf32le,'
        'tonemap=tonemap=hable:desat=0:peak=$peak,'
        'zscale=p=bt709:t=bt709:m=bt709:r=tv,'
        'scale=${size.width}:${size.height}:flags=lanczos,'
        'format=yuv420p,setsar=1';
  }

  String buildPreserveHdrFilter(ResolutionPreset preset, MediaTask task) {
    final size = scaleSizeExpression(preset);
    return 'scale=${size.width}:${size.height}:flags=lanczos,'
        'format=yuv420p10le,setsar=1';
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

  List<String> buildColorMetadataArgs(MediaTask task) {
    final colorProfile = resolveOutputColorProfile(task);
    return [
      '-color_range',
      colorProfile.range,
      '-colorspace',
      colorProfile.matrix,
      '-color_trc',
      colorProfile.transfer,
      '-color_primaries',
      colorProfile.primaries,
    ];
  }

  VideoColorProfile resolveOutputColorProfile(MediaTask task) {
    final analysis = task.analysisResult;
    if (shouldPreserveHdr(task)) {
      return inferHdrColorProfile(analysis);
    }

    if (analysis?.isHdr == true) {
      return VideoColorProfile.bt709();
    }

    final inferredProfile = inferSdrColorProfile(analysis);
    return VideoColorProfile(
      range: normalizeColorRange(analysis?.colorRange),
      matrix:
          normalizeColorMatrix(analysis?.colorSpace) ?? inferredProfile.matrix,
      transfer:
          normalizeColorTransfer(analysis?.colorTransfer) ??
          inferredProfile.transfer,
      primaries:
          normalizeColorPrimaries(analysis?.colorPrimaries) ??
          inferredProfile.primaries,
    );
  }

  VideoColorProfile inferHdrColorProfile(MediaAnalysisResult? analysis) {
    final transfer = normalizeColorTransfer(analysis?.colorTransfer);
    return VideoColorProfile(
      range: normalizeColorRange(analysis?.colorRange),
      matrix: normalizeColorMatrix(analysis?.colorSpace) ?? 'bt2020nc',
      transfer:
          transfer ??
          (analysis?.colorTransfer?.trim().toLowerCase() == 'arib-std-b67'
              ? 'arib-std-b67'
              : 'smpte2084'),
      primaries: normalizeColorPrimaries(analysis?.colorPrimaries) ?? 'bt2020',
    );
  }

  VideoColorProfile inferSdrColorProfile(MediaAnalysisResult? analysis) {
    final height = analysis?.videoHeight ?? analysis?.imageHeight;
    if (height != null && height > 0 && height < 720) {
      return const VideoColorProfile(
        range: 'tv',
        matrix: 'smpte170m',
        transfer: 'smpte170m',
        primaries: 'smpte170m',
      );
    }

    return VideoColorProfile.bt709();
  }

  void ensureSupportedColorInput(MediaAnalysisResult? analysis) {
    if (analysis?.isUnsupportedDolbyVisionProfile != true) {
      return;
    }

    throw const FfmpegCommandBuildException(
      '暂不支持 Dolby Vision Profile 5 或无 HDR10 兼容层的 Dolby Vision 视频。'
      '为避免输出变黑、偏紫或严重偏色，请先用支持 Dolby Vision 的工具转换为 HDR10/SDR，'
      '或等待后续 libplacebo/libdovi 路线。',
    );
  }

  double toneMapPeakFor(MediaAnalysisResult analysis) {
    final maxContentLightLevel = analysis.maxContentLightLevel;
    if (maxContentLightLevel != null && maxContentLightLevel > 0) {
      return maxContentLightLevel / 100;
    }

    final maxLuminance = analysis.masteringDisplayMaxLuminance;
    if (maxLuminance != null && maxLuminance > 0) {
      return maxLuminance / 100;
    }

    final transfer = normalizeColorTransfer(analysis.colorTransfer);
    if (transfer == 'smpte2084') {
      return 100;
    }

    return 10;
  }

  String formatToneMapPeak(double peak) {
    final rounded = peak.roundToDouble();
    if ((peak - rounded).abs() < 0.0001) {
      return rounded.toInt().toString();
    }

    return peak.toStringAsFixed(2);
  }

  int softwareCrfFor(int crf) {
    return crf.clamp(18, 36).toInt();
  }

  int nvencQualityFor(int crf) {
    return (crf - 2).clamp(18, 34).toInt();
  }

  int qsvQualityFor(int crf) {
    return (crf - 2).clamp(18, 34).toInt();
  }

  int amfQualityFor(int crf) {
    return (crf - 2).clamp(18, 34).toInt();
  }

  int videoToolboxQualityFor(int crf) {
    return (75 - ((crf - 24) * 5)).clamp(35, 80).toInt();
  }

  String normalizeColorRange(String? value) {
    final normalized = normalizeColorValue(value);
    if (normalized == 'pc' ||
        normalized == 'jpeg' ||
        normalized == 'full' ||
        normalized == 'fullrange') {
      return 'pc';
    }

    return 'tv';
  }

  String? normalizeColorMatrix(String? value) {
    final normalized = normalizeColorValue(value);
    return switch (normalized) {
      'bt709' => 'bt709',
      'bt470bg' => 'bt470bg',
      'smpte170m' => 'smpte170m',
      'bt2020nc' || 'bt2020ncl' => 'bt2020nc',
      _ => null,
    };
  }

  String? normalizeColorTransfer(String? value) {
    final normalized = normalizeColorValue(value);
    return switch (normalized) {
      'bt709' => 'bt709',
      'bt470bg' => 'bt470bg',
      'smpte170m' => 'smpte170m',
      'smpte2084' => 'smpte2084',
      'arib-std-b67' => 'arib-std-b67',
      _ => null,
    };
  }

  String? normalizeColorPrimaries(String? value) {
    final normalized = normalizeColorValue(value);
    return switch (normalized) {
      'bt709' => 'bt709',
      'bt470bg' => 'bt470bg',
      'smpte170m' => 'smpte170m',
      'bt2020' => 'bt2020',
      _ => null,
    };
  }

  String? normalizeColorValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized == 'unknown' ||
        normalized == 'unspecified' ||
        normalized == 'reserved' ||
        normalized == 'reserved0') {
      return null;
    }

    return normalized;
  }

  List<String> buildVideoCompatibilityArgs(
    MediaTask task,
    VideoCodec targetCodec,
    String videoEncoder,
  ) {
    final args = <String>[];
    if (targetCodec == VideoCodec.h264) {
      args.addAll(['-profile:v', 'high']);
    } else if (shouldPreserveHdr(task)) {
      args.addAll(['-profile:v', 'main10']);
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

    if (task.purpose == TaskPurpose.conversion) {
      final channels = task.analysisResult?.audioChannels;
      final sampleRate = targetAudioSampleRate(task);
      return [
        '-c:a',
        'aac',
        '-b:a',
        '320k',
        if (channels != null && channels > 0) ...['-ac', '$channels'],
        if (sampleRate != null) ...['-ar', '$sampleRate'],
      ];
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

class VideoColorProfile {
  final String range;
  final String matrix;
  final String transfer;
  final String primaries;

  const VideoColorProfile({
    required this.range,
    required this.matrix,
    required this.transfer,
    required this.primaries,
  });

  factory VideoColorProfile.bt709() {
    return const VideoColorProfile(
      range: 'tv',
      matrix: 'bt709',
      transfer: 'bt709',
      primaries: 'bt709',
    );
  }
}
