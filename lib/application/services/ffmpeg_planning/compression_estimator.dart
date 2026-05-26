import 'dart:math' as math;

import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/services/source_compression_assessor.dart';

enum EstimateConfidence { low, medium, high }

class CompressionEstimate {
  final int expectedBytes;
  final int lowerBytes;
  final int upperBytes;
  final EstimateConfidence confidence;

  const CompressionEstimate({
    required this.expectedBytes,
    required this.lowerBytes,
    required this.upperBytes,
    required this.confidence,
  });
}

abstract class CompressionEstimator {
  CompressionEstimate? estimateSmartPreset({
    required MediaTask task,
    required SmartCompressionPreset preset,
    required VideoCodec targetCodec,
    required ResolutionPreset targetResolutionPreset,
  });
}

class DefaultCompressionEstimator implements CompressionEstimator {
  const DefaultCompressionEstimator();

  static const containerOverheadRatio = 0.03;
  static const minimumSwingBytes = 5 * 1024 * 1024;

  @override
  CompressionEstimate? estimateSmartPreset({
    required MediaTask task,
    required SmartCompressionPreset preset,
    required VideoCodec targetCodec,
    required ResolutionPreset targetResolutionPreset,
  }) {
    if (SourceCompressionAssessor.assess(task).alreadyCompressed) {
      return null;
    }

    final sourceSize = task.sourceFileFingerprint?.fileSize;
    final durationMs = task.analysisResult?.durationMs;
    if (sourceSize == null || sourceSize <= 0) {
      return null;
    }

    if (durationMs == null || durationMs <= 0) {
      return estimateFromSourceRatio(sourceSize, preset);
    }

    final durationSeconds = durationMs / 1000;
    final analysis = task.analysisResult;
    final sourceTotalBitrate =
        analysis?.preferredBitrate ??
        (sourceSize * 8 / durationSeconds).round();
    final sourceAudioBitrate = sourceAudioBitrateFor(task);
    final sourceVideoBitrate = math.max(
      32000,
      sourceTotalBitrate - sourceAudioBitrate,
    );

    final estimatedVideoBitrate =
        sourceVideoBitrate *
        resolutionFactor(task, targetResolutionPreset) *
        codecEfficiencyFactor(
          sourceCodec: analysis?.videoCodec,
          targetCodec: targetCodec,
        ) *
        presetVideoFactor(preset);
    final targetVideoBitrate = math.min(
      estimatedVideoBitrate,
      videoBitrateCeiling(
        preset: preset,
        targetCodec: targetCodec,
        targetResolutionPreset: targetResolutionPreset,
        sourceHeight: analysis?.videoHeight,
      ).toDouble(),
    );
    final targetAudioBitrate = audioBitrateForPreset(task, preset);
    final targetTotalBitrate =
        (targetVideoBitrate + targetAudioBitrate) *
        (1 + containerOverheadRatio);
    final bitrateBasedBytes = (targetTotalBitrate * durationSeconds / 8)
        .round();

    final bounds = sourceRatioBounds(sourceSize, preset);
    final expectedBytes = bitrateBasedBytes.clamp(bounds.$1, bounds.$2).toInt();
    return withSwing(
      expectedBytes: expectedBytes,
      sourceSize: sourceSize,
      confidence: analysis?.preferredBitrate == null
          ? EstimateConfidence.medium
          : EstimateConfidence.high,
    );
  }

  CompressionEstimate estimateFromSourceRatio(
    int sourceSize,
    SmartCompressionPreset preset,
  ) {
    final ratio = switch (preset) {
      SmartCompressionPreset.clear => 0.65,
      SmartCompressionPreset.balanced => 0.50,
      SmartCompressionPreset.chat => 0.25,
      SmartCompressionPreset.compact => 0.10,
    };
    return withSwing(
      expectedBytes: (sourceSize * ratio).round(),
      sourceSize: sourceSize,
      confidence: EstimateConfidence.low,
    );
  }

  CompressionEstimate withSwing({
    required int expectedBytes,
    required int sourceSize,
    required EstimateConfidence confidence,
  }) {
    final swing = math.max(minimumSwingBytes, (expectedBytes * 0.12).round());
    final lowerBytes = math.max(1, expectedBytes - swing);
    final upperBytes = math.min(sourceSize, expectedBytes + swing);
    return CompressionEstimate(
      expectedBytes: expectedBytes,
      lowerBytes: lowerBytes,
      upperBytes: upperBytes,
      confidence: confidence,
    );
  }

  (int, int) sourceRatioBounds(int sourceSize, SmartCompressionPreset preset) {
    final (lower, upper) = switch (preset) {
      SmartCompressionPreset.clear => (0.12, 0.78),
      SmartCompressionPreset.balanced => (0.06, 0.60),
      SmartCompressionPreset.chat => (0.02, 0.36),
      SmartCompressionPreset.compact => (0.008, 0.18),
    };

    return ((sourceSize * lower).round(), (sourceSize * upper).round());
  }

  double presetVideoFactor(SmartCompressionPreset preset) {
    return switch (preset) {
      SmartCompressionPreset.clear => 0.78,
      SmartCompressionPreset.balanced => 0.44,
      SmartCompressionPreset.chat => 0.34,
      SmartCompressionPreset.compact => 0.25,
    };
  }

  int audioBitrateForPreset(MediaTask task, SmartCompressionPreset preset) {
    if (task.analysisResult?.audioCodec == null &&
        task.analysisResult?.audioBitrate == null) {
      return 0;
    }

    final target = switch (preset) {
      SmartCompressionPreset.clear => 128000,
      SmartCompressionPreset.balanced => 96000,
      SmartCompressionPreset.chat => 64000,
      SmartCompressionPreset.compact => 48000,
    };
    final source = task.analysisResult?.audioBitrate;
    if (source == null || source <= 0) {
      return target;
    }

    return math.min(source, target);
  }

  int sourceAudioBitrateFor(MediaTask task) {
    if (task.analysisResult?.audioCodec == null &&
        task.analysisResult?.audioBitrate == null) {
      return 0;
    }

    return task.analysisResult?.audioBitrate ?? 96000;
  }

  double resolutionFactor(MediaTask task, ResolutionPreset preset) {
    final sourceWidth = task.analysisResult?.videoWidth;
    final sourceHeight = task.analysisResult?.videoHeight;
    if (sourceWidth == null ||
        sourceWidth <= 0 ||
        sourceHeight == null ||
        sourceHeight <= 0) {
      return 1;
    }

    final targetHeight = switch (preset) {
      ResolutionPreset.original => sourceHeight,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };
    final boundedTargetHeight = math.min(sourceHeight, targetHeight);
    final targetWidth = sourceWidth * boundedTargetHeight / sourceHeight;
    final sourcePixels = sourceWidth * sourceHeight;
    final targetPixels = targetWidth * boundedTargetHeight;
    return (targetPixels / sourcePixels).clamp(0.12, 1).toDouble();
  }

  double codecEfficiencyFactor({
    required String? sourceCodec,
    required VideoCodec targetCodec,
  }) {
    final normalizedSource = sourceCodec?.trim().toLowerCase();
    final sourceIsHevc =
        normalizedSource == 'hevc' || normalizedSource == 'h265';
    final sourceIsH264 =
        normalizedSource == 'h264' || normalizedSource == 'avc1';

    return switch (targetCodec) {
      VideoCodec.hevc when sourceIsH264 => 0.65,
      VideoCodec.hevc when sourceIsHevc => 0.85,
      VideoCodec.hevc => 0.75,
      VideoCodec.h264 when sourceIsHevc => 1.20,
      VideoCodec.h264 => 1.0,
      VideoCodec.source => 1.0,
    };
  }

  int videoBitrateCeiling({
    required SmartCompressionPreset preset,
    required VideoCodec targetCodec,
    required ResolutionPreset targetResolutionPreset,
    required int? sourceHeight,
  }) {
    final targetHeight = switch (targetResolutionPreset) {
      ResolutionPreset.original => sourceHeight ?? 1080,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };
    final boundedHeight = sourceHeight == null || sourceHeight <= 0
        ? targetHeight
        : math.min(sourceHeight, targetHeight);
    final h264Ceiling = switch (preset) {
      SmartCompressionPreset.clear =>
        boundedHeight >= 2160
            ? 28000000
            : boundedHeight >= 1080
            ? 8000000
            : boundedHeight >= 720
            ? 4000000
            : 2000000,
      SmartCompressionPreset.balanced =>
        boundedHeight >= 2160
            ? 16000000
            : boundedHeight >= 1080
            ? 5000000
            : boundedHeight >= 720
            ? 2500000
            : 1200000,
      SmartCompressionPreset.chat =>
        boundedHeight >= 2160
            ? 10000000
            : boundedHeight >= 1080
            ? 3000000
            : boundedHeight >= 720
            ? 1600000
            : 800000,
      SmartCompressionPreset.compact =>
        boundedHeight >= 2160
            ? 7000000
            : boundedHeight >= 1080
            ? 2000000
            : boundedHeight >= 720
            ? 1100000
            : 550000,
    };
    final codecFactor = targetCodec == VideoCodec.hevc ? 0.72 : 1.0;
    return (h264Ceiling * codecFactor).round();
  }
}
