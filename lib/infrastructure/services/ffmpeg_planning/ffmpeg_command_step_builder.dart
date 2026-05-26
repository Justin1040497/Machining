import 'dart:io';

import 'package:machining/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:machining/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:machining/infrastructure/services/ffmpeg_planning/ffmpeg_video_argument_builder.dart';
import 'package:path/path.dart' as path;

class FfmpegCommandStepBuilder {
  final FfmpegVideoArgumentBuilder argumentBuilder;

  const FfmpegCommandStepBuilder({
    this.argumentBuilder = const FfmpegVideoArgumentBuilder(),
  });

  List<FfmpegCommandStep> buildCommandSteps({
    required MediaTask task,
    required CompressionRecommendation recommendation,
    required VideoCodec targetCodec,
    required String videoEncoder,
    required String outputPath,
  }) {
    if (shouldUseTwoPassTargetSize(
      task: task,
      recommendation: recommendation,
      videoEncoder: videoEncoder,
    )) {
      return buildTwoPassTargetSizeSteps(
        task: task,
        recommendation: recommendation,
        targetCodec: targetCodec,
        videoEncoder: videoEncoder,
        outputPath: outputPath,
      );
    }

    final args = buildSinglePassArgs(
      task: task,
      recommendation: recommendation,
      targetCodec: targetCodec,
      videoEncoder: videoEncoder,
      outputPath: outputPath,
    );
    return [
      FfmpegCommandStep(args: args, label: '生成输出文件', outputPath: outputPath),
    ];
  }

  List<String> buildSinglePassArgs({
    required MediaTask task,
    required CompressionRecommendation recommendation,
    required VideoCodec targetCodec,
    required String videoEncoder,
    required String outputPath,
  }) {
    return [
      '-hide_banner',
      '-i',
      task.inputPath,
      ...argumentBuilder.buildPurposeArgs(task, recommendation, videoEncoder),
      ...argumentBuilder.buildResolutionArgs(task.config.resolutionPreset),
      ...argumentBuilder.buildCommonOutputArgs(
        task.config.outputFormat,
        recommendation,
        targetCodec,
      ),
      '-progress',
      'pipe:1',
      outputPath,
    ];
  }

  bool shouldUseTwoPassTargetSize({
    required MediaTask task,
    required CompressionRecommendation recommendation,
    required String videoEncoder,
  }) {
    return task.purpose == TaskPurpose.compression &&
        recommendation.profile == CompressionProfile.targetSize &&
        !FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(videoEncoder);
  }

  List<FfmpegCommandStep> buildTwoPassTargetSizeSteps({
    required MediaTask task,
    required CompressionRecommendation recommendation,
    required VideoCodec targetCodec,
    required String videoEncoder,
    required String outputPath,
  }) {
    final passLogFile = passLogFilePrefix(outputPath);
    final firstPassArgs = [
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      ...buildTwoPassVideoArgs(
        recommendation,
        videoEncoder,
        passNumber: 1,
        passLogFile: passLogFile,
      ),
      ...argumentBuilder.buildResolutionArgs(task.config.resolutionPreset),
      '-progress',
      'pipe:1',
      '-an',
      '-f',
      'null',
      nullOutputTarget(),
    ];
    final secondPassArgs = [
      '-hide_banner',
      '-i',
      task.inputPath,
      ...buildTwoPassVideoArgs(
        recommendation,
        videoEncoder,
        passNumber: 2,
        passLogFile: passLogFile,
      ),
      ...argumentBuilder.buildResolutionArgs(task.config.resolutionPreset),
      ...argumentBuilder.buildCommonOutputArgs(
        task.config.outputFormat,
        recommendation,
        targetCodec,
      ),
      '-progress',
      'pipe:1',
      outputPath,
    ];

    return [
      FfmpegCommandStep(args: firstPassArgs, label: '分析目标体积'),
      FfmpegCommandStep(
        args: secondPassArgs,
        label: '生成目标体积文件',
        outputPath: outputPath,
      ),
    ];
  }

  List<String> buildTwoPassVideoArgs(
    CompressionRecommendation recommendation,
    String videoEncoder, {
    required int passNumber,
    required String passLogFile,
  }) {
    final targetVideoBitrate = recommendation.targetVideoBitrate;
    if (targetVideoBitrate == null) {
      return [
        '-c:v',
        videoEncoder,
        '-preset',
        recommendation.preset,
        '-crf',
        recommendation.crf.toString(),
      ];
    }

    return [
      '-c:v',
      videoEncoder,
      '-preset',
      recommendation.preset,
      '-b:v',
      FfmpegCommandFormatters.formatBitrate(targetVideoBitrate),
      '-pass',
      passNumber.toString(),
      '-passlogfile',
      passLogFile,
    ];
  }

  String passLogFilePrefix(String outputPath) {
    final directory = path.dirname(outputPath);
    final baseName = path
        .basenameWithoutExtension(outputPath)
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return path.join(directory, '.$baseName.ffmpeg-pass');
  }

  String nullOutputTarget() {
    return Platform.isWindows ? 'NUL' : '/dev/null';
  }
}
