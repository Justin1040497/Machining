import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';

class FfmpegEncoderResolver {
  const FfmpegEncoderResolver();

  void ensureSupportedTask(
    MediaTask task,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    if (task.mediaKind != MediaKind.video) {
      throw const FfmpegCommandBuildException('视频编码器解析只支持视频任务');
    }

    resolveTargetVideoCodec(task);
    resolveVideoEncoderForTask(
      task: task,
      targetCodec: resolveTargetVideoCodec(task),
      backend: task.config.encoderBackend,
      encoderCapabilities: encoderCapabilities,
    );
  }

  VideoCodec resolveTargetVideoCodec(MediaTask task) {
    if (shouldPreserveHdr(task)) {
      return VideoCodec.hevc;
    }

    if (task.purpose == TaskPurpose.conversion) {
      final sourceCodec = MediaCodecNormalizer.normalize(
        task.analysisResult?.videoCodec,
      );
      final sourceVideoCodec = sourceCodec == null
          ? null
          : MediaCodecNormalizer.videoCodecForSource(sourceCodec);
      if (sourceVideoCodec != null) {
        final outputFormat = task.config.outputFormat;
        return VideoOutputCompatibility.supports(outputFormat, sourceVideoCodec)
            ? sourceVideoCodec
            : VideoOutputCompatibility.defaultCodecFor(outputFormat);
      }
    }

    final configuredCodec = task.config.videoCodec;
    if (configuredCodec != VideoCodec.source) {
      return configuredCodec;
    }

    final sourceCodec = MediaCodecNormalizer.normalize(
      task.analysisResult?.videoCodec,
    );
    if (sourceCodec == null) {
      throw const FfmpegCommandBuildException('无法识别源视频编码，不能默认保留原编码');
    }

    final targetCodec = MediaCodecNormalizer.videoCodecForSource(sourceCodec);
    if (targetCodec != null) {
      return targetCodec;
    }

    throw FfmpegCommandBuildException('暂不支持保留源视频编码: $sourceCodec');
  }

  String resolveVideoEncoderForTask({
    required MediaTask task,
    required VideoCodec targetCodec,
    required EncoderBackend backend,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    return resolveVideoEncoder(
      targetCodec: targetCodec,
      backend: resolveEffectiveBackend(
        task: task,
        targetCodec: targetCodec,
        backend: backend,
        encoderCapabilities: encoderCapabilities,
      ),
      encoderCapabilities: encoderCapabilities,
    );
  }

  String resolveVideoEncoder({
    required VideoCodec targetCodec,
    required EncoderBackend backend,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    try {
      return encoderCapabilities.resolveEncoderName(
        targetCodec: targetCodec,
        backend: backend,
      );
    } on SourceCodecNotResolvedException {
      throw const FfmpegCommandBuildException('source 必须先解析成具体目标编码');
    } on IncompatibleEncoderBackendException {
      throw FfmpegCommandBuildException(
        '${FfmpegCommandFormatters.videoCodecLabel(targetCodec)} 不能使用 '
        '${FfmpegCommandFormatters.encoderBackendLabel(backend)} 编码器',
      );
    } on UnsupportedEncoderBackendException catch (error) {
      throw FfmpegCommandBuildException(
        '当前 FFmpeg 不支持 '
        '${FfmpegCommandFormatters.encoderBackendLabel(error.backend)} 编码器: '
        '${error.encoderName}',
      );
    }
  }

  EncoderBackend softwareBackendFor(VideoCodec targetCodec) {
    return switch (targetCodec) {
      VideoCodec.h264 => EncoderBackend.libx264,
      VideoCodec.hevc => EncoderBackend.libx265,
      VideoCodec.vp9 => EncoderBackend.libvpxVp9,
      VideoCodec.av1 => EncoderBackend.libsvtav1,
      VideoCodec.proRes => EncoderBackend.proresKs,
      VideoCodec.mpeg4 => EncoderBackend.nativeMpeg4,
      VideoCodec.mjpeg => EncoderBackend.nativeMjpeg,
      VideoCodec.source => throw const SourceCodecNotResolvedException(),
    };
  }

  EncoderBackend resolveEffectiveBackend({
    required MediaTask task,
    required VideoCodec targetCodec,
    required EncoderBackend backend,
    required FfmpegEncoderCapabilities encoderCapabilities,
  }) {
    if (shouldPreserveHdr(task) &&
        encoderCapabilities.supportsEncoder(
          targetCodec: VideoCodec.hevc,
          backend: EncoderBackend.libx265,
        )) {
      return EncoderBackend.libx265;
    }

    if (shouldPreserveHdr(task)) {
      throw const FfmpegCommandBuildException(
        '保持 HDR 输出需要当前 FFmpeg 支持 libx265 HEVC Main10 编码。',
      );
    }

    if (backend != EncoderBackend.auto ||
        !isHighRiskAppleHdrSource(task) ||
        !encoderCapabilities.supportsEncoder(
          targetCodec: targetCodec,
          backend: softwareBackendFor(targetCodec),
        )) {
      return backend;
    }

    return softwareBackendFor(targetCodec);
  }

  bool shouldPreserveHdr(MediaTask task) {
    return task.analysisResult?.isHdr == true &&
        (task.purpose == TaskPurpose.conversion ||
            task.config.video?.hdrOutputMode == HdrOutputMode.preserveHdr);
  }

  bool isHighRiskAppleHdrSource(MediaTask task) {
    final analysis = task.analysisResult;
    if (analysis == null || !analysis.isHdr) {
      return false;
    }

    final container = analysis.containerFormat?.toLowerCase() ?? '';
    final sourceCodec = analysis.videoCodec;
    final bitDepth = analysis.videoBitDepth ?? 8;

    return container.contains('mov') &&
        MediaCodecNormalizer.isHevc(sourceCodec) &&
        bitDepth >= 10;
  }
}
