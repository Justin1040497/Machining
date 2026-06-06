import 'package:flutter/material.dart';
import 'package:framelean/application/services/ffmpeg_planning/compression_estimator.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/audio_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/image_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/video_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';

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
                draftConfig = draftConfig.copyWith(outputFormat: value);
              });
            },
            onVideoCodecChanged: (value) {
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
    _mode = widget.selectedCompressionMode == CompressionMode.targetSize
        ? CompressionMode.targetSize
        : CompressionMode.preset;
    _activePresetTitle = _presetForSmartPreset(
      widget.selectedSmartPreset,
    ).title;
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
    final isVideoTask = widget.task.mediaKind == MediaKind.video;
    final modified = _isModified();
    final compressed =
        isVideoTask &&
        WorkbenchFormatters.isSourceAlreadyCompressed(widget.task);

    return Dialog(
      backgroundColor: Colors.white,
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
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.black,
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
                    onModeChanged: (mode) {
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

  Widget _buildMediaConfigPanel() {
    switch (widget.task.mediaKind) {
      case MediaKind.video:
        return WorkbenchVideoConfigPanel(
          selectedOutputFormat: widget.selectedOutputFormat,
          selectedVideoCodec: widget.selectedVideoCodec,
          selectedEncoderBackend: widget.selectedEncoderBackend,
          selectedResolutionPreset: widget.selectedResolutionPreset,
          availableEncoderBackends: widget.availableEncoderBackends,
          onOutputFormatChanged: widget.onOutputFormatChanged,
          onVideoCodecChanged: widget.onVideoCodecChanged,
          onEncoderBackendChanged: widget.onEncoderBackendChanged,
          onResolutionPresetChanged: widget.onResolutionPresetChanged,
          showEncoderBackend: false,
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
        return WorkbenchTaskAdjustmentPolicy.isAdjustedFromSource(
          task: widget.task,
          outputFormat: widget.selectedOutputFormat,
          videoCodec: widget.selectedVideoCodec,
          resolutionPreset: widget.selectedResolutionPreset,
        );
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

  bool _audioConfigChanged(
    AudioProcessingConfig initial,
    AudioProcessingConfig current,
  ) {
    return initial.outputFormat != current.outputFormat ||
        initial.bitratePreset != current.bitratePreset ||
        initial.sampleRate != current.sampleRate ||
        initial.channels != current.channels;
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
        return '$width * $height';
      }
    }

    return value.label.replaceAll('x', ' * ');
  }
}
