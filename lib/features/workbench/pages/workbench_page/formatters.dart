import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/application/services/source_compression_assessor.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:path/path.dart' as path;

abstract final class WorkbenchFormatters {
  static String formatCodec(String? codec) {
    if (codec == null || codec.isEmpty) {
      return '-';
    }

    final normalized = codec.toLowerCase();
    if (normalized == 'h264' || normalized == 'avc1') {
      return 'H264';
    }
    if (normalized == 'hevc' || normalized == 'h265') {
      return 'HEVC';
    }
    return codec.toUpperCase();
  }

  static String formatResolution(MediaAnalysisResult? analysis) {
    final width = analysis?.videoWidth;
    final height = analysis?.videoHeight;
    if (width == null || height == null) {
      return '-';
    }
    return '$width × $height';
  }

  static String formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return '-';
    }

    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatBitrate(int? bitrate) {
    if (bitrate == null || bitrate <= 0) {
      return '-';
    }

    return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
  }

  static String formatContainer(String? containerFormat) {
    if (containerFormat == null || containerFormat.isEmpty) {
      return '-';
    }

    return containerFormat.split(',').first.toUpperCase();
  }

  static String formatTargetCodec(
    VideoCodec codec,
    MediaAnalysisResult? analysis,
  ) {
    if (codec == VideoCodec.source) {
      return formatCodec(analysis?.videoCodec);
    }

    return codec == VideoCodec.hevc ? 'HEVC' : codec.label;
  }

  static OutputFormat inferInitialOutputFormat(MediaTask task) {
    final extension = path.extension(task.fileName).toLowerCase();
    switch (extension) {
      case '.mov':
        return OutputFormat.mov;
      case '.mkv':
        return OutputFormat.mkv;
      case '.mp4':
      case '.m4v':
        return OutputFormat.mp4;
    }

    final containerFormat = task.analysisResult?.containerFormat?.toLowerCase();
    if (containerFormat == null || containerFormat.isEmpty) {
      return OutputFormat.mp4;
    }
    if (containerFormat.contains('matroska') ||
        containerFormat.contains('mkv')) {
      return OutputFormat.mkv;
    }
    if (containerFormat.contains('mov') && !containerFormat.contains('mp4')) {
      return OutputFormat.mov;
    }

    return OutputFormat.mp4;
  }

  static VideoCodec inferInitialVideoCodec(MediaTask task) {
    final codec = task.analysisResult?.videoCodec?.toLowerCase();
    if (codec == 'hevc' || codec == 'h265') {
      return VideoCodec.hevc;
    }

    return VideoCodec.h264;
  }

  static bool isSourceAlreadyCompressed(MediaTask task) {
    return SourceCompressionAssessor.assess(task).alreadyCompressed;
  }

  static int? lowBitrateThreshold(MediaAnalysisResult? analysis) {
    return SourceCompressionAssessor.lowBitrateThreshold(analysis);
  }

  static String formatBytes(int? bytes) {
    if (bytes == null) {
      return '-';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    if (unitIndex == 0) {
      return '${value.round()}${units[unitIndex]}';
    }

    final text = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text${units[unitIndex]}';
  }
}
