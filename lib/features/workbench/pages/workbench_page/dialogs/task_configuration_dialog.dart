import 'package:flutter/material.dart';
import 'package:framelean/application/services/ffmpeg_planning/compression_estimator.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/audio_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/image_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/video_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';

@immutable
class WorkbenchTaskConfigurationDraft {
  const WorkbenchTaskConfigurationDraft({
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

Future<WorkbenchTaskConfigurationDraft?> showWorkbenchTaskConfigurationEditor({
  required BuildContext context,
  required MediaTask task,
  required ImageProvider? thumbnail,
  required int selectedQualityIndex,
  required OutputFormat selectedOutputFormat,
  required VideoCodec selectedVideoCodec,
  required EncoderBackend selectedEncoderBackend,
  required ResolutionPreset selectedResolutionPreset,
  required CompressionMode selectedCompressionMode,
  required SmartCompressionPreset selectedSmartPreset,
  required double selectedTargetSizeRatio,
  required VoidCallback onOpenSource,
}) {
  var draftQualityIndex = selectedQualityIndex;
  var draftOutputFormat = selectedOutputFormat;
  var draftVideoCodec = selectedVideoCodec;
  var draftEncoderBackend = selectedEncoderBackend;
  var draftResolutionPreset = selectedResolutionPreset;
  var draftCompressionMode = selectedCompressionMode;
  var draftSmartPreset = selectedSmartPreset;
  var draftTargetSizeRatio = selectedTargetSizeRatio;
  var draftConfig = task.config;
  final sourceOutputFormat = mediaOutputFormatForSourceFileName(
    sourceFileName: task.inputPath,
    mediaKind: task.mediaKind,
  );
  final sourceVideoOutputFormat = task.mediaKind == MediaKind.video
      ? sourceOutputFormat?.toVideoOutputFormat()
      : null;

  bool preserveHdrActiveForDraft() {
    return task.mediaKind == MediaKind.video &&
        task.analysisResult?.isHdr == true &&
        draftConfig.video?.hdrOutputMode == HdrOutputMode.preserveHdr;
  }

  bool isHdrCompatibleSmartPreset(SmartCompressionPreset preset) {
    return preset == SmartCompressionPreset.balanced ||
        preset == SmartCompressionPreset.clear;
  }

  void applyHdrRecommendedPreset() {
    draftCompressionMode = CompressionMode.preset;
    draftSmartPreset = SmartCompressionPreset.clear;
    draftQualityIndex = WorkbenchQualityPolicy.qualityIndexForSmartPreset(
      SmartCompressionPreset.clear,
    );
    draftConfig = draftConfig.copyWith(
      compressionMode: CompressionMode.preset,
      smartPreset: SmartCompressionPreset.clear,
    );
  }

  void normalizeHdrRestrictedChoices() {
    if (!preserveHdrActiveForDraft()) {
      return;
    }

    if (draftCompressionMode == CompressionMode.targetSize ||
        !isHdrCompatibleSmartPreset(draftSmartPreset)) {
      applyHdrRecommendedPreset();
    }
  }

  normalizeHdrRestrictedChoices();

  return showDialog<WorkbenchTaskConfigurationDraft>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, refreshDialog) {
          void updateDialogState(VoidCallback action) {
            refreshDialog(action);
          }

          return WorkbenchTaskConfigurationDialog(
            task: task,
            thumbnail: thumbnail,
            selectedQualityIndex: draftQualityIndex,
            selectedOutputFormat: draftOutputFormat,
            selectedVideoCodec: draftVideoCodec,
            selectedEncoderBackend: draftEncoderBackend,
            selectedResolutionPreset: draftResolutionPreset,
            selectedCompressionMode: draftCompressionMode,
            selectedSmartPreset: draftSmartPreset,
            selectedTargetSizeRatio: draftTargetSizeRatio,
            selectedVideoConfig: draftConfig.video,
            selectedImageConfig: draftConfig.image,
            selectedAudioConfig: draftConfig.audio,
            availableEncoderBackends:
                WorkbenchEncoderPolicy.availableEncoderBackends(
                  videoCodec: draftVideoCodec,
                  selectedBackend: draftEncoderBackend,
                ),
            onClose: () => Navigator.of(dialogContext).pop(),
            onOpenSource: onOpenSource,
            onSave: () {
              Navigator.of(dialogContext).pop(
                WorkbenchTaskConfigurationDraft(
                  qualityIndex: draftQualityIndex,
                  outputFormat: draftOutputFormat,
                  videoCodec: draftVideoCodec,
                  encoderBackend: draftEncoderBackend,
                  resolutionPreset: draftResolutionPreset,
                  compressionMode: draftCompressionMode,
                  smartPreset: draftSmartPreset,
                  targetSizeRatio: draftTargetSizeRatio,
                  config: draftConfig,
                ),
              );
            },
            onCompressionModeChanged: (value) {
              if (preserveHdrActiveForDraft() &&
                  value == CompressionMode.targetSize) {
                return;
              }
              updateDialogState(() {
                draftCompressionMode = value == CompressionMode.targetSize
                    ? CompressionMode.targetSize
                    : CompressionMode.preset;
                draftTargetSizeRatio =
                    WorkbenchQualityPolicy.normalizeTargetSizeRatio(
                      draftTargetSizeRatio,
                    );
                draftConfig = draftConfig.copyWith(
                  compressionMode: draftCompressionMode,
                );
              });
            },
            onSmartPresetChanged: (value) {
              if (preserveHdrActiveForDraft() &&
                  !isHdrCompatibleSmartPreset(value)) {
                return;
              }
              updateDialogState(() {
                draftSmartPreset = value;
                draftConfig = draftConfig.copyWith(smartPreset: value);
              });
            },
            onTargetSizeRatioChanged: (value) {
              updateDialogState(() {
                draftTargetSizeRatio =
                    WorkbenchQualityPolicy.normalizeTargetSizeRatio(value);
                draftQualityIndex =
                    WorkbenchQualityPolicy.qualityIndexForTargetSizeRatio(
                      draftTargetSizeRatio,
                    );
                draftConfig = draftConfig.copyWith(
                  targetSizeRatio: draftTargetSizeRatio,
                );
              });
            },
            onQualityChanged: (index) {
              if (index == draftQualityIndex) {
                return;
              }
              updateDialogState(() {
                draftQualityIndex = index;
              });
            },
            onOutputFormatChanged: (value) {
              updateDialogState(() {
                draftOutputFormat = value;
                draftConfig = draftConfig.copyWith(
                  outputFormat: value,
                  keepOriginalOutputFormat: value == sourceVideoOutputFormat,
                );
              });
            },
            onVideoCodecChanged: (value) {
              final preservingHdr =
                  draftConfig.video?.hdrOutputMode == HdrOutputMode.preserveHdr;
              if (preservingHdr) {
                value = VideoCodec.hevc;
              }
              final nextEncoderBackend =
                  WorkbenchEncoderPolicy.isBackendCompatibleWithCodec(
                    draftEncoderBackend,
                    value,
                  )
                  ? draftEncoderBackend
                  : EncoderBackend.auto;
              updateDialogState(() {
                draftVideoCodec = value;
                draftEncoderBackend = nextEncoderBackend;
                draftConfig = draftConfig.copyWith(
                  videoCodec: value,
                  encoderBackend: nextEncoderBackend,
                );
              });
            },
            onEncoderBackendChanged: (value) {
              updateDialogState(() {
                draftEncoderBackend = value;
                draftConfig = draftConfig.copyWith(encoderBackend: value);
              });
            },
            onPreserveHdrChanged: (value) {
              updateDialogState(() {
                final currentVideo =
                    draftConfig.video ?? VideoProcessingConfig.initial();
                if (value) {
                  draftVideoCodec = VideoCodec.hevc;
                  final nextBackend =
                      WorkbenchEncoderPolicy.isBackendCompatibleWithCodec(
                        draftEncoderBackend,
                        VideoCodec.hevc,
                      )
                      ? draftEncoderBackend
                      : EncoderBackend.auto;
                  draftEncoderBackend = nextBackend;
                  draftConfig = draftConfig.copyWith(
                    videoCodec: VideoCodec.hevc,
                    encoderBackend: nextBackend,
                    hdrOutputMode: HdrOutputMode.preserveHdr,
                    videoCodecBeforePreserveHdr: currentVideo.videoCodec,
                    encoderBackendBeforePreserveHdr:
                        currentVideo.encoderBackend,
                  );
                  applyHdrRecommendedPreset();
                  return;
                }

                final restoredCodec =
                    currentVideo.videoCodecBeforePreserveHdr ?? VideoCodec.h264;
                final restoredBackend =
                    currentVideo.encoderBackendBeforePreserveHdr ??
                    EncoderBackend.auto;
                final nextBackend =
                    WorkbenchEncoderPolicy.isBackendCompatibleWithCodec(
                      restoredBackend,
                      restoredCodec,
                    )
                    ? restoredBackend
                    : EncoderBackend.auto;
                draftVideoCodec = restoredCodec;
                draftEncoderBackend = nextBackend;
                draftConfig = draftConfig.copyWith(
                  videoCodec: restoredCodec,
                  encoderBackend: nextBackend,
                  hdrOutputMode: HdrOutputMode.convertToSdr,
                  videoCodecBeforePreserveHdr: null,
                  encoderBackendBeforePreserveHdr: null,
                );
              });
            },
            onVideoPreserveMetadataChanged: (value) {
              updateDialogState(() {
                final currentVideo =
                    draftConfig.video ?? VideoProcessingConfig.initial();
                draftConfig = draftConfig.copyWith(
                  video: currentVideo.copyWith(preserveMetadata: value),
                );
              });
            },
            onResolutionPresetChanged: (value) {
              updateDialogState(() {
                draftResolutionPreset = value;
                draftConfig = draftConfig.copyWith(resolutionPreset: value);
              });
            },
            onImageConfigChanged: (value) {
              updateDialogState(() {
                draftConfig = draftConfig.copyWith(image: value);
              });
            },
            onAudioConfigChanged: (value) {
              updateDialogState(() {
                draftConfig = draftConfig.copyWith(audio: value);
              });
            },
          );
        },
      );
    },
  );
}

class WorkbenchTaskConfigurationDialog extends StatefulWidget {
  const WorkbenchTaskConfigurationDialog({
    super.key,
    required this.task,
    required this.thumbnail,
    required this.selectedQualityIndex,
    required this.selectedOutputFormat,
    required this.selectedVideoCodec,
    required this.selectedEncoderBackend,
    required this.selectedResolutionPreset,
    required this.selectedCompressionMode,
    required this.selectedSmartPreset,
    required this.selectedTargetSizeRatio,
    this.selectedVideoConfig,
    this.selectedImageConfig,
    this.selectedAudioConfig,
    required this.availableEncoderBackends,
    required this.onClose,
    required this.onOpenSource,
    required this.onSave,
    required this.onCompressionModeChanged,
    required this.onSmartPresetChanged,
    required this.onTargetSizeRatioChanged,
    required this.onQualityChanged,
    required this.onOutputFormatChanged,
    required this.onVideoCodecChanged,
    required this.onEncoderBackendChanged,
    required this.onResolutionPresetChanged,
    this.onPreserveHdrChanged,
    this.onVideoPreserveMetadataChanged,
    this.onImageConfigChanged,
    this.onAudioConfigChanged,
  });

  final MediaTask task;
  final ImageProvider? thumbnail;
  final int selectedQualityIndex;
  final OutputFormat selectedOutputFormat;
  final VideoCodec selectedVideoCodec;
  final EncoderBackend selectedEncoderBackend;
  final ResolutionPreset selectedResolutionPreset;
  final CompressionMode selectedCompressionMode;
  final SmartCompressionPreset selectedSmartPreset;
  final double selectedTargetSizeRatio;
  final VideoProcessingConfig? selectedVideoConfig;
  final ImageProcessingConfig? selectedImageConfig;
  final AudioProcessingConfig? selectedAudioConfig;
  final List<EncoderBackend> availableEncoderBackends;
  final VoidCallback onClose;
  final VoidCallback onOpenSource;
  final VoidCallback onSave;
  final ValueChanged<CompressionMode> onCompressionModeChanged;
  final ValueChanged<SmartCompressionPreset> onSmartPresetChanged;
  final ValueChanged<double> onTargetSizeRatioChanged;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<OutputFormat> onOutputFormatChanged;
  final ValueChanged<VideoCodec> onVideoCodecChanged;
  final ValueChanged<EncoderBackend> onEncoderBackendChanged;
  final ValueChanged<bool>? onPreserveHdrChanged;
  final ValueChanged<bool>? onVideoPreserveMetadataChanged;
  final ValueChanged<ResolutionPreset> onResolutionPresetChanged;
  final ValueChanged<ImageProcessingConfig>? onImageConfigChanged;
  final ValueChanged<AudioProcessingConfig>? onAudioConfigChanged;

  @override
  State<WorkbenchTaskConfigurationDialog> createState() =>
      _WorkbenchTaskConfigurationDialogState();
}

class _WorkbenchTaskConfigurationDialogState
    extends State<WorkbenchTaskConfigurationDialog> {
  late CompressionMode _mode;
  String? _activePresetTitle;

  static const _recommendedPresets = [
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.balanced,
      qualityIndex: 4,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
    ),
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.chat,
      qualityIndex: 6,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
    ),
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.clear,
      qualityIndex: 3,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
    ),
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.compact,
      qualityIndex: 8,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.hevc,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mode = _effectiveMode(widget.selectedCompressionMode);
    _activePresetTitle = _presetForSmartPreset(
      widget.selectedSmartPreset,
    ).title;
  }

  @override
  void didUpdateWidget(WorkbenchTaskConfigurationDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextMode = _effectiveMode(widget.selectedCompressionMode);
    if (_mode != nextMode) {
      _mode = nextMode;
    }

    final nextPresetTitle = _presetForSmartPreset(
      widget.selectedSmartPreset,
    ).title;
    if (_activePresetTitle != nextPresetTitle) {
      _activePresetTitle = nextPresetTitle;
    }
  }

  CompressionMode _effectiveMode(CompressionMode mode) {
    if (_preserveHdrActive()) {
      return CompressionMode.preset;
    }

    return mode == CompressionMode.targetSize
        ? CompressionMode.targetSize
        : CompressionMode.preset;
  }

  WorkbenchCompressionPreset _presetForSmartPreset(
    SmartCompressionPreset smartPreset,
  ) {
    for (final preset in _recommendedPresets) {
      if (preset.smartPreset == smartPreset) {
        return preset;
      }
    }

    return _recommendedPresets.first;
  }

  void _applyPreset(WorkbenchCompressionPreset preset) {
    if (!_isPresetEnabled(preset)) {
      return;
    }

    setState(() {
      _mode = CompressionMode.preset;
      _activePresetTitle = preset.title;
    });

    widget.onCompressionModeChanged(CompressionMode.preset);
    widget.onSmartPresetChanged(preset.smartPreset);
    widget.onQualityChanged(preset.qualityIndex);
    widget.onOutputFormatChanged(preset.outputFormat);
    widget.onVideoCodecChanged(preset.videoCodec);
    widget.onEncoderBackendChanged(EncoderBackend.auto);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final isVideoTask = widget.task.mediaKind == MediaKind.video;
    final preserveHdr = _preserveHdrActive();
    final modified = _isModified();
    final compressed =
        isVideoTask &&
        WorkbenchFormatters.isSourceAlreadyCompressed(widget.task);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 25, 21),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkbenchDialogBackHeader(
                  title: '任务详情设置',
                  onClose: widget.onClose,
                  trailing: SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      tooltip: '打开源文件所在位置',
                      onPressed: widget.onOpenSource,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: colors.textPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                WorkbenchSourceSummary(
                  task: widget.task,
                  thumbnail: widget.thumbnail,
                ),
                const SizedBox(height: 14),
                if (isVideoTask) ...[
                  WorkbenchCompressionOptionsSection(
                    mode: _mode,
                    presets: _recommendedPresets,
                    selectedQualityIndex: widget.selectedQualityIndex,
                    activePresetTitle: _activePresetTitle,
                    selectedTargetSizeRatio: widget.selectedTargetSizeRatio,
                    estimatedSizeForPreset: _estimatedOutputSizeForPreset,
                    targetSizeModeEnabled: !preserveHdr,
                    isPresetEnabled: _isPresetEnabled,
                    onModeChanged: (mode) {
                      if (preserveHdr && mode == CompressionMode.targetSize) {
                        return;
                      }
                      setState(() {
                        _mode = mode;
                      });
                      widget.onCompressionModeChanged(mode);
                    },
                    onPresetSelected: _applyPreset,
                    onTargetSizeRatioChanged: widget.onTargetSizeRatioChanged,
                  ),
                  const SizedBox(height: 14),
                ],
                _buildMediaConfigPanel(),
                const SizedBox(height: 22),
                WorkbenchDialogActions(
                  leading: WorkbenchTaskConfigurationStatusBadges(
                    modified: modified,
                    compressed: compressed,
                  ),
                  onCancel: widget.onClose,
                  onSave: widget.onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _preserveHdrActive() {
    final videoConfig =
        widget.selectedVideoConfig ??
        widget.task.config.video ??
        VideoProcessingConfig.initial();
    return videoConfig.hdrOutputMode == HdrOutputMode.preserveHdr &&
        widget.task.analysisResult?.isHdr == true;
  }

  bool _isPresetEnabled(WorkbenchCompressionPreset preset) {
    if (!_preserveHdrActive()) {
      return true;
    }

    return preset.smartPreset == SmartCompressionPreset.balanced ||
        preset.smartPreset == SmartCompressionPreset.clear;
  }

  Widget _buildMediaConfigPanel() {
    final sourceOutputFormat = _sourceOutputFormat();

    switch (widget.task.mediaKind) {
      case MediaKind.video:
        final videoConfig =
            widget.selectedVideoConfig ??
            widget.task.config.video ??
            VideoProcessingConfig.initial();
        final preserveHdr =
            videoConfig.hdrOutputMode == HdrOutputMode.preserveHdr &&
            widget.task.analysisResult?.isHdr == true;
        return WorkbenchVideoConfigPanel(
          selectedOutputFormat: widget.selectedOutputFormat,
          selectedVideoCodec: preserveHdr
              ? VideoCodec.hevc
              : widget.selectedVideoCodec,
          selectedEncoderBackend: widget.selectedEncoderBackend,
          selectedResolutionPreset: widget.selectedResolutionPreset,
          availableEncoderBackends: widget.availableEncoderBackends,
          onOutputFormatChanged: widget.onOutputFormatChanged,
          onVideoCodecChanged: widget.onVideoCodecChanged,
          onEncoderBackendChanged: widget.onEncoderBackendChanged,
          onResolutionPresetChanged: widget.onResolutionPresetChanged,
          sourceOutputFormat: sourceOutputFormat?.toVideoOutputFormat(),
          keepOriginalOutputFormat: videoConfig.keepOriginalOutputFormat,
          showPreserveHdrOption: widget.task.analysisResult?.isHdr == true,
          preserveHdr: preserveHdr,
          onPreserveHdrChanged: widget.onPreserveHdrChanged,
          preserveMetadata: videoConfig.preserveMetadata,
          onPreserveMetadataChanged: widget.onVideoPreserveMetadataChanged,
          videoCodecValues: preserveHdr
              ? const [VideoCodec.hevc]
              : const [VideoCodec.h264, VideoCodec.hevc],
          videoCodecEnabled: !preserveHdr,
          showEncoderBackend: false,
          resolutionValues: _resolutionValues(),
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: 34,
          showTrailingText: false,
          resolutionLabelBuilder: _resolutionLabel,
          labelFontSize: 12,
          valueFontSize: 12,
        );
      case MediaKind.image:
        final imageConfig =
            widget.selectedImageConfig ??
            widget.task.config.image ??
            ImageProcessingConfig.initial();
        return WorkbenchImageConfigPanel(
          config: imageConfig,
          onChanged: widget.onImageConfigChanged ?? (_) {},
          sourceOutputFormat: sourceOutputFormat,
          sourceWidth:
              widget.task.analysisResult?.imageWidth ??
              widget.task.analysisResult?.videoWidth,
          sourceHeight:
              widget.task.analysisResult?.imageHeight ??
              widget.task.analysisResult?.videoHeight,
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: 34,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
        );
      case MediaKind.audio:
        final audioConfig =
            widget.selectedAudioConfig ??
            widget.task.config.audio ??
            AudioProcessingConfig.initial();
        return WorkbenchAudioConfigPanel(
          config: audioConfig,
          onChanged: widget.onAudioConfigChanged ?? (_) {},
          sourceOutputFormat: sourceOutputFormat,
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: 34,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
        );
    }
  }

  bool _isModified() {
    switch (widget.task.mediaKind) {
      case MediaKind.video:
        final adjustedFromSource =
            WorkbenchTaskAdjustmentPolicy.isAdjustedFromSource(
              task: widget.task,
              outputFormat: widget.selectedOutputFormat,
              videoCodec: widget.selectedVideoCodec,
              resolutionPreset: widget.selectedResolutionPreset,
            );
        final initial = widget.task.config.video;
        final current = widget.selectedVideoConfig;
        return adjustedFromSource ||
            (initial != null &&
                current != null &&
                _videoConfigChanged(initial, current));
      case MediaKind.image:
        final initial = widget.task.config.image;
        final current = widget.selectedImageConfig;
        return initial != null &&
            current != null &&
            _imageConfigChanged(initial, current);
      case MediaKind.audio:
        final initial = widget.task.config.audio;
        final current = widget.selectedAudioConfig;
        return initial != null &&
            current != null &&
            _audioConfigChanged(initial, current);
    }
  }

  bool _imageConfigChanged(
    ImageProcessingConfig initial,
    ImageProcessingConfig current,
  ) {
    return initial.outputFormat != current.outputFormat ||
        initial.imageQuality != current.imageQuality ||
        initial.resizePreset != current.resizePreset ||
        initial.preserveMetadata != current.preserveMetadata;
  }

  bool _videoConfigChanged(
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
        initial.preserveMetadata != current.preserveMetadata;
  }

  bool _audioConfigChanged(
    AudioProcessingConfig initial,
    AudioProcessingConfig current,
  ) {
    return initial.outputFormat != current.outputFormat ||
        initial.bitratePreset != current.bitratePreset ||
        initial.sampleRate != current.sampleRate ||
        initial.channels != current.channels ||
        initial.preserveMetadata != current.preserveMetadata;
  }

  String _estimatedOutputSizeForPreset(WorkbenchCompressionPreset preset) {
    if (WorkbenchFormatters.isSourceAlreadyCompressed(widget.task)) {
      return '';
    }

    final estimate = const DefaultCompressionEstimator().estimateSmartPreset(
      task: widget.task,
      preset: preset.smartPreset,
      targetCodec: preset.videoCodec,
      targetResolutionPreset: widget.selectedResolutionPreset,
    );
    if (estimate == null) {
      return '-';
    }

    return '约 ${WorkbenchFormatters.formatBytes(estimate.expectedBytes)}';
  }

  String _resolutionLabel(ResolutionPreset value) {
    if (value == ResolutionPreset.original) {
      final width = widget.task.analysisResult?.videoWidth;
      final height = widget.task.analysisResult?.videoHeight;
      if (width != null && height != null) {
        return '$width × $height（保持原始）';
      }
    }

    return value.label.replaceAll('x', ' × ');
  }

  MediaOutputFormat? _sourceOutputFormat() {
    return mediaOutputFormatForSourceFileName(
      sourceFileName: widget.task.inputPath,
      mediaKind: widget.task.mediaKind,
    );
  }

  List<ResolutionPreset> _resolutionValues() {
    final width = widget.task.analysisResult?.videoWidth;
    final height = widget.task.analysisResult?.videoHeight;
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

      final size = _resolutionPresetSize(preset);
      if (width == null || height == null || size == null) {
        return true;
      }

      return width != size.width || height != size.height;
    }).toList();
  }

  ({int width, int height})? _resolutionPresetSize(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.original => null,
      ResolutionPreset.p2160 => (width: 3840, height: 2160),
      ResolutionPreset.p1080 => (width: 1920, height: 1080),
      ResolutionPreset.p720 => (width: 1280, height: 720),
      ResolutionPreset.p480 => (width: 854, height: 480),
    };
  }
}
