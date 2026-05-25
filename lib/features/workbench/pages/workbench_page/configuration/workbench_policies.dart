import 'dart:io';

import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';

abstract final class WorkbenchQualityPolicy {
  static int initialQualityIndexForTask(MediaTask task) {
    if (task.config.compressionMode == CompressionMode.targetSize) {
      return qualityIndexForTargetSize(
        task: task,
        targetSizeBytes: task.config.targetSizeBytes,
        targetSizeRatio: task.config.targetSizeRatio,
      );
    }

    final smartPreset = task.config.smartPreset;
    if (smartPreset != null) {
      return qualityIndexForSmartPreset(smartPreset);
    }

    final configuredIndex = qualityIndexForCrf(task.config.compressionCrf);
    if (WorkbenchFormatters.isSourceAlreadyCompressed(task) &&
        configuredIndex == 2) {
      return WorkbenchConstants.qualityOptions.length - 1;
    }

    return configuredIndex;
  }

  static int qualityIndexForCrf(int crf) {
    for (
      var index = 0;
      index < WorkbenchConstants.qualityOptions.length;
      index += 1
    ) {
      if (WorkbenchConstants.qualityOptions[index].crf == crf) {
        return index;
      }
    }

    return 2;
  }

  static int qualityIndexForTargetSize({
    required MediaTask task,
    required int? targetSizeBytes,
    required double? targetSizeRatio,
  }) {
    return qualityIndexForTargetSizeRatio(
      targetSizeRatioFromTask(
        task: task,
        targetSizeBytes: targetSizeBytes,
        targetSizeRatio: targetSizeRatio,
      ),
    );
  }

  static int qualityIndexForTargetSizeRatio(double? targetSizeRatio) {
    if (targetSizeRatio == null || targetSizeRatio <= 0) {
      return qualityIndexForTargetSizeRatio(
        WorkbenchConstants.defaultTargetSizeRatio,
      );
    }

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (
      var index = 0;
      index < WorkbenchConstants.qualityOptions.length;
      index += 1
    ) {
      final option = WorkbenchConstants.qualityOptions[index];
      final distance = (option.targetRatio - targetSizeRatio).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }

    return nearestIndex;
  }

  static double initialTargetSizeRatioForTask(MediaTask task) {
    return normalizeTargetSizeRatio(
      targetSizeRatioFromTask(
        task: task,
        targetSizeBytes: task.config.targetSizeBytes,
        targetSizeRatio: task.config.targetSizeRatio,
      ),
    );
  }

  static double? targetSizeRatioFromTask({
    required MediaTask task,
    required int? targetSizeBytes,
    required double? targetSizeRatio,
  }) {
    if (targetSizeRatio != null && targetSizeRatio > 0) {
      return targetSizeRatio;
    }

    final sourceSize = task.sourceFileFingerprint?.fileSize;
    if (sourceSize != null &&
        sourceSize > 0 &&
        targetSizeBytes != null &&
        targetSizeBytes > 0) {
      return targetSizeBytes / sourceSize;
    }

    return null;
  }

  static double normalizeTargetSizeRatio(double? targetSizeRatio) {
    if (targetSizeRatio == null || targetSizeRatio <= 0) {
      return WorkbenchConstants.defaultTargetSizeRatio;
    }

    var nearestRatio = WorkbenchConstants.defaultTargetSizeRatio;
    var nearestDistance = double.infinity;
    for (final ratio in WorkbenchConstants.targetSizeRatios) {
      final distance = (ratio - targetSizeRatio).abs();
      if (distance < nearestDistance) {
        nearestRatio = ratio;
        nearestDistance = distance;
      }
    }

    return nearestRatio;
  }

  static int qualityIndexForSmartPreset(SmartCompressionPreset preset) {
    return switch (preset) {
      SmartCompressionPreset.balanced => 4,
      SmartCompressionPreset.chat => 6,
      SmartCompressionPreset.clear => 3,
      SmartCompressionPreset.compact => 8,
    };
  }

  static SmartCompressionPreset smartPresetForQualityIndex(
    int qualityIndexOrCrf,
  ) {
    if (qualityIndexOrCrf == 6 || qualityIndexOrCrf == 30) {
      return SmartCompressionPreset.chat;
    }
    if (qualityIndexOrCrf == 3 || qualityIndexOrCrf == 27) {
      return SmartCompressionPreset.clear;
    }
    if (qualityIndexOrCrf == 8 || qualityIndexOrCrf == 32) {
      return SmartCompressionPreset.compact;
    }

    return SmartCompressionPreset.balanced;
  }

  static int? targetSizeBytesForTargetRatio(
    MediaTask task,
    double targetSizeRatio,
  ) {
    final sourceSize = task.sourceFileFingerprint?.fileSize;
    if (sourceSize == null || sourceSize <= 0) {
      return null;
    }

    return (sourceSize * targetSizeRatio).round();
  }
}

abstract final class WorkbenchEncoderPolicy {
  static List<EncoderBackend> availableEncoderBackends({
    required VideoCodec videoCodec,
    required EncoderBackend selectedBackend,
  }) {
    final softwareBackend = videoCodec == VideoCodec.hevc
        ? EncoderBackend.libx265
        : EncoderBackend.libx264;

    late final List<EncoderBackend> backends;
    if (Platform.isMacOS) {
      backends = [
        EncoderBackend.auto,
        EncoderBackend.videotoolbox,
        softwareBackend,
      ];
    } else if (Platform.isWindows) {
      backends = [
        EncoderBackend.auto,
        EncoderBackend.nvenc,
        EncoderBackend.qsv,
        EncoderBackend.amf,
        softwareBackend,
      ];
    } else {
      backends = [EncoderBackend.auto, softwareBackend];
    }

    if (!backends.contains(selectedBackend)) {
      return [...backends, selectedBackend];
    }

    return backends;
  }

  static bool isBackendCompatibleWithCodec(
    EncoderBackend backend,
    VideoCodec codec,
  ) {
    return switch (backend) {
      EncoderBackend.libx264 => codec == VideoCodec.h264,
      EncoderBackend.libx265 => codec == VideoCodec.hevc,
      _ => true,
    };
  }
}
