import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/default_compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_log_hint_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_step_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_encoder_resolver.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_output_path_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_video_argument_builder.dart';

class DefaultFfmpegCommandBuilder implements FfmpegCommandBuilder {
  final CompressionAdvisor compressionAdvisor;
  final FfmpegOutputPathBuilder outputPathBuilder;
  final FfmpegEncoderResolver encoderResolver;
  final FfmpegVideoArgumentBuilder argumentBuilder;
  final FfmpegCommandStepBuilder stepBuilder;
  final FfmpegCommandLogHintBuilder logHintBuilder;

  DefaultFfmpegCommandBuilder({
    bool Function(String outputPath)? pathExists,
    CompressionAdvisor? compressionAdvisor,
    FfmpegOutputPathBuilder? outputPathBuilder,
    FfmpegEncoderResolver? encoderResolver,
    FfmpegVideoArgumentBuilder? argumentBuilder,
    FfmpegCommandStepBuilder? stepBuilder,
    FfmpegCommandLogHintBuilder? logHintBuilder,
  }) : compressionAdvisor = compressionAdvisor ?? DefaultCompressionAdvisor(),
       outputPathBuilder =
           outputPathBuilder ?? FfmpegOutputPathBuilder(pathExists: pathExists),
       encoderResolver = encoderResolver ?? const FfmpegEncoderResolver(),
       argumentBuilder = argumentBuilder ?? const FfmpegVideoArgumentBuilder(),
       stepBuilder =
           stepBuilder ??
           FfmpegCommandStepBuilder(
             argumentBuilder:
                 argumentBuilder ?? const FfmpegVideoArgumentBuilder(),
           ),
       logHintBuilder = logHintBuilder ?? const FfmpegCommandLogHintBuilder();

  @override
  FfmpegCommandPlan build(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    encoderResolver.ensureSupportedTask(task, encoderCapabilities);

    final outputPath = outputPathBuilder.buildOutputPath(task);
    final targetCodec = encoderResolver.resolveTargetVideoCodec(task);
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    final videoEncoder = encoderResolver.resolveVideoEncoderForTask(
      task: task,
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
      encoderCapabilities: encoderCapabilities,
    );
    ensureCompressionConfirmed(task, recommendation);
    final steps = stepBuilder.buildCommandSteps(
      task: task,
      recommendation: recommendation,
      targetCodec: targetCodec,
      videoEncoder: videoEncoder,
      encoderCapabilities: encoderCapabilities,
      outputPath: outputPath,
    );
    final args = steps.last.args;

    return FfmpegCommandPlan(
      args: args,
      steps: steps,
      cleanupPathPrefixes: steps.length > 1
          ? [stepBuilder.passLogFilePrefix(outputPath)]
          : const [],
      outputPath: outputPath,
      logHint: logHintBuilder.buildLogHint(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
      ),
    );
  }

  FfmpegCommandPlan buildPreviewSegment(
    MediaTask task, {
    required double startSeconds,
    required double durationSeconds,
    required String outputPath,
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    encoderResolver.ensureSupportedTask(task, encoderCapabilities);

    final targetCodec = encoderResolver.resolveTargetVideoCodec(task);
    final videoEncoder = encoderResolver.resolveVideoEncoderForTask(
      task: task,
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
      encoderCapabilities: encoderCapabilities,
    );
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    ensureCompressionConfirmed(task, recommendation);
    final args = <String>[
      '-hide_banner',
      '-y',
      '-ss',
      FfmpegCommandFormatters.formatSeconds(startSeconds),
      '-t',
      FfmpegCommandFormatters.formatSeconds(durationSeconds),
      '-i',
      task.inputPath,
      ...argumentBuilder.buildOutputStreamSelectionArgs(task),
      ...argumentBuilder.buildPurposeArgs(task, recommendation, videoEncoder),
      ...argumentBuilder.buildVideoFilterArgs(task, videoEncoder),
      ...argumentBuilder.buildCommonOutputArgs(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
        encoderCapabilities,
      ),
      outputPath,
    ];

    return FfmpegCommandPlan(
      args: args,
      outputPath: outputPath,
      logHint: logHintBuilder.buildLogHint(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
      ),
    );
  }

  String extensionFor(OutputFormat outputFormat) {
    return outputPathBuilder.extensionFor(outputFormat);
  }

  VideoCodec resolveTargetVideoCodec(MediaTask task) {
    return encoderResolver.resolveTargetVideoCodec(task);
  }

  String formatSeconds(double seconds) {
    return FfmpegCommandFormatters.formatSeconds(seconds);
  }

  void ensureCompressionConfirmed(
    MediaTask task,
    CompressionRecommendation recommendation,
  ) {
    if (task.purpose != TaskPurpose.compression) {
      return;
    }

    if (!recommendation.shouldWarnUser) {
      return;
    }

    throw CompressionConfirmationRequiredException(recommendation.message);
  }
}
