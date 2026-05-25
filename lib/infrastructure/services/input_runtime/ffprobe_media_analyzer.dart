import 'dart:convert';
import 'dart:io';

import 'package:machining/application/services/input_runtime/media_analyzer.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';

/// 使用 FFprobe 分析媒体文件基础信息
class FfprobeMediaAnalyzer implements MediaAnalyzer {
  final Duration timeout;

  FfprobeMediaAnalyzer({this.timeout = const Duration(seconds: 20)});

  @override
  Future<MediaAnalysisResult> analyze({
    required String ffprobePath,
    required String inputPath,
  }) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw StateError('源文件不存在: $inputPath');
    }

    final result = await Process.run(ffprobePath, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      inputPath,
    ]).timeout(timeout);

    if (result.exitCode != 0) {
      throw StateError('FFprobe 分析失败: ${result.stderr}');
    }

    final json = jsonDecode(result.stdout.toString());
    if (json is! Map<String, dynamic>) {
      throw StateError('FFprobe 输出格式无效');
    }

    final fileSize = await file.length();

    return parseResult(json, fileSize: fileSize);
  }

  MediaAnalysisResult parseResult(Map<String, dynamic> json, {int? fileSize}) {
    final streams = json['streams'];
    final format = json['format'];

    if (streams is! List) {
      throw StateError('FFprobe 输出缺少 streams');
    }

    final videoStream = findStream(streams, 'video');
    final audioStream = findStream(streams, 'audio');

    if (videoStream == null) {
      throw StateError('媒体文件没有视频流');
    }

    final durationMs = parseDurationMs(format, videoStream);

    return MediaAnalysisResult(
      durationMs: durationMs,
      videoWidth: parseInt(videoStream['width']),
      videoHeight: parseInt(videoStream['height']),
      videoCodec: parseString(videoStream['codec_name']),
      audioCodec: parseString(audioStream?['codec_name']),
      videoBitrate: parseInt(videoStream['bit_rate']),
      audioBitrate: parseInt(audioStream?['bit_rate']),
      containerBitrate: format is Map<String, dynamic>
          ? parseInt(format['bit_rate'])
          : null,
      estimatedBitrate: estimateBitrate(
        fileSize: fileSize,
        durationMs: durationMs,
      ),
      containerFormat: format is Map<String, dynamic>
          ? parseString(format['format_name'])
          : null,
      audioChannels: parseInt(audioStream?['channels']),
      audioSampleRate: parseInt(audioStream?['sample_rate']),
    );
  }

  Map<String, dynamic>? findStream(List<dynamic> streams, String codecType) {
    for (final stream in streams) {
      if (stream is Map<String, dynamic> && stream['codec_type'] == codecType) {
        return stream;
      }
    }

    return null;
  }

  int? parseDurationMs(Object? format, Map<String, dynamic> videoStream) {
    if (format is Map<String, dynamic>) {
      final duration = parseDouble(format['duration']);
      if (duration != null) {
        return (duration * 1000).round();
      }
    }

    final streamDuration = parseDouble(videoStream['duration']);
    if (streamDuration == null) {
      return null;
    }

    return (streamDuration * 1000).round();
  }

  int? estimateBitrate({required int? fileSize, required int? durationMs}) {
    if (fileSize == null || fileSize <= 0) {
      return null;
    }

    if (durationMs == null || durationMs <= 0) {
      return null;
    }

    final durationSeconds = durationMs / 1000;
    return (fileSize * 8 / durationSeconds).round();
  }

  int? parseInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  double? parseDouble(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String? parseString(Object? value) {
    if (value == null) {
      return null;
    }

    final text = value.toString();
    if (text.isEmpty) {
      return null;
    }

    return text;
  }
}
