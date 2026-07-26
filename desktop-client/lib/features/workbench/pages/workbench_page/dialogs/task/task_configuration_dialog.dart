import 'dart:io';

import 'package:flutter/material.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_policies.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/config/audio_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/config/image_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/config/video_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_state.dart';
export 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_state.dart'
    show WorkbenchTaskConfigurationDraft;
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_template.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_configuration_dialog_widgets.dart';

import 'package:framelean/features/workbench/workbench_icons.dart';

const _taskConfigFieldHeight = 40.0;

/// Legacy folder-default editor retained during the Engine migration.
///
/// Individual tasks must use `showEngineTaskConfigurationEditor`; this editor
/// cannot consume an FLL AnalysisSnapshot and must not be used as a fallback.
Future<WorkbenchTaskConfigurationDraft?> showTaskFolderConfigurationEditor({
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
  var state = TaskConfigDialogState.fromTask(
    task: task,
    selectedQualityIndex: selectedQualityIndex,
    selectedOutputFormat: selectedOutputFormat,
    selectedVideoCodec: selectedVideoCodec,
    selectedEncoderBackend: selectedEncoderBackend,
    selectedResolutionPreset: selectedResolutionPreset,
    selectedCompressionMode: selectedCompressionMode,
    selectedSmartPreset: selectedSmartPreset,
    selectedTargetSizeRatio: selectedTargetSizeRatio,
  );
  state = state.normalizeHdrRestrictedChoices(task: task);

  final sourceOutputFormat = mediaOutputFormatForSourceFileName(
    sourceFileName: task.inputPath,
    mediaKind: task.mediaKind,
  );
  final sourceVideoOutputFormat = task.mediaKind == MediaKind.video
      ? sourceOutputFormat?.toVideoOutputFormat()
      : null;

  return showDialog<WorkbenchTaskConfigurationDraft>(
    context: context,
    builder: (dialogContext) {
      String? outputLocationError;

      return StatefulBuilder(
        builder: (dialogContext, refreshDialog) {
          void updateState(TaskConfigDialogState next) {
            refreshDialog(() {
              state = next;
            });
          }

          final isVideoTask = task.mediaKind == MediaKind.video;
          final preserveHdr = state.preserveHdrActive(task);
          final modified = state.isModified(task: task);
          final compressed =
              isVideoTask &&
              WorkbenchFormatters.isSourceAlreadyCompressed(task);

          // ---- build slot widgets ----

          Widget buildMediaConfigPanel() {
            final sourceFmt = state.resolveSourceOutputFormat(task: task);

            if (state.purpose == TaskPurpose.conversion) {
              switch (task.mediaKind) {
                case MediaKind.video:
                  return WorkbenchConversionFormatPanel<OutputFormat>(
                    label: '目标格式',
                    value: state.outputFormat,
                    values: state.videoOutputFormats(task),
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      var next = state.copyWith(
                        outputFormat: value,
                        config: state.config.copyWith(outputFormat: value),
                      );
                      if (!VideoOutputCompatibility.supports(
                        value,
                        state.videoCodec,
                      )) {
                        final newCodec =
                            VideoOutputCompatibility.defaultCodecFor(value);
                        next = next.copyWith(
                          videoCodec: newCodec,
                          encoderBackend: EncoderBackend.auto,
                          config: next.config.copyWith(
                            videoCodec: newCodec,
                            encoderBackend: EncoderBackend.auto,
                          ),
                        );
                      }
                      next = next.copyWith(
                        config: next.config.copyWith(
                          keepOriginalOutputFormat:
                              value == sourceVideoOutputFormat,
                        ),
                      );
                      updateState(next);
                    },
                  );
                case MediaKind.image:
                  final imageConfig =
                      state.config.image ?? ImageProcessingConfig.initial();
                  return WorkbenchConversionFormatPanel<MediaOutputFormat>(
                    label: '目标格式',
                    value: imageConfig.outputFormat,
                    values: MediaOutputFormat.formatsFor(MediaKind.image),
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      updateState(
                        state.copyWith(
                          config: state.config.copyWith(
                            image: imageConfig.copyWith(
                              outputFormat: value,
                              keepOriginalOutputFormat: false,
                              losslessCompression: false,
                              imageQuality: 100,
                              resizePreset: ImageResizePreset.original,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                case MediaKind.audio:
                  final audioConfig =
                      state.config.audio ?? AudioProcessingConfig.initial();
                  return WorkbenchConversionFormatPanel<MediaOutputFormat>(
                    label: '目标格式',
                    value: audioConfig.outputFormat,
                    values: MediaOutputFormat.formatsFor(MediaKind.audio),
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      updateState(
                        state.copyWith(
                          config: state.config.copyWith(
                            audio: audioConfig.copyWith(
                              outputFormat: value,
                              keepOriginalOutputFormat: false,
                              bitratePreset: AudioBitratePreset.source,
                              sampleRate: AudioSampleRatePreset.source,
                              channels: AudioChannelsPreset.source,
                            ),
                          ),
                        ),
                      );
                    },
                  );
              }
            }

            switch (task.mediaKind) {
              case MediaKind.video:
                final videoConfig =
                    state.config.video ?? VideoProcessingConfig.initial();
                final phdr = preserveHdr;
                return WorkbenchVideoConfigPanel(
                  selectedOutputFormat: state.outputFormat,
                  selectedVideoCodec: phdr ? VideoCodec.hevc : state.videoCodec,
                  selectedEncoderBackend: state.encoderBackend,
                  selectedResolutionPreset: state.resolutionPreset,
                  availableEncoderBackends:
                      WorkbenchEncoderPolicy.availableEncoderBackends(
                        videoCodec: state.videoCodec,
                        selectedBackend: state.encoderBackend,
                      ),
                  onOutputFormatChanged: (value) {
                    var next = state.copyWith(
                      outputFormat: value,
                      config: state.config.copyWith(outputFormat: value),
                    );
                    if (!VideoOutputCompatibility.supports(
                      value,
                      state.videoCodec,
                    )) {
                      final newCodec = VideoOutputCompatibility.defaultCodecFor(
                        value,
                      );
                      next = next.copyWith(
                        videoCodec: newCodec,
                        encoderBackend: EncoderBackend.auto,
                        config: next.config.copyWith(
                          videoCodec: newCodec,
                          encoderBackend: EncoderBackend.auto,
                        ),
                      );
                    }
                    next = next.copyWith(
                      config: next.config.copyWith(
                        keepOriginalOutputFormat:
                            value == sourceVideoOutputFormat,
                      ),
                    );
                    updateState(next);
                  },
                  onVideoCodecChanged: (value) {
                    final result = WorkbenchCodecPolicy.resolveCodecChange(
                      requested: value,
                      currentBackend: state.encoderBackend,
                      preservingHdr: preserveHdr,
                    );
                    updateState(
                      state.copyWith(
                        videoCodec: result.codec,
                        encoderBackend: result.backend,
                        config: state.config.copyWith(
                          videoCodec: result.codec,
                          encoderBackend: result.backend,
                        ),
                      ),
                    );
                  },
                  onEncoderBackendChanged: (value) {
                    updateState(
                      state.copyWith(
                        encoderBackend: value,
                        config: state.config.copyWith(encoderBackend: value),
                      ),
                    );
                  },
                  onResolutionPresetChanged: (value) {
                    updateState(
                      state.copyWith(
                        resolutionPreset: value,
                        config: state.config.copyWith(resolutionPreset: value),
                      ),
                    );
                  },
                  sourceOutputFormat: sourceFmt?.toVideoOutputFormat(),
                  keepOriginalOutputFormat:
                      videoConfig.keepOriginalOutputFormat,
                  showPreserveHdrOption: task.analysisResult?.isHdr == true,
                  preserveHdr: phdr,
                  onPreserveHdrChanged: (value) {
                    updateState(
                      state.withPreserveHdrChanged(task: task, value: value),
                    );
                  },
                  preserveMetadata: videoConfig.preserveMetadata,
                  onPreserveMetadataChanged: (value) {
                    updateState(
                      state.withPreserveMetadata(task: task, value: value),
                    );
                  },
                  videoCodecValues: phdr
                      ? const [VideoCodec.hevc]
                      : VideoOutputCompatibility.codecsFor(state.outputFormat),
                  videoCodecEnabled: !phdr,
                  showEncoderBackend: false,
                  resolutionValues: state.availableResolutionPresets(task),
                  padding: EdgeInsets.zero,
                  itemSpacing: 8,
                  dropdownHeight: _taskConfigFieldHeight,
                  showTrailingText: false,
                  resolutionLabelBuilder: (value) =>
                      state.resolutionLabel(task, value),
                  labelFontSize: 12,
                  valueFontSize: 12,
                );
              case MediaKind.image:
                final imageConfig =
                    state.config.image ?? ImageProcessingConfig.initial();
                return WorkbenchImageConfigPanel(
                  config: imageConfig,
                  onChanged: (value) {
                    updateState(
                      state.copyWith(
                        config: state.config.copyWith(image: value),
                      ),
                    );
                  },
                  showLosslessCompression:
                      state.purpose == TaskPurpose.compression,
                  sourceOutputFormat: sourceFmt,
                  sourceWidth:
                      task.analysisResult?.imageWidth ??
                      task.analysisResult?.videoWidth,
                  sourceHeight:
                      task.analysisResult?.imageHeight ??
                      task.analysisResult?.videoHeight,
                  padding: EdgeInsets.zero,
                  itemSpacing: 8,
                  dropdownHeight: _taskConfigFieldHeight,
                  showTrailingText: false,
                  labelFontSize: 12,
                  valueFontSize: 12,
                );
              case MediaKind.audio:
                final audioConfig =
                    state.config.audio ?? AudioProcessingConfig.initial();
                return WorkbenchAudioConfigPanel(
                  config: audioConfig,
                  onChanged: (value) {
                    updateState(
                      state.copyWith(
                        config: state.config.copyWith(audio: value),
                      ),
                    );
                  },
                  sourceOutputFormat: sourceFmt,
                  padding: EdgeInsets.zero,
                  itemSpacing: 8,
                  dropdownHeight: _taskConfigFieldHeight,
                  showTrailingText: false,
                  labelFontSize: 12,
                  valueFontSize: 12,
                );
            }
          }

          // primaryContent: compression options + media config panel
          Widget primaryContent;
          if (isVideoTask && state.purpose == TaskPurpose.compression) {
            primaryContent = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompressionOptionsWrapper(
                  selectedQualityIndex: state.qualityIndex,
                  selectedSmartPreset:
                      state.smartPreset ?? SmartCompressionPreset.balanced,
                  selectedCompressionMode: state.compressionMode,
                  selectedTargetSizeRatio: state.targetSizeRatio,
                  selectedVideoCodec: state.videoCodec,
                  preserveHdr: preserveHdr,
                  estimatedSizeForPreset: (preset) => state
                      .estimatedOutputSizeForPreset(task: task, preset: preset),
                  onCompressionModeChanged: (value) {
                    if (preserveHdr && value == CompressionMode.targetSize) {
                      return;
                    }
                    final newMode = value == CompressionMode.targetSize
                        ? CompressionMode.targetSize
                        : CompressionMode.preset;
                    final newRatio =
                        WorkbenchQualityPolicy.normalizeTargetSizeRatio(
                          state.targetSizeRatio,
                        );
                    updateState(
                      state.copyWith(
                        compressionMode: newMode,
                        targetSizeRatio: newRatio,
                        config: state.config.copyWith(compressionMode: newMode),
                      ),
                    );
                  },
                  onSmartPresetChanged: (value) {
                    if (preserveHdr &&
                        !WorkbenchCodecPolicy.isHdrCompatibleSmartPreset(
                          value,
                        )) {
                      return;
                    }
                    updateState(
                      state.copyWith(
                        smartPreset: value,
                        config: state.config.copyWith(smartPreset: value),
                      ),
                    );
                  },
                  onQualityChanged: (index) {
                    if (index == state.qualityIndex) {
                      return;
                    }
                    updateState(state.copyWith(qualityIndex: index));
                  },
                  onOutputFormatChanged: (value) {
                    var next = state.copyWith(
                      outputFormat: value,
                      config: state.config.copyWith(outputFormat: value),
                    );
                    if (task.mediaKind == MediaKind.video &&
                        !VideoOutputCompatibility.supports(
                          value,
                          state.videoCodec,
                        )) {
                      final newCodec = VideoOutputCompatibility.defaultCodecFor(
                        value,
                      );
                      next = next.copyWith(
                        videoCodec: newCodec,
                        encoderBackend: EncoderBackend.auto,
                        config: next.config.copyWith(
                          videoCodec: newCodec,
                          encoderBackend: EncoderBackend.auto,
                        ),
                      );
                    }
                    next = next.copyWith(
                      config: next.config.copyWith(
                        keepOriginalOutputFormat:
                            value == sourceVideoOutputFormat,
                      ),
                    );
                    updateState(next);
                  },
                  onVideoCodecChanged: (value) {
                    final result = WorkbenchCodecPolicy.resolveCodecChange(
                      requested: value,
                      currentBackend: state.encoderBackend,
                      preservingHdr: preserveHdr,
                    );
                    updateState(
                      state.copyWith(
                        videoCodec: result.codec,
                        encoderBackend: result.backend,
                        config: state.config.copyWith(
                          videoCodec: result.codec,
                          encoderBackend: result.backend,
                        ),
                      ),
                    );
                  },
                  onEncoderBackendChanged: (value) {
                    updateState(
                      state.copyWith(
                        encoderBackend: value,
                        config: state.config.copyWith(encoderBackend: value),
                      ),
                    );
                  },
                  onTargetSizeRatioChanged: (value) {
                    final newRatio =
                        WorkbenchQualityPolicy.normalizeTargetSizeRatio(value);
                    final newIndex =
                        WorkbenchQualityPolicy.qualityIndexForTargetSizeRatio(
                          newRatio,
                        );
                    updateState(
                      state.copyWith(
                        targetSizeRatio: newRatio,
                        qualityIndex: newIndex,
                        config: state.config.copyWith(
                          targetSizeRatio: newRatio,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                buildMediaConfigPanel(),
              ],
            );
          } else {
            primaryContent = buildMediaConfigPanel();
          }

          // secondaryContent: output location when shown in main area
          Widget? secondaryContent;
          if (showOutputLocationInMain) {
            secondaryContent = _OutputLocationSection(
              config: state.config,
              systemOutputDirectoryLabel: systemOutputDirectoryLabel,
              onChanged: (mode, directory) {
                updateState(
                  state.copyWith(
                    config: state.config.copyWith(
                      outputLocationMode: mode,
                      outputDirectory: directory,
                    ),
                  ),
                );
              },
              onPickDirectory: onPickOutputDirectory,
              errorText: outputLocationError,
            );
          }

          // advancedContent: output location (fallback) + extra settings
          Widget? advancedContent;
          {
            final videoConfig =
                state.config.video ?? VideoProcessingConfig.initial();
            final audioStreams = task.analysisResult?.audioStreams ?? const [];

            advancedContent = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!showOutputLocationInMain) ...[
                  _OutputLocationSection(
                    config: state.config,
                    systemOutputDirectoryLabel: systemOutputDirectoryLabel,
                    onChanged: (mode, directory) {
                      updateState(
                        state.copyWith(
                          config: state.config.copyWith(
                            outputLocationMode: mode,
                            outputDirectory: directory,
                          ),
                        ),
                      );
                    },
                    onPickDirectory: onPickOutputDirectory,
                    errorText: outputLocationError,
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.purpose == TaskPurpose.conversion) ...[
                  ConfigCheckbox(
                    label: '保留元数据',
                    value: state.preserveMetadata,
                    height: _taskConfigFieldHeight,
                    fontSize: 12,
                    onChanged: (value) {
                      updateState(
                        state.withPreserveMetadata(task: task, value: value),
                      );
                    },
                  ),
                ],
                if (task.mediaKind == MediaKind.video &&
                    state.purpose == TaskPurpose.compression) ...[
                  ConfigDropdown<TwoPassMode>(
                    label: '两遍压缩',
                    trailingText: '',
                    value: videoConfig.twoPassMode,
                    values: TwoPassMode.values,
                    itemLabel: (mode) => switch (mode) {
                      TwoPassMode.automatic => '自动',
                      TwoPassMode.enabled => '开启',
                      TwoPassMode.disabled => '关闭',
                    },
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      updateState(
                        state.copyWith(
                          config: state.config.copyWith(
                            video: videoConfig.copyWith(twoPassMode: value),
                          ),
                        ),
                      );
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
                      values: [
                        -1,
                        ...audioStreams.map((stream) => stream.index),
                      ],
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
                        updateState(
                          state.copyWith(
                            config: state.config.copyWith(
                              video: videoConfig.copyWith(
                                selectedAudioStreamIndex: value == -1
                                    ? null
                                    : value,
                              ),
                            ),
                          ),
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
            );
          }

          return TaskConfigDialogTemplate(
            task: task,
            title: title,
            onClose: () => Navigator.of(dialogContext).pop(),
            onSave: () {
              final config = state.config;
              if (config.outputLocationMode == OutputLocationMode.custom &&
                  config.outputDirectory.trim().isEmpty) {
                outputLocationError = '请选择或填写输出目录';
                refreshDialog(() {});
                return;
              }
              Navigator.of(dialogContext).pop(state.toDraft());
            },
            onOpenSource: onOpenSource,
            thumbnail: thumbnail,
            sourceSummary: sourceSummary,
            selectedPurpose: state.purpose,
            onPurposeChanged: (value) {
              updateState(state.copyWith(purpose: value));
            },
            primaryContent: primaryContent,
            showSecondaryContent:
                showOutputLocationInMain && secondaryContent != null,
            secondaryContent: secondaryContent,
            threadLimit: state.config.threadLimit,
            onThreadLimitChanged: (value) {
              updateState(
                state.copyWith(
                  config: state.config.copyWith(threadLimit: value),
                ),
              );
            },
            advancedContent: advancedContent,
            modified: modified,
            compressed: compressed,
          );
        },
      );
    },
  );
}

int _audioStreamValue(int? value, Iterable<int> availableValues) {
  if (value == null) {
    return -1;
  }
  return availableValues.contains(value) ? value : -1;
}

// ---------------------------------------------------------------------------
// Compression Options Wrapper
// ---------------------------------------------------------------------------

class _CompressionOptionsWrapper extends StatefulWidget {
  const _CompressionOptionsWrapper({
    required this.selectedQualityIndex,
    required this.selectedSmartPreset,
    required this.selectedCompressionMode,
    required this.selectedTargetSizeRatio,
    required this.selectedVideoCodec,
    required this.preserveHdr,
    required this.estimatedSizeForPreset,
    required this.onCompressionModeChanged,
    required this.onSmartPresetChanged,
    required this.onQualityChanged,
    required this.onOutputFormatChanged,
    required this.onVideoCodecChanged,
    required this.onEncoderBackendChanged,
    required this.onTargetSizeRatioChanged,
  });

  final int selectedQualityIndex;
  final SmartCompressionPreset selectedSmartPreset;
  final CompressionMode selectedCompressionMode;
  final double selectedTargetSizeRatio;
  final VideoCodec selectedVideoCodec;
  final bool preserveHdr;
  final String Function(WorkbenchCompressionPreset) estimatedSizeForPreset;
  final ValueChanged<CompressionMode> onCompressionModeChanged;
  final ValueChanged<SmartCompressionPreset> onSmartPresetChanged;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<OutputFormat> onOutputFormatChanged;
  final ValueChanged<VideoCodec> onVideoCodecChanged;
  final ValueChanged<EncoderBackend> onEncoderBackendChanged;
  final ValueChanged<double> onTargetSizeRatioChanged;

  @override
  State<_CompressionOptionsWrapper> createState() =>
      _CompressionOptionsWrapperState();
}

class _CompressionOptionsWrapperState
    extends State<_CompressionOptionsWrapper> {
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

  late CompressionMode _mode;
  String? _activePresetTitle;

  @override
  void initState() {
    super.initState();
    _mode = _effectiveMode(widget.selectedCompressionMode);
    _activePresetTitle = _presetForSmartPreset(
      widget.selectedSmartPreset,
    ).title;
  }

  @override
  void didUpdateWidget(_CompressionOptionsWrapper oldWidget) {
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
    if (widget.preserveHdr) {
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

  bool _isPresetEnabled(WorkbenchCompressionPreset preset) {
    if (!widget.preserveHdr) {
      return true;
    }

    return preset.smartPreset == SmartCompressionPreset.balanced ||
        preset.smartPreset == SmartCompressionPreset.clear;
  }

  @override
  Widget build(BuildContext context) {
    return WorkbenchCompressionOptionsSection(
      mode: _mode,
      presets: _recommendedPresets,
      selectedQualityIndex: widget.selectedQualityIndex,
      activePresetTitle: _activePresetTitle,
      selectedTargetSizeRatio: widget.selectedTargetSizeRatio,
      estimatedSizeForPreset: widget.estimatedSizeForPreset,
      targetSizeModeEnabled:
          !widget.preserveHdr &&
          VideoOutputCompatibility.supportsTargetSize(
            widget.selectedVideoCodec,
          ),
      isPresetEnabled: _isPresetEnabled,
      onModeChanged: (mode) {
        if (widget.preserveHdr && mode == CompressionMode.targetSize) {
          return;
        }
        setState(() {
          _mode = mode;
        });
        widget.onCompressionModeChanged(mode);
      },
      onPresetSelected: _applyPreset,
      onTargetSizeRatioChanged: widget.onTargetSizeRatioChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Output Location Section
// ---------------------------------------------------------------------------

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
          trailingIcon: WorkbenchIcons.folderOpen,
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
