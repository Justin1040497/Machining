import 'package:flutter/cupertino.dart';
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
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/two_pass_mode.dart';
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
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/form_controls/config_dropdown.dart';

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

Future<WorkbenchTaskConfigurationDraft?> showWorkbenchTaskConfigurationEditor({
  required BuildContext context,
  required MediaTask task,
  required ImageProvider? thumbnail,
  String title = '任务详情设置',
  required int selectedQualityIndex,
  required OutputFormat selectedOutputFormat,
  required VideoCodec selectedVideoCodec,
  required EncoderBackend selectedEncoderBackend,
  required ResolutionPreset selectedResolutionPreset,
  required CompressionMode selectedCompressionMode,
  required SmartCompressionPreset selectedSmartPreset,
  required double selectedTargetSizeRatio,
  VoidCallback? onOpenSource,
}) {
  var draftPurpose = task.purpose;
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
            title: title,
            selectedQualityIndex: draftQualityIndex,
            selectedOutputFormat: draftOutputFormat,
            selectedVideoCodec: draftVideoCodec,
            selectedEncoderBackend: draftEncoderBackend,
            selectedResolutionPreset: draftResolutionPreset,
            selectedCompressionMode: draftCompressionMode,
            selectedSmartPreset: draftSmartPreset,
            selectedTargetSizeRatio: draftTargetSizeRatio,
            selectedPurpose: draftPurpose,
            selectedConfig: draftConfig,
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
                  purpose: draftPurpose,
                  config: draftConfig,
                ),
              );
            },
            onPurposeChanged: (value) {
              updateDialogState(() {
                draftPurpose = value;
              });
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
            onThreadLimitChanged: (value) {
              updateDialogState(() {
                draftConfig = draftConfig.copyWith(threadLimit: value);
              });
            },
            onTwoPassModeChanged: (value) {
              updateDialogState(() {
                final currentVideo =
                    draftConfig.video ?? VideoProcessingConfig.initial();
                draftConfig = draftConfig.copyWith(
                  video: currentVideo.copyWith(twoPassMode: value),
                );
              });
            },
            onSelectedAudioStreamIndexChanged: (value) {
              updateDialogState(() {
                final currentVideo =
                    draftConfig.video ?? VideoProcessingConfig.initial();
                draftConfig = draftConfig.copyWith(
                  video: currentVideo.copyWith(selectedAudioStreamIndex: value),
                );
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
    this.title = '任务详情设置',
    required this.selectedQualityIndex,
    required this.selectedOutputFormat,
    required this.selectedVideoCodec,
    required this.selectedEncoderBackend,
    required this.selectedResolutionPreset,
    required this.selectedCompressionMode,
    required this.selectedSmartPreset,
    required this.selectedTargetSizeRatio,
    this.selectedPurpose = TaskPurpose.compression,
    this.selectedConfig,
    this.selectedVideoConfig,
    this.selectedImageConfig,
    this.selectedAudioConfig,
    required this.availableEncoderBackends,
    required this.onClose,
    this.onOpenSource,
    required this.onSave,
    this.onPurposeChanged,
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
    this.onThreadLimitChanged,
    this.onTwoPassModeChanged,
    this.onSelectedAudioStreamIndexChanged,
  });

  final MediaTask task;
  final ImageProvider? thumbnail;
  final String title;
  final int selectedQualityIndex;
  final OutputFormat selectedOutputFormat;
  final VideoCodec selectedVideoCodec;
  final EncoderBackend selectedEncoderBackend;
  final ResolutionPreset selectedResolutionPreset;
  final CompressionMode selectedCompressionMode;
  final SmartCompressionPreset selectedSmartPreset;
  final double selectedTargetSizeRatio;
  final TaskPurpose selectedPurpose;
  final MediaTaskConfig? selectedConfig;
  final VideoProcessingConfig? selectedVideoConfig;
  final ImageProcessingConfig? selectedImageConfig;
  final AudioProcessingConfig? selectedAudioConfig;
  final List<EncoderBackend> availableEncoderBackends;
  final VoidCallback onClose;
  final VoidCallback? onOpenSource;
  final VoidCallback onSave;
  final ValueChanged<TaskPurpose>? onPurposeChanged;
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
  final ValueChanged<int?>? onThreadLimitChanged;
  final ValueChanged<TwoPassMode>? onTwoPassModeChanged;
  final ValueChanged<int?>? onSelectedAudioStreamIndexChanged;

  @override
  State<WorkbenchTaskConfigurationDialog> createState() =>
      _WorkbenchTaskConfigurationDialogState();
}

class _WorkbenchTaskConfigurationDialogState
    extends State<WorkbenchTaskConfigurationDialog> {
  static const _scrollbarThickness = 4.0;
  static const _scrollbarGutter = 12.0;

  final ScrollController _bodyScrollController = ScrollController();
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

  @override
  void dispose() {
    _bodyScrollController.dispose();
    super.dispose();
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
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 25, 21),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: WorkbenchDialogBackHeader(
                    title: widget.title,
                    onClose: widget.onClose,
                    trailing: widget.onOpenSource == null
                        ? null
                        : SizedBox(
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
                ),
                Positioned.fill(
                  top: 46,
                  bottom: 50,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: Scrollbar(
                      controller: _bodyScrollController,
                      thumbVisibility: false,
                      trackVisibility: false,
                      thickness: _scrollbarThickness,
                      radius: const Radius.circular(4),
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _bodyScrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(right: _scrollbarGutter),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WorkbenchSourceSummary(
                              task: widget.task,
                              thumbnail: widget.thumbnail,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child:
                                  CupertinoSlidingSegmentedControl<TaskPurpose>(
                                    groupValue: widget.selectedPurpose,
                                    backgroundColor: colors.surfaceDisabled,
                                    thumbColor: colors.surface,
                                    padding: const EdgeInsets.all(3),
                                    children: const {
                                      TaskPurpose.compression: Text('压缩'),
                                      TaskPurpose.conversion: Text('格式转换'),
                                    },
                                    onValueChanged: (value) {
                                      if (value != null) {
                                        widget.onPurposeChanged?.call(value);
                                      }
                                    },
                                  ),
                            ),
                            const SizedBox(height: 14),
                            if (isVideoTask &&
                                widget.selectedPurpose ==
                                    TaskPurpose.compression) ...[
                              WorkbenchCompressionOptionsSection(
                                mode: _mode,
                                presets: _recommendedPresets,
                                selectedQualityIndex:
                                    widget.selectedQualityIndex,
                                activePresetTitle: _activePresetTitle,
                                selectedTargetSizeRatio:
                                    widget.selectedTargetSizeRatio,
                                estimatedSizeForPreset:
                                    _estimatedOutputSizeForPreset,
                                targetSizeModeEnabled: !preserveHdr,
                                isPresetEnabled: _isPresetEnabled,
                                onModeChanged: (mode) {
                                  if (preserveHdr &&
                                      mode == CompressionMode.targetSize) {
                                    return;
                                  }
                                  setState(() {
                                    _mode = mode;
                                  });
                                  widget.onCompressionModeChanged(mode);
                                },
                                onPresetSelected: _applyPreset,
                                onTargetSizeRatioChanged:
                                    widget.onTargetSizeRatioChanged,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _buildMediaConfigPanel(),
                            const SizedBox(height: 14),
                            _AdvancedTaskSettingsSection(
                              task: widget.task,
                              selectedConfig: _selectedMediaTaskConfig(),
                              selectedVideoConfig:
                                  widget.selectedVideoConfig ??
                                  widget.task.config.video,
                              onThreadLimitChanged:
                                  widget.onThreadLimitChanged ?? (_) {},
                              onTwoPassModeChanged:
                                  widget.onTwoPassModeChanged ?? (_) {},
                              onSelectedAudioStreamIndexChanged:
                                  widget.onSelectedAudioStreamIndexChanged ??
                                  (_) {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: WorkbenchDialogActions(
                    leading: WorkbenchTaskConfigurationStatusBadges(
                      modified: modified,
                      compressed: compressed,
                    ),
                    onCancel: widget.onClose,
                    onSave: widget.onSave,
                  ),
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
          showLosslessCompression:
              widget.selectedPurpose == TaskPurpose.compression,
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
    if (widget.task.purpose != widget.selectedPurpose ||
        widget.task.config.threadLimit !=
            _selectedMediaTaskConfig().threadLimit) {
      return true;
    }

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
        initial.keepOriginalOutputFormat != current.keepOriginalOutputFormat ||
        initial.losslessCompression != current.losslessCompression ||
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
        initial.preserveMetadata != current.preserveMetadata ||
        initial.twoPassMode != current.twoPassMode ||
        initial.selectedAudioStreamIndex != current.selectedAudioStreamIndex;
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

  MediaTaskConfig _selectedMediaTaskConfig() {
    return widget.selectedConfig ?? widget.task.config;
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

class _AdvancedTaskSettingsSection extends StatelessWidget {
  const _AdvancedTaskSettingsSection({
    required this.task,
    required this.selectedConfig,
    required this.selectedVideoConfig,
    required this.onThreadLimitChanged,
    required this.onTwoPassModeChanged,
    required this.onSelectedAudioStreamIndexChanged,
  });

  final MediaTask task;
  final MediaTaskConfig selectedConfig;
  final VideoProcessingConfig? selectedVideoConfig;
  final ValueChanged<int?> onThreadLimitChanged;
  final ValueChanged<TwoPassMode> onTwoPassModeChanged;
  final ValueChanged<int?> onSelectedAudioStreamIndexChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final videoConfig =
        selectedVideoConfig ??
        task.config.video ??
        VideoProcessingConfig.initial();
    final audioStreams = task.analysisResult?.audioStreams ?? const [];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: colors.border),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedIconColor: colors.iconMuted,
          iconColor: colors.textPrimary,
          title: Text(
            '高级设置',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.flSp,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            ConfigDropdown<int>(
              label: '线程限制',
              trailingText: '',
              value: _threadLimitValue(selectedConfig.threadLimit),
              values: const [0, 1, 2, 3, 4, 6, 8],
              itemLabel: (value) => value == 0 ? '自动' : '$value 线程',
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                onThreadLimitChanged(value == 0 ? null : value);
              },
              height: 34,
              showTrailingText: false,
              labelFontSize: 12,
              valueFontSize: 12,
            ),
            if (task.mediaKind == MediaKind.video) ...[
              const SizedBox(height: 12),
              ConfigDropdown<TwoPassMode>(
                label: '两遍压缩',
                trailingText: '',
                value: videoConfig.twoPassMode,
                values: TwoPassMode.values,
                itemLabel: _twoPassModeLabel,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  onTwoPassModeChanged(value);
                },
                height: 34,
                showTrailingText: false,
                labelFontSize: 12,
                valueFontSize: 12,
              ),
              if (audioStreams.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConfigDropdown<int>(
                  label: '音频流',
                  trailingText: '',
                  value: _audioStreamValue(
                    videoConfig.selectedAudioStreamIndex,
                    audioStreams.map((stream) => stream.index),
                  ),
                  values: [-1, ...audioStreams.map((stream) => stream.index)],
                  itemLabel: (value) {
                    if (value == -1) {
                      return '自动';
                    }
                    final stream = audioStreams.firstWhere(
                      (stream) => stream.index == value,
                      orElse: () => audioStreams.first,
                    );
                    return stream.displayLabel;
                  },
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    onSelectedAudioStreamIndexChanged(
                      value == -1 ? null : value,
                    );
                  },
                  height: 34,
                  showTrailingText: false,
                  labelFontSize: 12,
                  valueFontSize: 12,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  int _threadLimitValue(int? value) {
    const supportedValues = [0, 1, 2, 3, 4, 6, 8];
    final normalized = value ?? 0;
    return supportedValues.contains(normalized) ? normalized : 0;
  }

  int _audioStreamValue(int? value, Iterable<int> availableValues) {
    if (value == null) {
      return -1;
    }
    return availableValues.contains(value) ? value : -1;
  }

  String _twoPassModeLabel(TwoPassMode mode) {
    return switch (mode) {
      TwoPassMode.automatic => '自动',
      TwoPassMode.enabled => '开启',
      TwoPassMode.disabled => '关闭',
    };
  }
}
