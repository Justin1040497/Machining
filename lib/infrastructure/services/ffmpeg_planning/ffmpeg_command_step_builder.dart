import 'dart:io';

import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/ffmpeg_planning/media_codec_normalizer.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/two_pass_mode.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/video_output_compatibility.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_video_argument_builder.dart';
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
    required FfmpegEncoderCapabilities encoderCapabilities,
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
        encoderCapabilities: encoderCapabilities,
        outputPath: outputPath,
      );
    }

    final args = buildSinglePassArgs(
      task: task,
      recommendation: recommendation,
      targetCodec: targetCodec,
      videoEncoder: videoEncoder,
      encoderCapabilities: encoderCapabilities,
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
    required FfmpegEncoderCapabilities encoderCapabilities,
    required String outputPath,
  }) {
    if (canStreamCopyConversion(task, targetCodec)) {
      return [
        '-hide_banner',
        '-y',
        '-i',
        task.inputPath,
        ...argumentBuilder.buildOutputStreamSelectionArgs(task),
        '-c:v',
        'copy',
        '-c:a',
        'copy',
        ...argumentBuilder.buildFrameTimingArgs(task),
        if (task.config.outputFormat == OutputFormat.mp4 ||
            task.config.outputFormat == OutputFormat.mov) ...[
          '-movflags',
          '+faststart',
        ],
        ...argumentBuilder.buildThreadArgs(task),
        '-progress',
        'pipe:1',
        outputPath,
      ];
    }

    return [
      '-hide_banner',
      '-y',
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
      ...argumentBuilder.buildThreadArgs(task),
      '-progress',
      'pipe:1',
      outputPath,
    ];
  }

  bool canStreamCopyConversion(MediaTask task, VideoCodec targetCodec) {
    if (task.purpose != TaskPurpose.conversion) {
      return false;
    }
    final sourceCodec = MediaCodecNormalizer.normalize(
      task.analysisResult?.videoCodec,
    );
    final sourceVideoCodec = sourceCodec == null
        ? null
        : MediaCodecNormalizer.videoCodecForSource(sourceCodec);
    if (sourceVideoCodec == null || sourceVideoCodec != targetCodec) {
      return false;
    }

    final outputFormat = task.config.outputFormat;
    if (!VideoOutputCompatibility.supports(outputFormat, targetCodec)) {
      return false;
    }
    if (outputFormat == OutputFormat.mkv) {
      return true;
    }
    final audioCodec = task.analysisResult?.audioCodec?.trim().toLowerCase();
    if (outputFormat == OutputFormat.webm) {
      return audioCodec == null ||
          audioCodec.isEmpty ||
          audioCodec.contains('opus') ||
          audioCodec.contains('vorbis');
    }
    if (outputFormat == OutputFormat.avi) {
      return audioCodec == null ||
          audioCodec.isEmpty ||
          audioCodec.contains('mp3') ||
          audioCodec.contains('pcm');
    }
    return audioCodec == null ||
        audioCodec.isEmpty ||
        audioCodec.contains('aac') ||
        audioCodec.contains('mp3') ||
        audioCodec.contains('alac');
  }

  bool shouldUseTwoPassTargetSize({
    required MediaTask task,
    required CompressionRecommendation recommendation,
    required String videoEncoder,
  }) {
    final twoPassMode = task.config.video?.twoPassMode ?? TwoPassMode.automatic;
    if (twoPassMode == TwoPassMode.disabled) {
      return false;
    }

    return task.purpose == TaskPurpose.compression &&
        recommendation.profile == CompressionProfile.targetSize &&
        videoEncoder != 'prores_ks' &&
        videoEncoder != 'mjpeg' &&
        !FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(videoEncoder);
  }

  List<FfmpegCommandStep> buildTwoPassTargetSizeSteps({
    required MediaTask task,
    required CompressionRecommendation recommendation,
    required VideoCodec targetCodec,
    required String videoEncoder,
    required FfmpegEncoderCapabilities encoderCapabilities,
    required String outputPath,
  }) {
    final passLogFile = passLogFilePrefix(outputPath);
    final firstPassArgs = [
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      ...argumentBuilder.buildVideoOnlyStreamSelectionArgs(),
      ...buildTwoPassVideoArgs(
        recommendation,
        videoEncoder,
        passNumber: 1,
        passLogFile: passLogFile,
      ),
      ...argumentBuilder.buildVideoFilterArgs(task, videoEncoder),
      ...argumentBuilder.buildThreadArgs(task),
      '-progress',
      'pipe:1',
      '-an',
      '-f',
      'null',
      nullOutputTarget(),
    ];
    final secondPassArgs = [
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      ...argumentBuilder.buildOutputStreamSelectionArgs(task),
      ...buildTwoPassVideoArgs(
        recommendation,
        videoEncoder,
        passNumber: 2,
        passLogFile: passLogFile,
      ),
      ...argumentBuilder.buildVideoFilterArgs(task, videoEncoder),
      ...argumentBuilder.buildCommonOutputArgs(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
        encoderCapabilities,
      ),
      ...argumentBuilder.buildThreadArgs(task),
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

    final encoderTuningArgs = switch (videoEncoder) {
      'libvpx-vp9' => const ['-deadline', 'good', '-cpu-used', '2'],
      'mpeg4' => const <String>[],
      _ => ['-preset', recommendation.preset],
    };
    return [
      '-c:v',
      videoEncoder,
      ...encoderTuningArgs,
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
