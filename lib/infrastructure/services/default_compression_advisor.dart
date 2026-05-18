import 'dart:math' as math;

import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/application/services/source_compression_assessor.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';

class DefaultCompressionAdvisor implements CompressionAdvisor {
  static const normalCrf = 28;
  static const extremeCrf = 30;
  static const preset = 'slow';
  static const minimumTargetTotalBitrate = 180000;
  static const minimumTargetVideoBitrate = 120000;
  static const minimumStrictTargetVideoBitrate = 16000;
  static const defaultExtremeAudioBitrate = 64000;
  static const defaultNormalAudioBitrate = 128000;
  static const normalEstimatedTargetRatio = 0.72;

  @override
  CompressionRecommendation recommend(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) {
    final assessment = SourceCompressionAssessor.assess(task);
    final bitrate = assessment.effectiveVideoBitrate;
    final source = assessment.bitrateSource;
    final threshold = assessment.lowBitrateThreshold;
    final alreadyCompressed = assessment.alreadyCompressed;

    if (task.config.compressionMode == CompressionMode.targetSize) {
      final targetSizeRecommendation = buildTargetSizeRecommendation(
        task: task,
        sourceAlreadyCompressed: alreadyCompressed,
        bitrate: bitrate,
        lowBitrateThreshold: threshold,
        bitrateSource: source,
      );
      if (targetSizeRecommendation != null) {
        return targetSizeRecommendation;
      }
    }

    if (bitrate == null || threshold == null) {
      return CompressionRecommendation(
        profile: CompressionProfile.normal,
        sourceAlreadyCompressed: false,
        shouldWarnUser: false,
        message: '码率未知，使用普通压缩策略',
        crf: task.config.compressionCrf,
        preset: preset,
        targetTotalBitrate: null,
        targetVideoBitrate: null,
        targetAudioBitrate: null,
        estimatedOutputSizeBytes: null,
        bitrate: bitrate,
        lowBitrateThreshold: threshold,
        bitrateSource: source,
      );
    }

    if (!alreadyCompressed) {
      final normalTargetAudioBitrate = calculateNormalTargetAudioBitrate(task);
      final normalTargetTotalBitrate =
          calculateNormalEstimatedTargetTotalBitrate(
            task: task,
            sourceBitrate: bitrate,
            targetAudioBitrate: normalTargetAudioBitrate,
          );
      final normalTargetVideoBitrate = calculateTargetVideoBitrate(
        targetTotalBitrate: normalTargetTotalBitrate,
        targetAudioBitrate: normalTargetAudioBitrate,
      );
      final normalEstimatedOutputSizeBytes = calculateEstimatedOutputSizeBytes(
        task: task,
        targetTotalBitrate: normalTargetTotalBitrate,
      );

      return CompressionRecommendation(
        profile: CompressionProfile.normal,
        sourceAlreadyCompressed: false,
        shouldWarnUser: false,
        message: '当前码率不低，使用普通压缩策略',
        crf: task.config.compressionCrf,
        preset: preset,
        targetTotalBitrate: normalTargetTotalBitrate,
        targetVideoBitrate: normalTargetVideoBitrate,
        targetAudioBitrate: normalTargetAudioBitrate,
        estimatedOutputSizeBytes: normalEstimatedOutputSizeBytes,
        bitrate: bitrate,
        lowBitrateThreshold: threshold,
        bitrateSource: source,
      );
    }

    if (!allowExtremeCompression) {
      final targetAudioBitrate = calculateTargetAudioBitrate(task);
      final targetTotalBitrate = calculateTargetTotalBitrate(bitrate);
      final targetVideoBitrate = calculateTargetVideoBitrate(
        targetTotalBitrate: targetTotalBitrate,
        targetAudioBitrate: targetAudioBitrate,
      );
      return CompressionRecommendation(
        profile: CompressionProfile.normal,
        sourceAlreadyCompressed: true,
        shouldWarnUser: true,
        message: '该视频已经压缩过，再压缩体积可能变大',
        crf: task.config.compressionCrf,
        preset: preset,
        targetTotalBitrate: targetTotalBitrate,
        targetVideoBitrate: targetVideoBitrate,
        targetAudioBitrate: targetAudioBitrate,
        estimatedOutputSizeBytes: null,
        bitrate: bitrate,
        lowBitrateThreshold: threshold,
        bitrateSource: source,
      );
    }

    final targetAudioBitrate = calculateTargetAudioBitrate(task);
    final targetTotalBitrate = calculateTargetTotalBitrate(bitrate);
    final targetVideoBitrate = calculateTargetVideoBitrate(
      targetTotalBitrate: targetTotalBitrate,
      targetAudioBitrate: targetAudioBitrate,
    );

    return CompressionRecommendation(
      profile: CompressionProfile.extreme,
      sourceAlreadyCompressed: true,
      shouldWarnUser: false,
      message: '用户确认继续压缩，使用目标码率极限压缩策略',
      crf: extremeCrf,
      preset: preset,
      targetTotalBitrate: targetTotalBitrate,
      targetVideoBitrate: targetVideoBitrate,
      targetAudioBitrate: targetAudioBitrate,
      estimatedOutputSizeBytes: null,
      bitrate: bitrate,
      lowBitrateThreshold: threshold,
      bitrateSource: source,
    );
  }

  CompressionRecommendation? buildTargetSizeRecommendation({
    required MediaTask task,
    required bool sourceAlreadyCompressed,
    required int? bitrate,
    required int? lowBitrateThreshold,
    required CompressionBitrateSource bitrateSource,
  }) {
    final durationMs = task.analysisResult?.durationMs;
    final targetSizeBytes = resolveTargetSizeBytes(task);
    if (targetSizeBytes == null ||
        targetSizeBytes <= 0 ||
        durationMs == null ||
        durationMs <= 0 ||
        task.config.compressionMode != CompressionMode.targetSize) {
      return null;
    }

    final durationSeconds = durationMs / 1000;
    final requestedTotalBitrate = math.max(
      minimumStrictTargetVideoBitrate,
      (targetSizeBytes * 8 / durationSeconds).round(),
    );
    final targetAudioBitrate = calculateTargetSizeAudioBitrate(
      task,
      requestedTotalBitrate,
    );
    final requestedVideoBitrate = requestedTotalBitrate - targetAudioBitrate;
    final targetVideoBitrate = math.max(
      minimumStrictTargetVideoBitrate,
      requestedVideoBitrate,
    );
    final targetTotalBitrate = targetVideoBitrate + targetAudioBitrate;

    return CompressionRecommendation(
      profile: CompressionProfile.targetSize,
      sourceAlreadyCompressed: sourceAlreadyCompressed,
      shouldWarnUser: false,
      message: '使用指定目标体积压缩策略',
      crf: task.config.compressionCrf,
      preset: preset,
      targetTotalBitrate: targetTotalBitrate,
      targetVideoBitrate: targetVideoBitrate,
      targetAudioBitrate: targetAudioBitrate,
      estimatedOutputSizeBytes: sourceAlreadyCompressed
          ? null
          : calculateEstimatedOutputSizeBytes(
              task: task,
              targetTotalBitrate: targetTotalBitrate,
            ),
      bitrate: bitrate,
      lowBitrateThreshold: lowBitrateThreshold,
      bitrateSource: bitrateSource,
    );
  }

  int? resolveTargetSizeBytes(MediaTask task) {
    final targetSizeBytes = task.config.targetSizeBytes;
    if (targetSizeBytes != null && targetSizeBytes > 0) {
      return targetSizeBytes;
    }

    final sourceSize = task.sourceFileFingerprint?.fileSize;
    final ratio = task.config.targetSizeRatio;
    if (sourceSize == null || sourceSize <= 0 || ratio == null || ratio <= 0) {
      return null;
    }

    return (sourceSize * ratio).round();
  }

  int calculateTargetTotalBitrate(int sourceBitrate) {
    final target = (sourceBitrate * 0.85).round();
    if (target < minimumTargetTotalBitrate) {
      return minimumTargetTotalBitrate;
    }

    return target;
  }

  int calculateNormalEstimatedTargetTotalBitrate({
    required MediaTask task,
    required int sourceBitrate,
    required int targetAudioBitrate,
  }) {
    final target = (sourceBitrate * normalEstimatedTargetRatio).round();
    final cappedTarget = math.min(
      target,
      normalTargetVideoBitrateCeiling(task) + targetAudioBitrate,
    );

    return math.max(cappedTarget, minimumTargetTotalBitrate);
  }

  int calculateNormalTargetAudioBitrate(MediaTask task) {
    final defaultAudioBitrate = switch (normalPresetForTask(task)) {
      SmartCompressionPreset.clear => defaultNormalAudioBitrate,
      SmartCompressionPreset.balanced => 96000,
      SmartCompressionPreset.chat => 64000,
      SmartCompressionPreset.compact => 48000,
    };
    final sourceAudioBitrate = task.analysisResult?.audioBitrate;
    if (sourceAudioBitrate == null || sourceAudioBitrate <= 0) {
      return defaultAudioBitrate;
    }

    if (sourceAudioBitrate <= defaultAudioBitrate) {
      return sourceAudioBitrate;
    }

    return defaultAudioBitrate;
  }

  int normalTargetVideoBitrateCeiling(MediaTask task) {
    final height = effectiveTargetHeight(task);
    final preset = normalPresetForTask(task);
    final h264Ceiling = switch (preset) {
      SmartCompressionPreset.clear =>
        height >= 2160
            ? 28000000
            : height >= 1080
            ? 8000000
            : height >= 720
            ? 4000000
            : 2000000,
      SmartCompressionPreset.balanced =>
        height >= 2160
            ? 16000000
            : height >= 1080
            ? 5000000
            : height >= 720
            ? 2500000
            : 1200000,
      SmartCompressionPreset.chat =>
        height >= 2160
            ? 10000000
            : height >= 1080
            ? 3000000
            : height >= 720
            ? 1600000
            : 800000,
      SmartCompressionPreset.compact =>
        height >= 2160
            ? 7000000
            : height >= 1080
            ? 2000000
            : height >= 720
            ? 1100000
            : 550000,
    };

    final codecEfficiencyFactor = switch (resolvedTargetCodecForTask(task)) {
      VideoCodec.hevc => 0.72,
      VideoCodec.h264 || VideoCodec.source => 1.0,
    };
    return math.max(
      minimumTargetVideoBitrate,
      (h264Ceiling * codecEfficiencyFactor).round(),
    );
  }

  SmartCompressionPreset normalPresetForTask(MediaTask task) {
    final smartPreset = task.config.smartPreset;
    if (smartPreset != null) {
      return smartPreset;
    }

    final crf = task.config.compressionCrf;
    if (crf <= 27) {
      return SmartCompressionPreset.clear;
    }
    if (crf >= 31) {
      return SmartCompressionPreset.compact;
    }
    if (crf >= 29) {
      return SmartCompressionPreset.chat;
    }

    return SmartCompressionPreset.balanced;
  }

  VideoCodec resolvedTargetCodecForTask(MediaTask task) {
    final configuredCodec = task.config.videoCodec;
    if (configuredCodec != VideoCodec.source) {
      return configuredCodec;
    }

    final sourceCodec = task.analysisResult?.videoCodec?.trim().toLowerCase();
    if (sourceCodec == 'hevc' || sourceCodec == 'h265') {
      return VideoCodec.hevc;
    }

    return VideoCodec.h264;
  }

  int calculateTargetAudioBitrate(MediaTask task) {
    final sourceAudioBitrate = task.analysisResult?.audioBitrate;
    if (sourceAudioBitrate == null || sourceAudioBitrate <= 0) {
      return defaultExtremeAudioBitrate;
    }

    if (sourceAudioBitrate <= defaultExtremeAudioBitrate) {
      return sourceAudioBitrate;
    }

    return defaultExtremeAudioBitrate;
  }

  int calculateTargetSizeAudioBitrate(MediaTask task, int targetTotalBitrate) {
    if (task.analysisResult?.audioCodec == null &&
        task.analysisResult?.audioBitrate == null) {
      return 0;
    }

    final defaultAudioBitrate = targetTotalBitrate <= 96000
        ? 24000
        : targetTotalBitrate <= 160000
        ? 32000
        : targetTotalBitrate <= 320000
        ? 48000
        : targetTotalBitrate <= 800000
        ? 64000
        : targetTotalBitrate <= 1500000
        ? 96000
        : defaultNormalAudioBitrate;
    final sourceAudioBitrate = task.analysisResult?.audioBitrate;
    if (sourceAudioBitrate == null || sourceAudioBitrate <= 0) {
      return defaultAudioBitrate;
    }

    if (sourceAudioBitrate <= defaultAudioBitrate) {
      return sourceAudioBitrate;
    }

    return defaultAudioBitrate;
  }

  int minimumVideoBitrateForTask(MediaTask task) {
    final height = effectiveTargetHeight(task);
    if (height >= 2160) {
      return 2500000;
    }
    if (height >= 1080) {
      return 900000;
    }
    if (height >= 720) {
      return 500000;
    }

    return 280000;
  }

  int effectiveTargetHeight(MediaTask task) {
    final sourceHeight = task.analysisResult?.videoHeight;
    final presetHeight = switch (task.config.resolutionPreset) {
      ResolutionPreset.original => sourceHeight,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };

    return presetHeight ?? sourceHeight ?? 1080;
  }

  int calculateTargetVideoBitrate({
    required int targetTotalBitrate,
    required int targetAudioBitrate,
  }) {
    final target = targetTotalBitrate - targetAudioBitrate;
    if (target < minimumTargetVideoBitrate) {
      return minimumTargetVideoBitrate;
    }

    return target;
  }

  int? calculateEstimatedOutputSizeBytes({
    required MediaTask task,
    required int targetTotalBitrate,
  }) {
    final durationMs = task.analysisResult?.durationMs;
    if (durationMs == null || durationMs <= 0) {
      return null;
    }

    final durationSeconds = durationMs / 1000;
    return (targetTotalBitrate * durationSeconds / 8).round();
  }

  CompressionBitrateSource bitrateSource(MediaAnalysisResult? analysis) {
    return SourceCompressionAssessor.bitrateSource(analysis);
  }

  int? lowBitrateThreshold(MediaAnalysisResult? analysis) {
    return SourceCompressionAssessor.lowBitrateThreshold(analysis);
  }
}
