import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';

enum ProgressMode { timed, step }

enum FfmpegStepCompletionPolicy {
  alwaysContinue,
  completeIfOutputSmallerThanSource,
  failIfOutputNotSmallerThanSource,
}

class FfmpegCommandStep {
  final List<String> args;
  final String? outputPath;
  final String? workingOutputPath;
  final String label;
  final ProgressMode progressMode;
  final FfmpegStepCompletionPolicy completionPolicy;
  final Set<MediaTaskPolicyTag> policyTagsOnStart;

  const FfmpegCommandStep({
    required this.args,
    required this.label,
    this.progressMode = ProgressMode.timed,
    this.outputPath,
    this.workingOutputPath,
    this.completionPolicy = FfmpegStepCompletionPolicy.alwaysContinue,
    this.policyTagsOnStart = const {},
  });

  FfmpegCommandStep copyWith({
    List<String>? args,
    String? outputPath,
    String? workingOutputPath,
    String? label,
    ProgressMode? progressMode,
    FfmpegStepCompletionPolicy? completionPolicy,
    Set<MediaTaskPolicyTag>? policyTagsOnStart,
  }) {
    return FfmpegCommandStep(
      args: args ?? this.args,
      label: label ?? this.label,
      progressMode: progressMode ?? this.progressMode,
      outputPath: outputPath ?? this.outputPath,
      workingOutputPath: workingOutputPath ?? this.workingOutputPath,
      completionPolicy: completionPolicy ?? this.completionPolicy,
      policyTagsOnStart: policyTagsOnStart ?? this.policyTagsOnStart,
    );
  }
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

  FfmpegCommandPlan copyWith({
    List<String>? args,
    List<FfmpegCommandStep>? steps,
    List<String>? cleanupPathPrefixes,
    String? outputPath,
    String? logHint,
  }) {
    return FfmpegCommandPlan(
      args: args ?? this.args,
      steps: steps ?? this.steps,
      cleanupPathPrefixes: cleanupPathPrefixes ?? this.cleanupPathPrefixes,
      outputPath: outputPath ?? this.outputPath,
      logHint: logHint ?? this.logHint,
    );
  }

  FfmpegCommandPlan replaceOutputPath({
    required String oldPath,
    required String newPath,
  }) {
    List<String> replaceArgs(List<String> source) {
      return source.map((arg) => arg == oldPath ? newPath : arg).toList();
    }

    final nextSteps = steps
        .map(
          (step) => step.copyWith(
            args: replaceArgs(step.args),
            outputPath: step.outputPath == oldPath ? newPath : step.outputPath,
          ),
        )
        .toList();

    return copyWith(
      args: replaceArgs(args),
      steps: nextSteps,
      outputPath: outputPath == oldPath ? newPath : outputPath,
    );
  }

  FfmpegCommandPlan replaceExecutionOutputPath({
    required String finalPath,
    required String workingPath,
  }) {
    List<String> replaceArgs(List<String> source) {
      return source.map((arg) => arg == finalPath ? workingPath : arg).toList();
    }

    final nextSteps = steps
        .map(
          (step) => step.outputPath == finalPath
              ? step.copyWith(
                  args: replaceArgs(step.args),
                  workingOutputPath: workingPath,
                )
              : step,
        )
        .toList();

    return copyWith(args: replaceArgs(args), steps: nextSteps);
  }
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
