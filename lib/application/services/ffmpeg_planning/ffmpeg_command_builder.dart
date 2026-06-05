import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';

enum ProgressMode { timed, step }

class FfmpegCommandStep {
  final List<String> args;
  final String? outputPath;
  final String label;
  final ProgressMode progressMode;

  const FfmpegCommandStep({
    required this.args,
    required this.label,
    this.progressMode = ProgressMode.timed,
    this.outputPath,
  });
}

class FfmpegCommandPlan {
  final List<String> args;
  final List<FfmpegCommandStep> steps;
  final List<String> cleanupPathPrefixes;
  final String outputPath;
  final String logHint;

  FfmpegCommandPlan({
    required this.args,
    required this.outputPath,
    required this.logHint,
    List<FfmpegCommandStep>? steps,
    this.cleanupPathPrefixes = const [],
  }) : steps =
           steps ??
           [
             FfmpegCommandStep(
               args: args,
               label: '执行 FFmpeg',
               outputPath: outputPath,
             ),
           ];
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
