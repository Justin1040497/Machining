import 'dart:io';

import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/application/services/ffmpeg_command_builder.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/infrastructure/services/default_compression_advisor.dart';
import 'package:path/path.dart' as path;

class DefaultFfmpegCommandBuilder implements FfmpegCommandBuilder {
  final bool Function(String outputPath) outputPathExists;
  final CompressionAdvisor compressionAdvisor;

  DefaultFfmpegCommandBuilder({
    bool Function(String outputPath)? pathExists,
    CompressionAdvisor? compressionAdvisor,
  }) : outputPathExists =
           pathExists ?? ((outputPath) => File(outputPath).existsSync()),
       compressionAdvisor = compressionAdvisor ?? DefaultCompressionAdvisor();

  @override
  FfmpegCommandPlan build(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) {
    ensureSupportedTask(task);

    final outputPath = buildOutputPath(task);
    final targetCodec = resolveTargetVideoCodec(task);
    final videoEncoder = resolveVideoEncoder(
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
    );
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    ensureCompressionConfirmed(task, recommendation);
    final args = <String>[
      '-hide_banner',
      '-i',
      task.inputPath,
      ...buildPurposeArgs(task, recommendation, videoEncoder),
      ...buildResolutionArgs(task.config.resolutionPreset),
      ...buildCommonOutputArgs(
        task.config.outputFormat,
        recommendation,
        targetCodec,
      ),
      '-progress',
      'pipe:1',
      outputPath,
    ];

    return FfmpegCommandPlan(
      args: args,
      outputPath: outputPath,
      logHint: buildLogHint(task, recommendation, targetCodec, videoEncoder),
    );
  }

  FfmpegCommandPlan buildPreviewSegment(
    MediaTask task, {
    required double startSeconds,
    required double durationSeconds,
    required String outputPath,
    bool allowExtremeCompression = false,
  }) {
    ensureSupportedTask(task);

    final targetCodec = resolveTargetVideoCodec(task);
    final videoEncoder = resolveVideoEncoder(
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
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
      formatSeconds(startSeconds),
      '-t',
      formatSeconds(durationSeconds),
      '-i',
      task.inputPath,
      ...buildPurposeArgs(task, recommendation, videoEncoder),
      ...buildResolutionArgs(task.config.resolutionPreset),
      ...buildCommonOutputArgs(
        task.config.outputFormat,
        recommendation,
        targetCodec,
      ),
      outputPath,
    ];

    return FfmpegCommandPlan(
      args: args,
      outputPath: outputPath,
      logHint: buildLogHint(task, recommendation, targetCodec, videoEncoder),
    );
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

  void ensureSupportedTask(MediaTask task) {
    if (task.mediaKind != MediaKind.video) {
      throw const FfmpegCommandBuildException('当前版本只支持视频任务');
    }

    resolveTargetVideoCodec(task);
    resolveVideoEncoder(
      targetCodec: resolveTargetVideoCodec(task),
      backend: task.config.encoderBackend,
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
  }) {
    return switch ((targetCodec, backend)) {
      (VideoCodec.h264, EncoderBackend.auto) => 'libx264',
      (VideoCodec.h264, EncoderBackend.libx264) => 'libx264',
      (VideoCodec.h264, EncoderBackend.videotoolbox) => 'h264_videotoolbox',
      (VideoCodec.hevc, EncoderBackend.auto) => 'libx265',
      (VideoCodec.hevc, EncoderBackend.libx265) => 'libx265',
      (VideoCodec.hevc, EncoderBackend.videotoolbox) => 'hevc_videotoolbox',
      (VideoCodec.h264, EncoderBackend.libx265) =>
        throw const FfmpegCommandBuildException('H.264 不能使用 libx265 编码器'),
      (VideoCodec.hevc, EncoderBackend.libx264) =>
        throw const FfmpegCommandBuildException('HEVC 不能使用 libx264 编码器'),
      (VideoCodec.source, _) => throw const FfmpegCommandBuildException(
        'source 必须先解析成具体目标编码',
      ),
    };
  }

  String buildOutputPath(MediaTask task) {
    final inputDirectory = path.dirname(task.inputPath);
    final outputDirectory = task.config.outputDirectory.trim().isEmpty
        ? inputDirectory
        : task.config.outputDirectory;
    final extension = extensionFor(task.config.outputFormat);
    final outputFileName = buildOutputFileName(task, extension);
    final baseOutputPath = path.join(outputDirectory, outputFileName);

    return uniqueOutputPath(baseOutputPath, task.inputPath);
  }

  String buildOutputFileName(MediaTask task, String extension) {
    final customName = task.config.outputFileName.trim();
    if (customName.isNotEmpty) {
      final safeName = path.basename(customName);
      final baseName = path.basenameWithoutExtension(safeName).trim();
      if (baseName.isNotEmpty) {
        return '$baseName$extension';
      }
    }

    final inputBaseName = path.basenameWithoutExtension(task.fileName);
    final suffix = switch (task.purpose) {
      TaskPurpose.compression => 'compressed',
      TaskPurpose.conversion => 'converted',
    };

    return '${inputBaseName}_$suffix$extension';
  }

  String uniqueOutputPath(String preferredPath, String inputPath) {
    if (!isUnsafeOutputPath(preferredPath, inputPath)) {
      return preferredPath;
    }

    final directory = path.dirname(preferredPath);
    final baseName = path.basenameWithoutExtension(preferredPath);
    final extension = path.extension(preferredPath);

    var index = 1;
    while (true) {
      final candidate = path.join(directory, '$baseName-$index$extension');
      if (!isUnsafeOutputPath(candidate, inputPath)) {
        return candidate;
      }
      index += 1;
    }
  }

  bool isUnsafeOutputPath(String outputPath, String inputPath) {
    return isSamePath(outputPath, inputPath) || outputPathExists(outputPath);
  }

  bool isSamePath(String first, String second) {
    return path.normalize(path.absolute(first)) ==
        path.normalize(path.absolute(second));
  }

  List<String> buildPurposeArgs(
    MediaTask task,
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    return switch (task.purpose) {
      TaskPurpose.compression => buildCompressionArgs(
        recommendation,
        videoEncoder,
      ),
      TaskPurpose.conversion => ['-c:v', videoEncoder],
    };
  }

  List<String> buildCompressionArgs(
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    final baseArgs = <String>[
      '-c:v',
      videoEncoder,
      '-preset',
      recommendation.preset,
    ];

    if (recommendation.profile != CompressionProfile.extreme) {
      return [...baseArgs, '-crf', recommendation.crf.toString()];
    }

    final targetVideoBitrate = recommendation.targetVideoBitrate;
    if (targetVideoBitrate == null) {
      return [...baseArgs, '-crf', recommendation.crf.toString()];
    }

    return [
      ...baseArgs,
      '-b:v',
      formatBitrate(targetVideoBitrate),
      '-maxrate',
      formatBitrate(targetVideoBitrate),
      '-bufsize',
      formatBitrate(targetVideoBitrate * 2),
    ];
  }

  List<String> buildResolutionArgs(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.original => const [],
      ResolutionPreset.p2160 => const ['-vf', 'scale=-2:2160'],
      ResolutionPreset.p1080 => const ['-vf', 'scale=-2:1080'],
      ResolutionPreset.p720 => const ['-vf', 'scale=-2:720'],
      ResolutionPreset.p480 => const ['-vf', 'scale=-2:480'],
    };
  }

  List<String> buildCommonOutputArgs(
    OutputFormat outputFormat,
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
  ) {
    final audioBitrate = recommendation.targetAudioBitrate == null
        ? '128k'
        : formatBitrate(recommendation.targetAudioBitrate!);
    final args = <String>[
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      audioBitrate,
    ];

    if (targetCodec == VideoCodec.hevc &&
        (outputFormat == OutputFormat.mp4 ||
            outputFormat == OutputFormat.mov)) {
      args.addAll(['-tag:v', 'hvc1']);
    }

    if (outputFormat == OutputFormat.mp4 || outputFormat == OutputFormat.mov) {
      args.addAll(['-movflags', '+faststart']);
    }

    return args;
  }

  String formatBitrate(int bitrate) {
    if (bitrate % 1000000 == 0) {
      return '${bitrate ~/ 1000000}M';
    }

    return '${(bitrate / 1000).round()}k';
  }

  String formatSeconds(double seconds) {
    if (seconds <= 0) {
      return '0';
    }

    return seconds.toStringAsFixed(3);
  }

  String extensionFor(OutputFormat outputFormat) {
    return switch (outputFormat) {
      OutputFormat.mp4 => '.mp4',
      OutputFormat.mov => '.mov',
      OutputFormat.mkv => '.mkv',
    };
  }

  String buildLogHint(
    MediaTask task,
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
    String videoEncoder,
  ) {
    return switch (task.purpose) {
      TaskPurpose.compression => buildCompressionLogHint(
        recommendation,
        targetCodec,
        videoEncoder,
        task.config.resolutionPreset,
      ),
      TaskPurpose.conversion =>
        '使用 ${targetCodec.label} / $videoEncoder 路线生成目标封装格式文件',
    };
  }

  String buildCompressionLogHint(
    CompressionRecommendation recommendation,
    VideoCodec targetCodec,
    String videoEncoder,
    ResolutionPreset resolutionPreset,
  ) {
    if (recommendation.profile == CompressionProfile.extreme) {
      return '${recommendation.message}，目标分辨率 ${resolutionPreset.label}，'
          '目标编码 ${targetCodec.label} / $videoEncoder，'
          '目标视频码率 ${formatBitrate(recommendation.targetVideoBitrate!)}，'
          '目标音频码率 ${formatBitrate(recommendation.targetAudioBitrate!)}';
    }

    return '${recommendation.message}，'
        '使用 ${targetCodec.label} / $videoEncoder CRF ${recommendation.crf} '
        '生成输出文件';
  }
}
