import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
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
    resolveVideoEncoder(
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

    final sourceCodec = task.analysisResult?.videoCodec?.trim().toLowerCase();
    if (sourceCodec == null || sourceCodec.isEmpty) {
      throw const FfmpegCommandBuildException('无法识别源视频编码，不能默认保留原编码');
    }

    if (sourceCodec == 'h264' || sourceCodec == 'avc1') {
      return VideoCodec.h264;
    }

    if (sourceCodec == 'hevc' || sourceCodec == 'h265') {
      return VideoCodec.hevc;
    }

    throw FfmpegCommandBuildException('暂不支持保留源视频编码: $sourceCodec');
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
}
