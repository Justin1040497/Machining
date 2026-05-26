import 'dart:io';

import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/execution/preview_frame_generator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart';
import 'package:path/path.dart' as path;

class PreviewFrameCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const PreviewFrameCommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
}

typedef PreviewFrameCommandRunner =
    Future<PreviewFrameCommandResult> Function({
      required String ffmpegPath,
      required List<String> args,
    });

typedef PreviewDirectoryFactory = Directory Function(MediaTask task);

class LocalPreviewFrameGenerator implements PreviewFrameGenerator {
  static const defaultRatios = <double>[0.05, 0.275, 0.5, 0.725, 0.95];

  final DefaultFfmpegCommandBuilder commandBuilder;
  final CompressionAdvisor compressionAdvisor;
  final PreviewFrameCommandRunner runCommand;
  final PreviewDirectoryFactory previewDirectoryFactory;
  final double previewSegmentDurationSeconds;

  LocalPreviewFrameGenerator({
    required this.commandBuilder,
    required this.compressionAdvisor,
    PreviewFrameCommandRunner? runCommand,
    PreviewDirectoryFactory? previewDirectoryFactory,
    this.previewSegmentDurationSeconds = 1,
  }) : runCommand = runCommand ?? runFfmpegCommand,
       previewDirectoryFactory =
           previewDirectoryFactory ?? defaultPreviewDirectoryFactory;

  @override
  PreviewFrameFingerprint buildFingerprint(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    final analysis = task.analysisResult;
    final config = task.config;

    return PreviewFrameFingerprint(
      [
        task.id,
        task.inputPath,
        task.purpose.name,
        config.outputFormat.name,
        config.videoCodec.name,
        config.encoderBackend.name,
        encoderCapabilities.fingerprintValue,
        config.resolutionPreset.name,
        allowExtremeCompression,
        config.compressionMode.name,
        config.smartPreset?.name,
        config.targetSizeBytes,
        config.targetSizeRatio,
        analysis?.durationMs,
        analysis?.videoWidth,
        analysis?.videoHeight,
        analysis?.videoCodec,
        analysis?.preferredBitrate,
        recommendation.profile.name,
        recommendation.crf,
        recommendation.preset,
        recommendation.targetTotalBitrate,
        recommendation.targetVideoBitrate,
        recommendation.targetAudioBitrate,
      ].join('|'),
    );
  }

  @override
  Future<PreviewFrameResult> generate(PreviewFrameRequest request) async {
    final task = request.task;
    final durationMs = task.analysisResult?.durationMs;
    if (durationMs == null || durationMs <= 0) {
      throw const PreviewFrameGenerationException('缺少视频时长，不能生成预览帧');
    }

    final directory = previewDirectoryFactory(task);
    await prepareDirectory(directory);

    final fingerprint = buildFingerprint(
      task,
      allowExtremeCompression: request.allowExtremeCompression,
      encoderCapabilities: request.encoderCapabilities,
    );
    final durationSeconds = durationMs / 1000;
    final frames = <PreviewFramePair>[];

    for (var i = 0; i < defaultRatios.length; i += 1) {
      final index = i + 1;
      final ratio = defaultRatios[i];
      final timestampSeconds = durationSeconds * ratio;
      final originalFramePath = path.join(
        directory.path,
        'original_$index.jpg',
      );
      final previewFramePath = path.join(directory.path, 'preview_$index.jpg');
      final segmentPath = path.join(
        directory.path,
        'preview_segment_$index${commandBuilder.extensionFor(task.config.outputFormat)}',
      );

      await runCheckedCommand(
        ffmpegPath: request.ffmpegPath,
        args: buildExtractFrameArgs(
          task.inputPath,
          timestampSeconds,
          originalFramePath,
        ),
        description: '提取第 $index 张原始预览帧',
      );

      final segmentPlan = commandBuilder.buildPreviewSegment(
        task,
        startSeconds: segmentStartSeconds(timestampSeconds),
        durationSeconds: previewSegmentDurationSeconds,
        outputPath: segmentPath,
        allowExtremeCompression: request.allowExtremeCompression,
        encoderCapabilities: request.encoderCapabilities,
      );
      try {
        await runCheckedCommand(
          ffmpegPath: request.ffmpegPath,
          args: segmentPlan.args,
          description: '生成第 $index 段压缩预览片段',
        );
        await runCheckedCommand(
          ffmpegPath: request.ffmpegPath,
          args: buildExtractFrameArgs(
            segmentPath,
            segmentFrameOffsetSeconds(timestampSeconds),
            previewFramePath,
          ),
          description: '提取第 $index 张压缩预览帧',
        );
      } finally {
        await deletePreviewSegment(segmentPath);
      }

      frames.add(
        PreviewFramePair(
          index: index,
          ratio: ratio,
          timestampSeconds: timestampSeconds,
          originalFramePath: originalFramePath,
          previewFramePath: previewFramePath,
        ),
      );
    }

    return PreviewFrameResult(
      taskId: task.id,
      directoryPath: directory.path,
      fingerprint: fingerprint,
      frames: frames,
    );
  }

  Future<void> prepareDirectory(Directory directory) async {
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        await entity.delete(recursive: true);
      }
      return;
    }

    await directory.create(recursive: true);
  }

  Future<void> deletePreviewSegment(String segmentPath) async {
    final segmentFile = File(segmentPath);
    if (!await segmentFile.exists()) {
      return;
    }

    await segmentFile.delete();
  }

  double segmentStartSeconds(double timestampSeconds) {
    final start = timestampSeconds - (previewSegmentDurationSeconds / 2);
    if (start <= 0) {
      return 0;
    }

    return start;
  }

  double segmentFrameOffsetSeconds(double timestampSeconds) {
    final midpoint = previewSegmentDurationSeconds / 2;
    if (timestampSeconds < midpoint) {
      return timestampSeconds;
    }

    return midpoint;
  }

  List<String> buildExtractFrameArgs(
    String inputPath,
    double timestampSeconds,
    String outputPath,
  ) {
    return [
      '-hide_banner',
      '-y',
      '-ss',
      commandBuilder.formatSeconds(timestampSeconds),
      '-i',
      inputPath,
      '-frames:v',
      '1',
      '-q:v',
      '2',
      outputPath,
    ];
  }

  Future<void> runCheckedCommand({
    required String ffmpegPath,
    required List<String> args,
    required String description,
  }) async {
    final result = await runCommand(ffmpegPath: ffmpegPath, args: args);
    if (result.exitCode == 0) {
      return;
    }

    final detail = result.stderr.trim().isEmpty
        ? result.stdout.trim()
        : result.stderr.trim();
    throw PreviewFrameGenerationException('$description失败: $detail');
  }

  static Directory defaultPreviewDirectoryFactory(MediaTask task) {
    return Directory(
      path.join(Directory.systemTemp.path, 'framelean', 'previews', task.id),
    );
  }

  static Future<PreviewFrameCommandResult> runFfmpegCommand({
    required String ffmpegPath,
    required List<String> args,
  }) async {
    final result = await Process.run(ffmpegPath, args);

    return PreviewFrameCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }
}
