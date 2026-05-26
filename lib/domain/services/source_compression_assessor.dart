import 'dart:math' as math;

import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';

enum CompressionBitrateSource { videoStream, container, estimated, unknown }

class SourceCompressionAssessment {
  const SourceCompressionAssessment({
    required this.alreadyCompressed,
    required this.effectiveVideoBitrate,
    required this.lowBitrateThreshold,
    required this.bitrateSource,
  });

  final bool alreadyCompressed;
  final int? effectiveVideoBitrate;
  final int? lowBitrateThreshold;
  final CompressionBitrateSource bitrateSource;
}

abstract final class SourceCompressionAssessor {
  static SourceCompressionAssessment assess(MediaTask task) {
    final analysis = task.analysisResult;
    final effectiveVideoBitrate = resolveEffectiveVideoBitrate(analysis);
    final threshold = lowBitrateThreshold(analysis);
    return SourceCompressionAssessment(
      alreadyCompressed:
          effectiveVideoBitrate != null &&
          threshold != null &&
          effectiveVideoBitrate < threshold,
      effectiveVideoBitrate: effectiveVideoBitrate,
      lowBitrateThreshold: threshold,
      bitrateSource: bitrateSource(analysis),
    );
  }

  static int? resolveEffectiveVideoBitrate(MediaAnalysisResult? analysis) {
    if (analysis == null) {
      return null;
    }

    final videoBitrate = analysis.videoBitrate;
    if (videoBitrate != null && videoBitrate > 0) {
      return videoBitrate;
    }

    final totalBitrate = analysis.containerBitrate ?? analysis.estimatedBitrate;
    if (totalBitrate == null || totalBitrate <= 0) {
      return null;
    }

    final audioBitrate = analysis.audioBitrate;
    if (audioBitrate != null && audioBitrate > 0) {
      return math.max(32000, totalBitrate - audioBitrate);
    }

    if (analysis.audioCodec == null) {
      return totalBitrate;
    }

    return (totalBitrate * 0.88).round();
  }

  static CompressionBitrateSource bitrateSource(MediaAnalysisResult? analysis) {
    if (analysis == null) {
      return CompressionBitrateSource.unknown;
    }

    if (analysis.videoBitrate != null && analysis.videoBitrate! > 0) {
      return CompressionBitrateSource.videoStream;
    }

    if (analysis.containerBitrate != null && analysis.containerBitrate! > 0) {
      return CompressionBitrateSource.container;
    }

    if (analysis.estimatedBitrate != null && analysis.estimatedBitrate! > 0) {
      return CompressionBitrateSource.estimated;
    }

    return CompressionBitrateSource.unknown;
  }

  static int? lowBitrateThreshold(MediaAnalysisResult? analysis) {
    final height = analysis?.videoHeight;
    if (height == null || height <= 0) {
      return null;
    }

    final h264Threshold = switch (height) {
      >= 2160 => 4500000,
      >= 1440 => 2800000,
      >= 1080 => 1500000,
      >= 720 => 800000,
      >= 480 => 500000,
      _ => 350000,
    };

    return math.max(
      240000,
      (h264Threshold * codecEfficiencyFactor(analysis?.videoCodec)).round(),
    );
  }

  static double codecEfficiencyFactor(String? codec) {
    final normalized = codec?.trim().toLowerCase();
    return switch (normalized) {
      'hevc' || 'h265' => 0.72,
      'av1' => 0.58,
      'vp9' => 0.65,
      _ => 1.0,
    };
  }
}
