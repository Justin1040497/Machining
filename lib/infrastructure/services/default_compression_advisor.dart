import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';

class DefaultCompressionAdvisor implements CompressionAdvisor {
  static const normalCrf = 28;
  static const extremeCrf = 30;
  static const preset = 'slow';
  static const minimumTargetTotalBitrate = 180000;
  static const minimumTargetVideoBitrate = 120000;
  static const defaultExtremeAudioBitrate = 64000;
  static const defaultNormalAudioBitrate = 128000;
  static const normalEstimatedTargetRatio = 0.72;

  @override
  CompressionRecommendation recommend(
    MediaTask task, {
    bool allowExtremeCompression = false,
  }) {
    final analysis = task.analysisResult;
    final bitrate = analysis?.preferredBitrate;
    final source = bitrateSource(analysis);
    final threshold = lowBitrateThreshold(analysis);

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

    final normalTargetAudioBitrate = calculateNormalTargetAudioBitrate(task);
    final normalTargetTotalBitrate = calculateNormalEstimatedTargetTotalBitrate(
      bitrate,
    );
    final normalTargetVideoBitrate = calculateTargetVideoBitrate(
      targetTotalBitrate: normalTargetTotalBitrate,
      targetAudioBitrate: normalTargetAudioBitrate,
    );
    final normalEstimatedOutputSizeBytes = calculateEstimatedOutputSizeBytes(
      task: task,
      targetTotalBitrate: normalTargetTotalBitrate,
    );

    final alreadyCompressed = bitrate < threshold;
    if (!alreadyCompressed) {
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
        estimatedOutputSizeBytes: calculateEstimatedOutputSizeBytes(
          task: task,
          targetTotalBitrate: targetTotalBitrate,
        ),
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
      estimatedOutputSizeBytes: calculateEstimatedOutputSizeBytes(
        task: task,
        targetTotalBitrate: targetTotalBitrate,
      ),
      bitrate: bitrate,
      lowBitrateThreshold: threshold,
      bitrateSource: source,
    );
  }

  int calculateTargetTotalBitrate(int sourceBitrate) {
    final target = (sourceBitrate * 0.85).round();
    if (target < minimumTargetTotalBitrate) {
      return minimumTargetTotalBitrate;
    }

    return target;
  }

  int calculateNormalEstimatedTargetTotalBitrate(int sourceBitrate) {
    final target = (sourceBitrate * normalEstimatedTargetRatio).round();
    if (target < minimumTargetTotalBitrate) {
      return minimumTargetTotalBitrate;
    }

    return target;
  }

  int calculateNormalTargetAudioBitrate(MediaTask task) {
    final sourceAudioBitrate = task.analysisResult?.audioBitrate;
    if (sourceAudioBitrate == null || sourceAudioBitrate <= 0) {
      return defaultNormalAudioBitrate;
    }

    if (sourceAudioBitrate <= defaultNormalAudioBitrate) {
      return sourceAudioBitrate;
    }

    return defaultNormalAudioBitrate;
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
    if (analysis == null) {
      return CompressionBitrateSource.unknown;
    }

    if (analysis.videoBitrate != null) {
      return CompressionBitrateSource.videoStream;
    }

    if (analysis.containerBitrate != null) {
      return CompressionBitrateSource.container;
    }

    if (analysis.estimatedBitrate != null) {
      return CompressionBitrateSource.estimated;
    }

    return CompressionBitrateSource.unknown;
  }

  int? lowBitrateThreshold(MediaAnalysisResult? analysis) {
    final height = analysis?.videoHeight;
    if (height == null || height <= 0) {
      return null;
    }

    if (height >= 1080) {
      return 1500000;
    }

    if (height >= 720) {
      return 800000;
    }

    return 500000;
  }
}
