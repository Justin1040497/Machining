import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/ffmpeg_planning/media_codec_normalizer.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';

class FfmpegEncoderResolver {
  const FfmpegEncoderResolver();

  void ensureSupportedTask(
    MediaTask task,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    if (task.mediaKind != MediaKind.video) {
      throw const FfmpegCommandBuildException('当前版本只支持视频任务');
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
      VideoCodec.source => throw const SourceCodecNotResolvedException(),
    };
  }

  EncoderBackend resolveEffectiveBackend({
    required MediaTask task,
    required VideoCodec targetCodec,
    required EncoderBackend backend,
    required FfmpegEncoderCapabilities encoderCapabilities,
  }) {
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
