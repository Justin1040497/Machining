import 'dart:io';

import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/application/services/ffmpeg_command_builder.dart';
import 'package:machining/application/services/ffmpeg_encoder_capabilities.dart';
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
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    ensureSupportedTask(task, encoderCapabilities);

    final outputPath = buildOutputPath(task);
    final targetCodec = resolveTargetVideoCodec(task);
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    final videoEncoder = resolveVideoEncoder(
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
      encoderCapabilities: encoderCapabilities,
    );
    ensureCompressionConfirmed(task, recommendation);
    final steps = buildCommandSteps(
      task: task,
      recommendation: recommendation,
      targetCodec: targetCodec,
      videoEncoder: videoEncoder,
      outputPath: outputPath,
    );
    final args = steps.last.args;

    return FfmpegCommandPlan(
      args: args,
      steps: steps,
      cleanupPathPrefixes: steps.length > 1
          ? [passLogFilePrefix(outputPath)]
          : const [],
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
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    ensureSupportedTask(task, encoderCapabilities);

    final targetCodec = resolveTargetVideoCodec(task);
    final videoEncoder = resolveVideoEncoder(
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
        '${targetCodec.label} 不能使用 ${backend.label} 编码器',
      );
    } on UnsupportedEncoderBackendException catch (error) {
      throw FfmpegCommandBuildException(
        '当前 FFmpeg 不支持 ${error.backend.label} 编码器: ${error.encoderName}',
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
      ...buildResolutionArgs(task.config.resolutionPreset),
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
      formatBitrate(targetVideoBitrate),
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

  List<String> buildCompressionArgs(
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    if (FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(
      videoEncoder,
    )) {
      return buildHardwareCompressionArgs(recommendation, videoEncoder);
    }

    final baseArgs = <String>[
      '-c:v',
      videoEncoder,
      '-preset',
      recommendation.preset,
    ];

    if (recommendation.profile == CompressionProfile.normal) {
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

  List<String> buildHardwareCompressionArgs(
    CompressionRecommendation recommendation,
    String videoEncoder,
  ) {
    final targetVideoBitrate = recommendation.targetVideoBitrate;
    final quality = recommendation.crf.toString();

    if (videoEncoder.endsWith('_videotoolbox')) {
      return [
        '-c:v',
        videoEncoder,
        if (targetVideoBitrate == null) ...['-q:v', quality],
        if (targetVideoBitrate != null) ...[
          '-b:v',
          formatBitrate(targetVideoBitrate),
        ],
      ];
    }

    if (videoEncoder.endsWith('_nvenc')) {
      return [
        '-c:v',
        videoEncoder,
        '-preset',
        'p5',
        '-rc',
        'vbr',
        if (targetVideoBitrate == null) ...['-cq', quality, '-b:v', '0'],
        if (targetVideoBitrate != null) ...[
          '-b:v',
          formatBitrate(targetVideoBitrate),
          '-maxrate',
          formatBitrate(targetVideoBitrate),
          '-bufsize',
          formatBitrate(targetVideoBitrate * 2),
        ],
      ];
    }

    if (videoEncoder.endsWith('_qsv')) {
      return [
        '-c:v',
        videoEncoder,
        if (targetVideoBitrate == null) ...['-global_quality', quality],
        if (targetVideoBitrate != null) ...[
          '-b:v',
          formatBitrate(targetVideoBitrate),
          '-maxrate',
          formatBitrate(targetVideoBitrate),
          '-bufsize',
          formatBitrate(targetVideoBitrate * 2),
        ],
      ];
    }

    if (videoEncoder.endsWith('_amf')) {
      return [
        '-c:v',
        videoEncoder,
        '-quality',
        'balanced',
        if (targetVideoBitrate == null) ...[
          '-rc',
          'cqp',
          '-qp_i',
          quality,
          '-qp_p',
          quality,
        ],
        if (targetVideoBitrate != null) ...[
          '-rc',
          'vbr_peak',
          '-b:v',
          formatBitrate(targetVideoBitrate),
          '-maxrate',
          formatBitrate(targetVideoBitrate),
          '-bufsize',
          formatBitrate(targetVideoBitrate * 2),
        ],
      ];
    }

    return ['-c:v', videoEncoder];
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
    if (recommendation.profile == CompressionProfile.extreme ||
        recommendation.profile == CompressionProfile.targetSize) {
      final strategy =
          recommendation.profile == CompressionProfile.targetSize &&
              !FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(
                videoEncoder,
              )
          ? '使用指定目标体积两遍压缩策略'
          : recommendation.message;
      return '$strategy，目标分辨率 ${resolutionPreset.label}，'
          '目标编码 ${targetCodec.label} / $videoEncoder，'
          '目标视频码率 ${formatBitrate(recommendation.targetVideoBitrate!)}，'
          '目标音频码率 ${formatBitrate(recommendation.targetAudioBitrate!)}';
    }

    return '${recommendation.message}，'
        '使用 ${targetCodec.label} / $videoEncoder CRF ${recommendation.crf} '
        '生成输出文件';
  }
}
