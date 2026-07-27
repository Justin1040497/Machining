import 'dart:io';

import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';

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

    return qualityIndexForCrf(task.config.compressionCrf);
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
      return qualityIndexForTargetSizeRatio(defaultTargetSizeRatio);
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
      return defaultTargetSizeRatio;
    }

    var nearestRatio = defaultTargetSizeRatio;
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

abstract final class WorkbenchTaskAdjustmentPolicy {
  static bool isAdjustedFromSource({
    required MediaTask task,
    required OutputFormat outputFormat,
    required VideoCodec videoCodec,
    required ResolutionPreset resolutionPreset,
  }) {
    return outputFormatChanged(task, outputFormat) ||
        videoCodecChanged(task, videoCodec) ||
        resolutionChanged(task, resolutionPreset);
  }

  static bool outputFormatChanged(MediaTask task, OutputFormat outputFormat) {
    return outputFormat != WorkbenchFormatters.inferInitialOutputFormat(task);
  }

  static bool videoCodecChanged(MediaTask task, VideoCodec videoCodec) {
    if (videoCodec == VideoCodec.source) {
      return false;
    }

    return videoCodec != WorkbenchFormatters.inferInitialVideoCodec(task);
  }

  static bool resolutionChanged(MediaTask task, ResolutionPreset preset) {
    if (preset == ResolutionPreset.original) {
      return false;
    }

    final sourceHeight = task.analysisResult?.videoHeight;
    if (sourceHeight == null || sourceHeight <= 0) {
      return true;
    }

    return _heightForPreset(preset) != sourceHeight;
  }

  static int? _heightForPreset(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.original => null,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };
  }
}

abstract final class WorkbenchEncoderPolicy {
  static List<EncoderBackend> availableEncoderBackends({
    required VideoCodec videoCodec,
    required EncoderBackend selectedBackend,
  }) {
    final softwareBackend = switch (videoCodec) {
      VideoCodec.h264 => EncoderBackend.libx264,
      VideoCodec.hevc => EncoderBackend.libx265,
      VideoCodec.vp9 => EncoderBackend.libvpxVp9,
      VideoCodec.av1 => EncoderBackend.libsvtav1,
      VideoCodec.proRes => EncoderBackend.proresKs,
      VideoCodec.mpeg4 => EncoderBackend.nativeMpeg4,
      VideoCodec.mjpeg => EncoderBackend.nativeMjpeg,
      VideoCodec.source => EncoderBackend.auto,
    };

    late final List<EncoderBackend> backends;
    if (Platform.isMacOS) {
      backends = [
        EncoderBackend.auto,
        if (videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.hevc)
          EncoderBackend.videotoolbox,
        if (softwareBackend != EncoderBackend.auto) softwareBackend,
      ];
    } else if (Platform.isWindows) {
      backends = [
        EncoderBackend.auto,
        if (videoCodec == VideoCodec.h264 ||
            videoCodec == VideoCodec.hevc ||
            videoCodec == VideoCodec.av1)
          EncoderBackend.nvenc,
        if (videoCodec == VideoCodec.h264 ||
            videoCodec == VideoCodec.hevc ||
            videoCodec == VideoCodec.vp9 ||
            videoCodec == VideoCodec.av1)
          EncoderBackend.qsv,
        if (videoCodec == VideoCodec.h264 ||
            videoCodec == VideoCodec.hevc ||
            videoCodec == VideoCodec.av1)
          EncoderBackend.amf,
        if (softwareBackend != EncoderBackend.auto) softwareBackend,
      ];
    } else {
      backends = [
        EncoderBackend.auto,
        if (softwareBackend != EncoderBackend.auto) softwareBackend,
      ];
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
      EncoderBackend.libvpxVp9 => codec == VideoCodec.vp9,
      EncoderBackend.libsvtav1 => codec == VideoCodec.av1,
      EncoderBackend.proresKs => codec == VideoCodec.proRes,
      EncoderBackend.nativeMpeg4 => codec == VideoCodec.mpeg4,
      EncoderBackend.nativeMjpeg => codec == VideoCodec.mjpeg,
      EncoderBackend.videotoolbox =>
        codec == VideoCodec.h264 || codec == VideoCodec.hevc,
      EncoderBackend.nvenc || EncoderBackend.amf =>
        codec == VideoCodec.h264 ||
            codec == VideoCodec.hevc ||
            codec == VideoCodec.av1,
      EncoderBackend.qsv =>
        codec == VideoCodec.h264 ||
            codec == VideoCodec.hevc ||
            codec == VideoCodec.vp9 ||
            codec == VideoCodec.av1,
      EncoderBackend.auto => codec != VideoCodec.source,
    };
  }
}

/// 编解码器与 HDR 策略。
///
/// 保留旧任务配置路径中共用的编解码器变更约束。
abstract final class WorkbenchCodecPolicy {
  /// 解析编解码器变更请求，返回修正后的 (codec, backend) 组合。
  ///
  /// 处理两类约束：
  /// 1. HDR 约束：当 [preservingHdr] 为 true 时强制使用 HEVC。
  /// 2. 兼容性约束：如果当前 [currentBackend] 不兼容目标 codec，
  ///    回退到 [EncoderBackend.auto]。
  static ({VideoCodec codec, EncoderBackend backend}) resolveCodecChange({
    required VideoCodec requested,
    required EncoderBackend currentBackend,
    required bool preservingHdr,
  }) {
    var codec = requested;
    var backend = currentBackend;

    if (preservingHdr && codec != VideoCodec.hevc) {
      codec = VideoCodec.hevc;
    }

    if (!WorkbenchEncoderPolicy.isBackendCompatibleWithCodec(backend, codec)) {
      backend = EncoderBackend.auto;
    }

    return (codec: codec, backend: backend);
  }

  /// 给定的智能预设是否兼容 HDR 输出。
  static bool isHdrCompatibleSmartPreset(SmartCompressionPreset preset) {
    return preset == SmartCompressionPreset.balanced ||
        preset == SmartCompressionPreset.clear;
  }

  /// 给定的视频编解码器是否兼容 HDR 输出。
  static bool isHdrCompatibleCodec(VideoCodec codec) {
    return codec == VideoCodec.hevc || codec == VideoCodec.proRes;
  }
}
