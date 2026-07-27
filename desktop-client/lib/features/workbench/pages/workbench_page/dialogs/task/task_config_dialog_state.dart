/// 任务配置弹窗的可变状态模型。
///
/// 对应原 task_configuration_dialog.dart 中 ~10 个闭包变量的集合，
/// 采用项目统一的 @immutable + copyWith 模式，与 WorkbenchPreviewState 风格一致。
///
/// 使用 sentinel 模式处理 nullable 字段的 copyWith 重置场景。
library;

import 'package:flutter/foundation.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';

const Object _sentinel = Object();

@immutable
class TaskConfigDialogState {
  const TaskConfigDialogState({
    required this.purpose,
    required this.qualityIndex,
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.compressionMode,
    required this.smartPreset,
    required this.targetSizeRatio,
    required this.config,
    this.threadLimit,
  });

  final TaskPurpose purpose;
  final int qualityIndex;
  final OutputFormat outputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final ResolutionPreset resolutionPreset;
  final CompressionMode compressionMode;
  final SmartCompressionPreset? smartPreset;
  final double targetSizeRatio;
  final MediaTaskConfig config;
  final int? threadLimit;

  /// 从已有任务初始化弹窗状态。
  factory TaskConfigDialogState.fromTask({
    required MediaTask task,
    required int selectedQualityIndex,
    required OutputFormat selectedOutputFormat,
    required VideoCodec selectedVideoCodec,
    required EncoderBackend selectedEncoderBackend,
    required ResolutionPreset selectedResolutionPreset,
    required CompressionMode selectedCompressionMode,
    required SmartCompressionPreset selectedSmartPreset,
    required double selectedTargetSizeRatio,
  }) {
    return TaskConfigDialogState(
      purpose: task.purpose,
      qualityIndex: selectedQualityIndex,
      outputFormat: selectedOutputFormat,
      videoCodec: selectedVideoCodec,
      encoderBackend: selectedEncoderBackend,
      resolutionPreset: selectedResolutionPreset,
      compressionMode: selectedCompressionMode,
      smartPreset: selectedSmartPreset,
      targetSizeRatio: selectedTargetSizeRatio,
      config: task.config,
      threadLimit: task.config.threadLimit,
    );
  }

  TaskConfigDialogState copyWith({
    TaskPurpose? purpose,
    int? qualityIndex,
    OutputFormat? outputFormat,
    VideoCodec? videoCodec,
    EncoderBackend? encoderBackend,
    ResolutionPreset? resolutionPreset,
    CompressionMode? compressionMode,
    Object? smartPreset = _sentinel,
    Object? targetSizeRatio = _sentinel,
    MediaTaskConfig? config,
    Object? threadLimit = _sentinel,
  }) {
    return TaskConfigDialogState(
      purpose: purpose ?? this.purpose,
      qualityIndex: qualityIndex ?? this.qualityIndex,
      outputFormat: outputFormat ?? this.outputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      encoderBackend: encoderBackend ?? this.encoderBackend,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      compressionMode: compressionMode ?? this.compressionMode,
      smartPreset: smartPreset == _sentinel
          ? this.smartPreset
          : smartPreset as SmartCompressionPreset?,
      targetSizeRatio: targetSizeRatio == _sentinel
          ? this.targetSizeRatio
          : targetSizeRatio as double,
      config: config ?? this.config,
      threadLimit: threadLimit == _sentinel
          ? this.threadLimit
          : threadLimit as int?,
    );
  }

  // -------------------------------------------------------------------------
  // HDR 相关
  // -------------------------------------------------------------------------

  /// 当前是否处于"保持 HDR"模式。
  ///
  /// 需要 [task] 参数以检查源文件是否含 HDR 信息。
  bool preserveHdrActive(MediaTask task) {
    if (task.analysisResult?.isHdr != true) return false;
    final videoConfig = config.video ?? VideoProcessingConfig.initial();
    return videoConfig.hdrOutputMode == HdrOutputMode.preserveHdr;
  }

  /// 当 HDR 约束激活时，规范化当前选择。
  TaskConfigDialogState normalizeHdrRestrictedChoices({
    required MediaTask task,
  }) {
    if (!preserveHdrActive(task)) {
      return this;
    }

    if (compressionMode == CompressionMode.targetSize ||
        !WorkbenchCodecPolicy.isHdrCompatibleSmartPreset(
          smartPreset ?? SmartCompressionPreset.balanced,
        )) {
      return _applyHdrRecommendedPreset();
    }

    return this;
  }

  TaskConfigDialogState _applyHdrRecommendedPreset() {
    final recommended = SmartCompressionPreset.clear;
    return copyWith(
      compressionMode: CompressionMode.preset,
      smartPreset: recommended,
      qualityIndex: WorkbenchQualityPolicy.qualityIndexForSmartPreset(
        recommended,
      ),
    );
  }

  /// 开启/关闭"保持 HDR"模式。
  ///
  /// 开启时：强制 HEVC + 兼容 backend + 保存原 codec/backend + 切换到推荐预设。
  /// 关闭时：恢复原 codec/backend + 切回 SDR 模式。
  TaskConfigDialogState withPreserveHdrChanged({
    required MediaTask task,
    required bool value,
  }) {
    final videoConfig = config.video ?? VideoProcessingConfig.initial();

    if (value) {
      final result = WorkbenchCodecPolicy.resolveCodecChange(
        requested: VideoCodec.hevc,
        currentBackend: encoderBackend,
        preservingHdr: true,
      );
      return copyWith(
        videoCodec: result.codec,
        encoderBackend: result.backend,
        config: config.copyWith(
          videoCodec: result.codec,
          encoderBackend: result.backend,
          hdrOutputMode: HdrOutputMode.preserveHdr,
          videoCodecBeforePreserveHdr: videoConfig.videoCodec,
          encoderBackendBeforePreserveHdr: videoConfig.encoderBackend,
        ),
      )._applyHdrRecommendedPreset();
    }

    // 关闭 HDR：恢复之前的 codec/backend
    final restoredCodec =
        videoConfig.videoCodecBeforePreserveHdr ?? VideoCodec.h264;
    final restoredBackend =
        videoConfig.encoderBackendBeforePreserveHdr ?? EncoderBackend.auto;
    final result = WorkbenchCodecPolicy.resolveCodecChange(
      requested: restoredCodec,
      currentBackend: restoredBackend,
      preservingHdr: false,
    );
    return copyWith(
      videoCodec: result.codec,
      encoderBackend: result.backend,
      config: config.copyWith(
        videoCodec: result.codec,
        encoderBackend: result.backend,
        hdrOutputMode: HdrOutputMode.convertToSdr,
        videoCodecBeforePreserveHdr: null,
        encoderBackendBeforePreserveHdr: null,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 源文件信息
  // -------------------------------------------------------------------------

  /// 源视频像素格式是否含 Alpha 通道。
  bool sourceHasAlpha(MediaTask task) {
    final pixelFormat = task.analysisResult?.videoPixelFormat
        ?.trim()
        .toLowerCase();
    return pixelFormat != null &&
        (pixelFormat.startsWith('yuva') ||
            pixelFormat == 'rgba' ||
            pixelFormat == 'bgra' ||
            pixelFormat == 'argb' ||
            pixelFormat == 'abgr' ||
            pixelFormat.startsWith('gbrap'));
  }

  /// 根据源文件 Alpha 通道情况，返回允许的输出格式列表（视频任务）。
  List<OutputFormat> videoOutputFormats(MediaTask task) {
    if (sourceHasAlpha(task)) {
      return const [OutputFormat.mov];
    }
    return OutputFormat.values;
  }

  /// 根据源文件名推断输出格式。
  MediaOutputFormat? resolveSourceOutputFormat({required MediaTask task}) {
    return mediaOutputFormatForSourceFileName(
      sourceFileName: task.inputPath,
      mediaKind: task.mediaKind,
    );
  }

  // -------------------------------------------------------------------------
  // 分辨率
  // -------------------------------------------------------------------------

  ({int width, int height})? resolutionPresetSize(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.original => null,
      ResolutionPreset.p2160 => (width: 3840, height: 2160),
      ResolutionPreset.p1080 => (width: 1920, height: 1080),
      ResolutionPreset.p720 => (width: 1280, height: 720),
      ResolutionPreset.p480 => (width: 854, height: 480),
    };
  }

  List<ResolutionPreset> availableResolutionPresets(MediaTask task) {
    final width = task.analysisResult?.videoWidth;
    final height = task.analysisResult?.videoHeight;
    return const [
      ResolutionPreset.original,
      ResolutionPreset.p2160,
      ResolutionPreset.p1080,
      ResolutionPreset.p720,
      ResolutionPreset.p480,
    ].where((preset) {
      if (preset == ResolutionPreset.original) {
        return true;
      }
      final size = resolutionPresetSize(preset);
      if (width == null || height == null || size == null) {
        return true;
      }
      return width != size.width || height != size.height;
    }).toList();
  }

  String resolutionLabel(MediaTask task, ResolutionPreset value) {
    if (value == ResolutionPreset.original) {
      final w = task.analysisResult?.videoWidth;
      final h = task.analysisResult?.videoHeight;
      if (w != null && h != null) {
        return '$w × $h（保持原始）';
      }
    }
    return value.label.replaceAll('x', ' × ');
  }

  // -------------------------------------------------------------------------
  // 元数据开关
  // -------------------------------------------------------------------------

  bool get preserveMetadata {
    final video = config.video;
    if (video != null) return video.preserveMetadata;
    final image = config.image;
    if (image != null) return image.preserveMetadata;
    final audio = config.audio;
    if (audio != null) return audio.preserveMetadata;
    return true;
  }

  TaskConfigDialogState withPreserveMetadata({
    required MediaTask task,
    required bool value,
  }) {
    final video = config.video;
    final image = config.image;
    final audio = config.audio;

    if (task.mediaKind == MediaKind.video && video != null) {
      return copyWith(
        config: config.copyWith(video: video.copyWith(preserveMetadata: value)),
      );
    }
    if (task.mediaKind == MediaKind.image && image != null) {
      return copyWith(
        config: config.copyWith(image: image.copyWith(preserveMetadata: value)),
      );
    }
    if (task.mediaKind == MediaKind.audio && audio != null) {
      return copyWith(
        config: config.copyWith(audio: audio.copyWith(preserveMetadata: value)),
      );
    }

    return this;
  }

  // -------------------------------------------------------------------------
  // 变更检测
  // -------------------------------------------------------------------------

  bool isModified({required MediaTask task}) {
    if (task.purpose != purpose || task.config.threadLimit != threadLimit) {
      return true;
    }

    switch (task.mediaKind) {
      case MediaKind.video:
        final adjusted = WorkbenchTaskAdjustmentPolicy.isAdjustedFromSource(
          task: task,
          outputFormat: outputFormat,
          videoCodec: videoCodec,
          resolutionPreset: resolutionPreset,
        );
        final initial = task.config.video;
        final current = config.video;
        return adjusted ||
            (initial != null &&
                current != null &&
                videoConfigChanged(initial, current));

      case MediaKind.image:
        final initial = task.config.image;
        final current = config.image;
        return initial != null &&
            current != null &&
            imageConfigChanged(initial, current);

      case MediaKind.audio:
        final initial = task.config.audio;
        final current = config.audio;
        return initial != null &&
            current != null &&
            audioConfigChanged(initial, current);
    }
  }

  bool videoConfigChanged(
    VideoProcessingConfig initial,
    VideoProcessingConfig current,
  ) {
    return initial.outputFormat != current.outputFormat ||
        initial.keepOriginalOutputFormat != current.keepOriginalOutputFormat ||
        initial.videoCodec != current.videoCodec ||
        initial.encoderBackend != current.encoderBackend ||
        initial.hdrOutputMode != current.hdrOutputMode ||
        initial.resolutionPreset != current.resolutionPreset ||
        initial.compressionCrf != current.compressionCrf ||
        initial.smartPreset != current.smartPreset ||
        initial.preserveMetadata != current.preserveMetadata ||
        initial.twoPassMode != current.twoPassMode ||
        initial.selectedAudioStreamIndex != current.selectedAudioStreamIndex;
  }

  bool imageConfigChanged(
    ImageProcessingConfig initial,
    ImageProcessingConfig current,
  ) {
    return initial.outputFormat != current.outputFormat ||
        initial.keepOriginalOutputFormat != current.keepOriginalOutputFormat ||
        initial.losslessCompression != current.losslessCompression ||
        initial.imageQuality != current.imageQuality ||
        initial.resizePreset != current.resizePreset ||
        initial.preserveMetadata != current.preserveMetadata;
  }

  bool audioConfigChanged(
    AudioProcessingConfig initial,
    AudioProcessingConfig current,
  ) {
    return initial.outputFormat != current.outputFormat ||
        initial.bitratePreset != current.bitratePreset ||
        initial.sampleRate != current.sampleRate ||
        initial.channels != current.channels ||
        initial.preserveMetadata != current.preserveMetadata;
  }

  // -------------------------------------------------------------------------
  // 生成返回结果
  // -------------------------------------------------------------------------

  /// 构建弹窗最终输出的 Draft 对象。
  WorkbenchTaskConfigurationDraft toDraft() {
    return WorkbenchTaskConfigurationDraft(
      purpose: purpose,
      qualityIndex: qualityIndex,
      outputFormat: outputFormat,
      videoCodec: videoCodec,
      encoderBackend: encoderBackend,
      resolutionPreset: resolutionPreset,
      compressionMode: compressionMode,
      smartPreset: smartPreset ?? SmartCompressionPreset.balanced,
      targetSizeRatio: targetSizeRatio,
      config: config,
    );
  }
}

/// 任务配置弹窗的返回值。
///
/// 包含用户在弹窗中调整后的所有配置字段，由 [TaskConfigDialogState.toDraft] 构建。
@immutable
class WorkbenchTaskConfigurationDraft {
  const WorkbenchTaskConfigurationDraft({
    required this.purpose,
    required this.qualityIndex,
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.compressionMode,
    required this.smartPreset,
    required this.targetSizeRatio,
    required this.config,
  });

  final TaskPurpose purpose;
  final int qualityIndex;
  final OutputFormat outputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final ResolutionPreset resolutionPreset;
  final CompressionMode compressionMode;
  final SmartCompressionPreset smartPreset;
  final double targetSizeRatio;
  final MediaTaskConfig config;
}
