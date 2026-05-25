import 'package:flutter/material.dart';
import 'package:machining/application/services/ffmpeg_planning/compression_estimator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog_widgets.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/video_config_panel.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:machining/features/workbench/presentation_mappers/domain_labels.dart';

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
  });

  final int qualityIndex;
  final OutputFormat outputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final ResolutionPreset resolutionPreset;
  final CompressionMode compressionMode;
  final SmartCompressionPreset smartPreset;
  final double targetSizeRatio;
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
              });
            },
            onSmartPresetChanged: (value) {
              updateDialogState(() {
                draftSmartPreset = value;
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
              });
            },
            onEncoderBackendChanged: (value) {
              updateDialogState(() {
                draftEncoderBackend = value;
              });
            },
            onResolutionPresetChanged: (value) {
              updateDialogState(() {
                draftResolutionPreset = value;
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
    final modified = WorkbenchTaskAdjustmentPolicy.isAdjustedFromSource(
      task: widget.task,
      outputFormat: widget.selectedOutputFormat,
      videoCodec: widget.selectedVideoCodec,
      resolutionPreset: widget.selectedResolutionPreset,
    );
    final compressed = WorkbenchFormatters.isSourceAlreadyCompressed(
      widget.task,
    );

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
                WorkbenchVideoConfigPanel(
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
                ),
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
