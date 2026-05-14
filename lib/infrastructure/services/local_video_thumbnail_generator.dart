import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:machining/application/services/video_thumbnail_generator.dart';
import 'package:path/path.dart' as path;

class VideoThumbnailProbeResult {
  final int exitCode;
  final List<int> bytes;
  final String stderr;

  const VideoThumbnailProbeResult({
    required this.exitCode,
    required this.bytes,
    this.stderr = '',
  });
}

class VideoThumbnailCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const VideoThumbnailCommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
}

typedef VideoThumbnailProbeRunner =
    Future<VideoThumbnailProbeResult> Function({
      required String ffmpegPath,
      required List<String> args,
    });

typedef VideoThumbnailCommandRunner =
    Future<VideoThumbnailCommandResult> Function({
      required String ffmpegPath,
      required List<String> args,
    });

class LocalVideoThumbnailGenerator implements VideoThumbnailGenerator {
  static const probeSize = 16;
  static const blackLumaThreshold = 18.0;
  static const visiblePixelLumaThreshold = 28;
  static const visiblePixelRatioThreshold = 0.02;

  final VideoThumbnailProbeRunner runProbe;
  final VideoThumbnailCommandRunner runCommand;

  const LocalVideoThumbnailGenerator({
    VideoThumbnailProbeRunner? runProbe,
    VideoThumbnailCommandRunner? runCommand,
  }) : runProbe = runProbe ?? runFfmpegProbe,
       runCommand = runCommand ?? runFfmpegCommand;

  @override
  Future<VideoThumbnailResult> generate(VideoThumbnailRequest request) async {
    final timestamps = candidateTimestamps(
      request.task.analysisResult?.durationMs,
    );

    for (final timestamp in timestamps) {
      final frame = await probeFrame(request, timestamp);
      if (frame == null || isBlackFrame(frame)) {
        continue;
      }

      await extractThumbnail(request, timestamp);
      return VideoThumbnailResult(
        outputPath: request.outputPath,
        timestampSeconds: timestamp,
      );
    }

    throw const VideoThumbnailGenerationException('没有找到可显示的非黑色视频帧');
  }

  List<double> candidateTimestamps(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return const [0.1, 0.5, 1, 2, 5];
    }

    final durationSeconds = durationMs / 1000;
    final timestamps =
        <double>{
            0.1,
            durationSeconds * 0.05,
            durationSeconds * 0.12,
            durationSeconds * 0.25,
            durationSeconds * 0.5,
            durationSeconds * 0.75,
            durationSeconds * 0.9,
          }.map((timestamp) => timestamp.clamp(0.1, durationSeconds)).toList()
          ..sort();

    return timestamps;
  }

  Future<Uint8List?> probeFrame(
    VideoThumbnailRequest request,
    double timestampSeconds,
  ) async {
    final result = await runProbe(
      ffmpegPath: request.ffmpegPath,
      args: [
        '-hide_banner',
        '-v',
        'error',
        '-ss',
        formatSeconds(timestampSeconds),
        '-i',
        request.task.inputPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=$probeSize:$probeSize',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgb24',
        'pipe:1',
      ],
    );

    if (result.exitCode != 0 || result.bytes.isEmpty) {
      return null;
    }

    return Uint8List.fromList(result.bytes);
  }

  bool isBlackFrame(Uint8List rgbBytes) {
    if (rgbBytes.length < 3) {
      return true;
    }

    var lumaTotal = 0.0;
    var visiblePixels = 0;
    final pixelCount = rgbBytes.length ~/ 3;

    for (var index = 0; index < pixelCount; index += 1) {
      final offset = index * 3;
      final red = rgbBytes[offset];
      final green = rgbBytes[offset + 1];
      final blue = rgbBytes[offset + 2];
      final luma = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722);
      lumaTotal += luma;
      if (luma >= visiblePixelLumaThreshold) {
        visiblePixels += 1;
      }
    }

    final averageLuma = lumaTotal / pixelCount;
    final visiblePixelRatio = visiblePixels / pixelCount;
    return averageLuma < blackLumaThreshold &&
        visiblePixelRatio < visiblePixelRatioThreshold;
  }

  Future<void> extractThumbnail(
    VideoThumbnailRequest request,
    double timestampSeconds,
  ) async {
    await File(request.outputPath).parent.create(recursive: true);
    final tempPath = path.join(
      path.dirname(request.outputPath),
      '.${path.basenameWithoutExtension(request.outputPath)}.tmp.jpg',
    );

    final result = await runCommand(
      ffmpegPath: request.ffmpegPath,
      args: [
        '-hide_banner',
        '-y',
        '-ss',
        formatSeconds(timestampSeconds),
        '-i',
        request.task.inputPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=80:-1',
        '-q:v',
        '4',
        tempPath,
      ],
    );

    if (result.exitCode != 0 || !await File(tempPath).exists()) {
      final detail = result.stderr.trim().isEmpty
          ? result.stdout.trim()
          : result.stderr.trim();
      throw VideoThumbnailGenerationException('缩略图提取失败: $detail');
    }

    await File(tempPath).rename(request.outputPath);
  }

  String formatSeconds(double seconds) {
    return seconds.toStringAsFixed(3);
  }

  static Future<VideoThumbnailProbeResult> runFfmpegProbe({
    required String ffmpegPath,
    required List<String> args,
  }) async {
    final result = await Process.run(
      ffmpegPath,
      args,
      stdoutEncoding: null,
      stderrEncoding: utf8,
    );

    return VideoThumbnailProbeResult(
      exitCode: result.exitCode,
      bytes: result.stdout is List<int> ? result.stdout as List<int> : const [],
      stderr: result.stderr.toString(),
    );
  }

  static Future<VideoThumbnailCommandResult> runFfmpegCommand({
    required String ffmpegPath,
    required List<String> args,
  }) async {
    final result = await Process.run(ffmpegPath, args);

    return VideoThumbnailCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }
}
