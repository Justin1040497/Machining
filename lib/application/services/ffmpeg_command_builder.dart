import 'package:machining/application/services/ffmpeg_encoder_capabilities.dart';
import 'package:machining/domain/entities/media_task.dart';

class FfmpegCommandPlan {
  final List<String> args;
  final String outputPath;
  final String logHint;

  const FfmpegCommandPlan({
    required this.args,
    required this.outputPath,
    required this.logHint,
  });
}

class FfmpegCommandBuildException implements Exception {
  final String message;

  const FfmpegCommandBuildException(this.message);

  @override
  String toString() {
    return message;
  }
}

class CompressionConfirmationRequiredException implements Exception {
  final String message;

  const CompressionConfirmationRequiredException(this.message);

  @override
  String toString() {
    return message;
  }
}

abstract class FfmpegCommandBuilder {
  FfmpegCommandPlan build(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  });
}
