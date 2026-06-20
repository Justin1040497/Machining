import 'dart:io';

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
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/two_pass_mode.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/domain/value_objects/video_output_compatibility.dart';
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
import 'package:framelean/app/widgets/form_controls/config_checkbox.dart';
import 'package:framelean/app/widgets/form_controls/path_field.dart';

const _taskConfigFieldHeight = 40.0;
const _taskConfigSegmentedControlHeight = 42.0;

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
  Widget? sourceSummary,
  String title = '任务详情设置',
  bool showOutputLocationInMain = false,
  String systemOutputDirectoryLabel = '使用应用设置',
  Future<String?> Function()? onPickOutputDirectory,
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
            sourceSummary: sourceSummary,
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
            showOutputLocationInMain: showOutputLocationInMain,
            systemOutputDirectoryLabel: systemOutputDirectoryLabel,
            onPickOutputDirectory: onPickOutputDirectory,
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
                if (task.mediaKind == MediaKind.video &&
                    !VideoOutputCompatibility.supports(
                      value,
                      draftVideoCodec,
                    )) {
                  draftVideoCodec = VideoOutputCompatibility.defaultCodecFor(
                    value,
                  );
                  draftEncoderBackend = EncoderBackend.auto;
                }
                draftConfig = draftConfig.copyWith(
                  outputFormat: value,
                  videoCodec: draftVideoCodec,
                  encoderBackend: draftEncoderBackend,
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
            onOutputLocationChanged: (mode, directory) {
              updateDialogState(() {
                draftConfig = draftConfig.copyWith(
                  outputLocationMode: mode,
                  outputDirectory: directory,
                );
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
    this.sourceSummary,
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
    this.showOutputLocationInMain = false,
    this.systemOutputDirectoryLabel = '使用应用设置',
    this.onPickOutputDirectory,
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
    this.onOutputLocationChanged,
    this.onTwoPassModeChanged,
    this.onSelectedAudioStreamIndexChanged,
  });

  final MediaTask task;
  final ImageProvider? thumbnail;
  final Widget? sourceSummary;
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
  final bool showOutputLocationInMain;
  final String systemOutputDirectoryLabel;
  final Future<String?> Function()? onPickOutputDirectory;
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
  final void Function(OutputLocationMode mode, String directory)?
  onOutputLocationChanged;
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
  String? _outputLocationError;

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
                  bottom: 56,
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
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(
                          2,
                          0,
                          _scrollbarGutter,
                          0,
                        ),
                        child: SingleChildScrollView(
                          controller: _bodyScrollController,
                          physics: const ClampingScrollPhysics(),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              widget.sourceSummary ??
                                  WorkbenchSourceSummary(
                                    task: widget.task,
                                    thumbnail: widget.thumbnail,
                                  ),
                              if (widget.showOutputLocationInMain) ...[
                                const SizedBox(height: 14),
                                _OutputLocationSection(
                                  config: _selectedMediaTaskConfig(),
                                  systemOutputDirectoryLabel:
                                      widget.systemOutputDirectoryLabel,
                                  onChanged:
                                      widget.onOutputLocationChanged ??
                                      (_, _) {},
                                  onPickDirectory: widget.onPickOutputDirectory,
                                  errorText: _outputLocationError,
                                ),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: _taskConfigSegmentedControlHeight,
                                child:
                                    CupertinoSlidingSegmentedControl<
                                      TaskPurpose
                                    >(
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
                                  targetSizeModeEnabled:
                                      !preserveHdr &&
                                      VideoOutputCompatibility.supportsTargetSize(
                                        widget.selectedVideoCodec,
                                      ),
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
                                selectedPurpose: widget.selectedPurpose,
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
                                preserveMetadata: _preserveMetadata(),
                                onPreserveMetadataChanged:
                                    _onPreserveMetadataChanged,
                                showOutputLocation:
                                    !widget.showOutputLocationInMain,
                                systemOutputDirectoryLabel:
                                    widget.systemOutputDirectoryLabel,
                                onOutputLocationChanged:
                                    widget.onOutputLocationChanged ?? (_, _) {},
                                onPickOutputDirectory:
                                    widget.onPickOutputDirectory,
                                outputLocationError: _outputLocationError,
                              ),
                            ],
                          ),
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
                    onSave: _handleSave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    final config = _selectedMediaTaskConfig();
    if (config.outputLocationMode == OutputLocationMode.custom &&
        config.outputDirectory.trim().isEmpty) {
      setState(() {
        _outputLocationError = '请选择或填写输出目录';
      });
      return;
    }
    widget.onSave();
  }

  bool _preserveHdrActive() {
    final videoConfig =
        widget.selectedVideoConfig ??
        widget.task.config.video ??
        VideoProcessingConfig.initial();
    return videoConfig.hdrOutputMode == HdrOutputMode.preserveHdr &&
        widget.task.analysisResult?.isHdr == true;
  }

  bool _preserveMetadata() {
    return switch (widget.task.mediaKind) {
      MediaKind.video =>
        (widget.selectedVideoConfig ?? widget.task.config.video)
                ?.preserveMetadata ??
            true,
      MediaKind.image =>
        (widget.selectedImageConfig ?? widget.task.config.image)
                ?.preserveMetadata ??
            true,
      MediaKind.audio =>
        (widget.selectedAudioConfig ?? widget.task.config.audio)
                ?.preserveMetadata ??
            true,
    };
  }

  void _onPreserveMetadataChanged(bool value) {
    switch (widget.task.mediaKind) {
      case MediaKind.video:
        widget.onVideoPreserveMetadataChanged?.call(value);
      case MediaKind.image:
        final config =
            widget.selectedImageConfig ??
            widget.task.config.image ??
            ImageProcessingConfig.initial();
        widget.onImageConfigChanged?.call(
          config.copyWith(preserveMetadata: value),
        );
      case MediaKind.audio:
        final config =
            widget.selectedAudioConfig ??
            widget.task.config.audio ??
            AudioProcessingConfig.initial();
        widget.onAudioConfigChanged?.call(
          config.copyWith(preserveMetadata: value),
        );
    }
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

    if (widget.selectedPurpose == TaskPurpose.conversion) {
      switch (widget.task.mediaKind) {
        case MediaKind.video:
          return WorkbenchConversionFormatPanel<OutputFormat>(
            label: '目标格式',
            value: widget.selectedOutputFormat,
            values: _videoOutputFormats(),
            itemLabel: (value) => value.label,
            onChanged: widget.onOutputFormatChanged,
          );
        case MediaKind.image:
          final imageConfig =
              widget.selectedImageConfig ??
              widget.task.config.image ??
              ImageProcessingConfig.initial();
          return WorkbenchConversionFormatPanel<MediaOutputFormat>(
            label: '目标格式',
            value: imageConfig.outputFormat,
            values: MediaOutputFormat.formatsFor(MediaKind.image),
            itemLabel: (value) => value.label,
            onChanged: (value) {
              widget.onImageConfigChanged?.call(
                imageConfig.copyWith(
                  outputFormat: value,
                  keepOriginalOutputFormat: false,
                  losslessCompression: false,
                  imageQuality: 100,
                  resizePreset: ImageResizePreset.original,
                ),
              );
            },
          );
        case MediaKind.audio:
          final audioConfig =
              widget.selectedAudioConfig ??
              widget.task.config.audio ??
              AudioProcessingConfig.initial();
          return WorkbenchConversionFormatPanel<MediaOutputFormat>(
            label: '目标格式',
            value: audioConfig.outputFormat,
            values: MediaOutputFormat.formatsFor(MediaKind.audio),
            itemLabel: (value) => value.label,
            onChanged: (value) {
              widget.onAudioConfigChanged?.call(
                audioConfig.copyWith(
                  outputFormat: value,
                  keepOriginalOutputFormat: false,
                  bitratePreset: AudioBitratePreset.source,
                  sampleRate: AudioSampleRatePreset.source,
                  channels: AudioChannelsPreset.source,
                ),
              );
            },
          );
      }
    }

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
              : VideoOutputCompatibility.codecsFor(widget.selectedOutputFormat),
          videoCodecEnabled: !preserveHdr,
          showEncoderBackend: false,
          resolutionValues: _resolutionValues(),
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: _taskConfigFieldHeight,
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
          dropdownHeight: _taskConfigFieldHeight,
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
          dropdownHeight: _taskConfigFieldHeight,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
        );
    }
  }

  List<OutputFormat> _videoOutputFormats() {
    if (_sourceHasAlpha()) {
      return const [OutputFormat.mov];
    }
    return OutputFormat.values;
  }

  bool _sourceHasAlpha() {
    final pixelFormat = widget.task.analysisResult?.videoPixelFormat
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
    required this.selectedPurpose,
    required this.selectedConfig,
    required this.selectedVideoConfig,
    required this.onThreadLimitChanged,
    required this.onTwoPassModeChanged,
    required this.onSelectedAudioStreamIndexChanged,
    required this.preserveMetadata,
    required this.onPreserveMetadataChanged,
    required this.showOutputLocation,
    required this.systemOutputDirectoryLabel,
    required this.onOutputLocationChanged,
    this.onPickOutputDirectory,
    this.outputLocationError,
  });

  final MediaTask task;
  final TaskPurpose selectedPurpose;
  final MediaTaskConfig selectedConfig;
  final VideoProcessingConfig? selectedVideoConfig;
  final ValueChanged<int?> onThreadLimitChanged;
  final ValueChanged<TwoPassMode> onTwoPassModeChanged;
  final ValueChanged<int?> onSelectedAudioStreamIndexChanged;
  final bool preserveMetadata;
  final ValueChanged<bool> onPreserveMetadataChanged;
  final bool showOutputLocation;
  final String systemOutputDirectoryLabel;
  final void Function(OutputLocationMode mode, String directory)
  onOutputLocationChanged;
  final Future<String?> Function()? onPickOutputDirectory;
  final String? outputLocationError;

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
            if (showOutputLocation) ...[
              _OutputLocationSection(
                config: selectedConfig,
                systemOutputDirectoryLabel: systemOutputDirectoryLabel,
                onChanged: onOutputLocationChanged,
                onPickDirectory: onPickOutputDirectory,
                errorText: outputLocationError,
              ),
              const SizedBox(height: 12),
            ],
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
              height: _taskConfigFieldHeight,
              showTrailingText: false,
              labelFontSize: 12,
              valueFontSize: 12,
            ),
            if (selectedPurpose == TaskPurpose.conversion) ...[
              const SizedBox(height: 12),
              ConfigCheckbox(
                label: '保留元数据',
                value: preserveMetadata,
                height: _taskConfigFieldHeight,
                fontSize: 12,
                onChanged: onPreserveMetadataChanged,
              ),
            ],
            if (task.mediaKind == MediaKind.video &&
                selectedPurpose == TaskPurpose.compression) ...[
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
                height: _taskConfigFieldHeight,
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
                  height: _taskConfigFieldHeight,
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

class _OutputLocationSection extends StatefulWidget {
  const _OutputLocationSection({
    required this.config,
    required this.systemOutputDirectoryLabel,
    required this.onChanged,
    this.onPickDirectory,
    this.errorText,
  });

  final MediaTaskConfig config;
  final String systemOutputDirectoryLabel;
  final void Function(OutputLocationMode mode, String directory) onChanged;
  final Future<String?> Function()? onPickDirectory;
  final String? errorText;

  @override
  State<_OutputLocationSection> createState() => _OutputLocationSectionState();
}

class _OutputLocationSectionState extends State<_OutputLocationSection> {
  late final TextEditingController _controller;
  late final TextEditingController _effectiveController;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.config.outputDirectory);
    _effectiveController = TextEditingController();
    _syncEffectiveText();
  }

  @override
  void didUpdateWidget(_OutputLocationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.config.outputDirectory) {
      _controller.text = widget.config.outputDirectory;
    }
    _syncEffectiveText();
  }

  @override
  void dispose() {
    _controller.dispose();
    _effectiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.config.outputLocationMode;
    final enabled = mode == OutputLocationMode.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ConfigCheckbox(
                label: '保存到源文件旁',
                value: mode == OutputLocationMode.source,
                onChanged: (value) {
                  widget.onChanged(
                    value
                        ? OutputLocationMode.source
                        : OutputLocationMode.custom,
                    _controller.text.trim(),
                  );
                },
              ),
            ),
            Expanded(
              child: ConfigCheckbox(
                label: '使用系统设置',
                value: mode == OutputLocationMode.system,
                onChanged: (value) {
                  widget.onChanged(
                    value
                        ? OutputLocationMode.system
                        : OutputLocationMode.custom,
                    _controller.text.trim(),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PathField(
          controller: enabled ? _controller : _effectiveController,
          enabled: enabled,
          hintText: '选择输出目录',
          highlighted: _dragging,
          trailingIcon: Icons.folder_open_rounded,
          height: _taskConfigFieldHeight,
          onChanged: (value) {
            widget.onChanged(OutputLocationMode.custom, value);
          },
          onTrailingTap: () async {
            final selected = await widget.onPickDirectory?.call();
            if (selected == null || selected.trim().isEmpty) {
              return;
            }
            _controller.text = selected.trim();
            widget.onChanged(OutputLocationMode.custom, selected.trim());
          },
          onDraggingChanged: (value) {
            setState(() => _dragging = value);
          },
          onDropped: (items) async {
            if (items.isEmpty) {
              return;
            }
            final droppedPath = items.first.path;
            final type = await FileSystemEntity.type(droppedPath);
            if (!mounted) {
              return;
            }
            setState(() => _dragging = false);
            if (type == FileSystemEntityType.directory) {
              _controller.text = droppedPath;
              widget.onChanged(OutputLocationMode.custom, droppedPath);
            }
          },
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 5),
          Text(
            widget.errorText!,
            style: TextStyle(
              color: context.frameLeanColors.statusFailed,
              fontSize: 10.flSp,
            ),
          ),
        ],
      ],
    );
  }

  void _syncEffectiveText() {
    _effectiveController.text =
        widget.config.outputLocationMode == OutputLocationMode.source
        ? '每个源文件所在目录'
        : widget.systemOutputDirectoryLabel;
  }
}
