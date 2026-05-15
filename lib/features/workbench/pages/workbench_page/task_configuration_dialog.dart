import 'package:flutter/material.dart';
import 'package:machining/application/services/compression_estimator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/formatters.dart';
import 'package:machining/features/workbench/pages/workbench_page/video_config_panel.dart';

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
    required this.selectedTargetSizeBytes,
    required this.availableEncoderBackends,
    required this.onClose,
    required this.onOpenSource,
    required this.onSave,
    required this.onCompressionModeChanged,
    required this.onSmartPresetChanged,
    required this.onTargetSizeBytesChanged,
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
  final int? selectedTargetSizeBytes;
  final List<EncoderBackend> availableEncoderBackends;
  final VoidCallback onClose;
  final VoidCallback onOpenSource;
  final VoidCallback onSave;
  final ValueChanged<CompressionMode> onCompressionModeChanged;
  final ValueChanged<SmartCompressionPreset> onSmartPresetChanged;
  final ValueChanged<int?> onTargetSizeBytesChanged;
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
  late final TextEditingController _targetSizeController;
  late final FocusNode _targetSizeFocusNode;
  String? _activePresetTitle;
  bool _presetEdited = false;

  static const _recommendedPresets = [
    _CompressionPreset(
      smartPreset: SmartCompressionPreset.balanced,
      qualityIndex: 4,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
      resolutionPreset: ResolutionPreset.original,
    ),
    _CompressionPreset(
      smartPreset: SmartCompressionPreset.chat,
      qualityIndex: 6,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
      resolutionPreset: ResolutionPreset.p1080,
      capResolutionToSource: true,
    ),
    _CompressionPreset(
      smartPreset: SmartCompressionPreset.clear,
      qualityIndex: 3,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
      resolutionPreset: ResolutionPreset.original,
    ),
    _CompressionPreset(
      smartPreset: SmartCompressionPreset.compact,
      qualityIndex: 8,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.hevc,
      resolutionPreset: ResolutionPreset.p720,
      capResolutionToSource: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _targetSizeController = TextEditingController(
      text: _targetSizeInputText(widget.selectedTargetSizeBytes),
    );
    _targetSizeFocusNode = FocusNode();
    _mode = widget.selectedCompressionMode == CompressionMode.targetSize
        ? CompressionMode.targetSize
        : CompressionMode.smart;
    _activePresetTitle = _presetForSmartPreset(
      widget.selectedSmartPreset,
    ).title;
  }

  @override
  void didUpdateWidget(covariant WorkbenchTaskConfigurationDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTargetSizeBytes != widget.selectedTargetSizeBytes &&
        !_targetSizeFocusNode.hasFocus) {
      _targetSizeController.text = _targetSizeInputText(
        widget.selectedTargetSizeBytes,
      );
    }
  }

  @override
  void dispose() {
    _targetSizeController.dispose();
    _targetSizeFocusNode.dispose();
    super.dispose();
  }

  _CompressionPreset _presetForSmartPreset(SmartCompressionPreset smartPreset) {
    for (final preset in _recommendedPresets) {
      if (preset.smartPreset == smartPreset) {
        return preset;
      }
    }

    return _recommendedPresets.first;
  }

  void _applyPreset(_CompressionPreset preset) {
    setState(() {
      _mode = CompressionMode.smart;
      _activePresetTitle = preset.title;
      _presetEdited = false;
    });

    widget.onCompressionModeChanged(CompressionMode.smart);
    widget.onSmartPresetChanged(preset.smartPreset);
    widget.onQualityChanged(preset.qualityIndex);
    widget.onOutputFormatChanged(preset.outputFormat);
    widget.onVideoCodecChanged(preset.videoCodec);
    widget.onEncoderBackendChanged(EncoderBackend.auto);
    widget.onResolutionPresetChanged(_resolvePresetResolution(preset));
  }

  ResolutionPreset _resolvePresetResolution(_CompressionPreset preset) {
    if (!preset.capResolutionToSource) {
      return preset.resolutionPreset;
    }

    final sourceHeight = widget.task.analysisResult?.videoHeight;
    if (sourceHeight == null || sourceHeight <= 0) {
      return preset.resolutionPreset;
    }

    final targetHeight = switch (preset.resolutionPreset) {
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
      ResolutionPreset.original => sourceHeight,
    };

    return sourceHeight > targetHeight
        ? preset.resolutionPreset
        : ResolutionPreset.original;
  }

  void _markPresetEdited() {
    if (_mode == CompressionMode.targetSize || _activePresetTitle == null) {
      return;
    }

    setState(() {
      _presetEdited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                _DialogHeader(
                  title: '任务详情设置',
                  onClose: widget.onClose,
                  onOpenSource: widget.onOpenSource,
                ),
                const SizedBox(height: 18),
                _SourceSummary(task: widget.task, thumbnail: widget.thumbnail),
                const SizedBox(height: 14),
                _CompressionOptionsSection(
                  mode: _mode,
                  presets: _recommendedPresets,
                  selectedQualityIndex: widget.selectedQualityIndex,
                  activePresetTitle: _activePresetTitle,
                  presetEdited: _presetEdited,
                  badgeText: _targetSizeBadgeText(),
                  targetSizeController: _targetSizeController,
                  targetSizeFocusNode: _targetSizeFocusNode,
                  estimatedSizeForPreset: _estimatedOutputSizeForPreset,
                  onModeChanged: (mode) {
                    setState(() {
                      _mode = mode;
                    });
                    widget.onCompressionModeChanged(mode);
                  },
                  onPresetSelected: _applyPreset,
                  onTargetSizeChanged: (value) {
                    widget.onTargetSizeBytesChanged(
                      _parseTargetSizeBytes(value),
                    );
                  },
                ),
                const SizedBox(height: 14),
                WorkbenchVideoConfigPanel(
                  selectedOutputFormat: widget.selectedOutputFormat,
                  selectedVideoCodec: widget.selectedVideoCodec,
                  selectedEncoderBackend: widget.selectedEncoderBackend,
                  selectedResolutionPreset: widget.selectedResolutionPreset,
                  availableEncoderBackends: widget.availableEncoderBackends,
                  onOutputFormatChanged: (value) {
                    _markPresetEdited();
                    widget.onOutputFormatChanged(value);
                  },
                  onVideoCodecChanged: (value) {
                    _markPresetEdited();
                    widget.onVideoCodecChanged(value);
                  },
                  onEncoderBackendChanged: (value) {
                    _markPresetEdited();
                    widget.onEncoderBackendChanged(value);
                  },
                  onResolutionPresetChanged: (value) {
                    _markPresetEdited();
                    widget.onResolutionPresetChanged(value);
                  },
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
                _DialogActions(onCancel: widget.onClose, onSave: widget.onSave),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _targetSizeBadgeText() {
    final targetSizeBytes = widget.selectedTargetSizeBytes;
    if (targetSizeBytes == null || targetSizeBytes <= 0) {
      return '目标体积 -';
    }

    final sourceSize = widget.task.sourceFileFingerprint?.fileSize;
    if (sourceSize == null || sourceSize <= 0) {
      return '目标 ${WorkbenchFormatters.formatBytes(targetSizeBytes)}';
    }

    final compressionPercent = ((1 - targetSizeBytes / sourceSize) * 100)
        .clamp(0, 99)
        .round();
    return '压缩 $compressionPercent% > ${WorkbenchFormatters.formatBytes(targetSizeBytes)}';
  }

  String _estimatedOutputSizeForPreset(_CompressionPreset preset) {
    final estimate = const DefaultCompressionEstimator().estimateSmartPreset(
      task: widget.task,
      preset: preset.smartPreset,
      targetCodec: preset.videoCodec,
      targetResolutionPreset: _resolvePresetResolution(preset),
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

  String _targetSizeInputText(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '';
    }

    final value = bytes / (1024 * 1024);
    return value >= 10 && value.roundToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  int? _parseTargetSizeBytes(String value) {
    final megabytes = double.tryParse(value.trim().replaceAll(',', '.'));
    if (megabytes == null || megabytes <= 0) {
      return null;
    }

    return (megabytes * 1024 * 1024).round();
  }
}

class _CompressionPreset {
  const _CompressionPreset({
    required this.smartPreset,
    required this.qualityIndex,
    required this.outputFormat,
    required this.videoCodec,
    required this.resolutionPreset,
    this.capResolutionToSource = false,
  });

  final SmartCompressionPreset smartPreset;
  final int qualityIndex;
  final OutputFormat outputFormat;
  final VideoCodec videoCodec;
  final ResolutionPreset resolutionPreset;
  final bool capResolutionToSource;

  String get title => smartPreset.label;

  String get subtitle => smartPreset.subtitle;
}

class _CompressionOptionsSection extends StatelessWidget {
  const _CompressionOptionsSection({
    required this.mode,
    required this.presets,
    required this.selectedQualityIndex,
    required this.activePresetTitle,
    required this.presetEdited,
    required this.badgeText,
    required this.targetSizeController,
    required this.targetSizeFocusNode,
    required this.estimatedSizeForPreset,
    required this.onModeChanged,
    required this.onPresetSelected,
    required this.onTargetSizeChanged,
  });

  final CompressionMode mode;
  final List<_CompressionPreset> presets;
  final int selectedQualityIndex;
  final String? activePresetTitle;
  final bool presetEdited;
  final String badgeText;
  final TextEditingController targetSizeController;
  final FocusNode targetSizeFocusNode;
  final String Function(_CompressionPreset preset) estimatedSizeForPreset;
  final ValueChanged<CompressionMode> onModeChanged;
  final ValueChanged<_CompressionPreset> onPresetSelected;
  final ValueChanged<String> onTargetSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompressionModeSwitch(mode: mode, onChanged: onModeChanged),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: mode != CompressionMode.targetSize
              ? _RecommendedPresetRow(
                  key: const ValueKey('recommended-presets'),
                  presets: presets,
                  selectedQualityIndex: selectedQualityIndex,
                  activePresetTitle: activePresetTitle,
                  presetEdited: presetEdited,
                  estimatedSizeForPreset: estimatedSizeForPreset,
                  onSelected: onPresetSelected,
                )
              : _TargetSizePanel(
                  key: const ValueKey('custom-target-size'),
                  controller: targetSizeController,
                  focusNode: targetSizeFocusNode,
                  badgeText: badgeText,
                  onChanged: onTargetSizeChanged,
                ),
        ),
      ],
    );
  }
}

class _TargetSizePanel extends StatelessWidget {
  const _TargetSizePanel({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.badgeText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String badgeText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '目标大小',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8C8C8C),
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: onChanged,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 13,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(
                          color: Color(0xFF6290FF),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'MB',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompressionModeSwitch extends StatelessWidget {
  const _CompressionModeSwitch({required this.mode, required this.onChanged});

  final CompressionMode mode;
  final ValueChanged<CompressionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _CompressionModeSegment(
            label: '推荐方案选项',
            selected: mode != CompressionMode.targetSize,
            onTap: () => onChanged(CompressionMode.smart),
          ),
          _CompressionModeSegment(
            label: '自定义目标体积',
            selected: mode == CompressionMode.targetSize,
            onTap: () => onChanged(CompressionMode.targetSize),
          ),
        ],
      ),
    );
  }
}

class _CompressionModeSegment extends StatelessWidget {
  const _CompressionModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF111111)
                  : const Color(0xFF777777),
              fontSize: 12,
              height: 1,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedPresetRow extends StatelessWidget {
  const _RecommendedPresetRow({
    super.key,
    required this.presets,
    required this.selectedQualityIndex,
    required this.activePresetTitle,
    required this.presetEdited,
    required this.estimatedSizeForPreset,
    required this.onSelected,
  });

  final List<_CompressionPreset> presets;
  final int selectedQualityIndex;
  final String? activePresetTitle;
  final bool presetEdited;
  final String Function(_CompressionPreset preset) estimatedSizeForPreset;
  final ValueChanged<_CompressionPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasActivePreset = activePresetTitle != null;

    return Row(
      children: [
        for (var index = 0; index < presets.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: _RecommendedPresetCard(
              preset: presets[index],
              selected: hasActivePreset
                  ? presets[index].title == activePresetTitle
                  : presets[index].qualityIndex == selectedQualityIndex,
              edited: presets[index].title == activePresetTitle && presetEdited,
              estimatedSize: estimatedSizeForPreset(presets[index]),
              onTap: () => onSelected(presets[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecommendedPresetCard extends StatelessWidget {
  const _RecommendedPresetCard({
    required this.preset,
    required this.selected,
    required this.edited,
    required this.estimatedSize,
    required this.onTap,
  });

  final _CompressionPreset preset;
  final bool selected;
  final bool edited;
  final String estimatedSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${preset.title}：${preset.subtitle}',
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 72,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF4FF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6290FF)
                  : const Color(0xFFE4E4E4),
              width: selected ? 1.3 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x126290FF),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF315FD4)
                      : const Color(0xFF111111),
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                preset.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8C8C8C),
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      estimatedSize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF6290FF)
                            : const Color(0xFF9A9A9A),
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (edited)
                    Container(
                      height: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x176290FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已调',
                        style: TextStyle(
                          color: Color(0xFF6290FF),
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.onClose,
    required this.onOpenSource,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-10, 0),
          child: SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.keyboard_arrow_left_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton(
            tooltip: '在 Finder 中打开源文件',
            onPressed: onOpenSource,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.open_in_new_rounded,
              color: Colors.black,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceSummary extends StatelessWidget {
  const _SourceSummary({required this.task, required this.thumbnail});

  final MediaTask task;
  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    final analysis = task.analysisResult;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 11,
              height: 1.95,
              fontWeight: FontWeight.w400,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '原视频大小: ${WorkbenchFormatters.formatBytes(task.sourceFileFingerprint?.fileSize)}',
                ),
                Text('分辨率: ${WorkbenchFormatters.formatResolution(analysis)}'),
                Wrap(
                  spacing: 24,
                  runSpacing: 0,
                  children: [
                    Text(
                      '视频格式: ${WorkbenchFormatters.formatContainer(analysis?.containerFormat)}',
                    ),
                    Text(
                      '视频时长: ${WorkbenchFormatters.formatDuration(analysis?.durationMs)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _TaskThumbnail(thumbnail: thumbnail),
      ],
    );
  }
}

class _TaskThumbnail extends StatelessWidget {
  const _TaskThumbnail({required this.thumbnail});

  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEF5),
        borderRadius: BorderRadius.circular(8),
        image: thumbnail == null
            ? null
            : DecorationImage(image: thumbnail!, fit: BoxFit.cover),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail == null
          ? const Icon(
              Icons.movie_creation_outlined,
              color: Color(0xFF7D8B95),
              size: 22,
            )
          : null,
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.onCancel, required this.onSave});

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _DialogActionButton(
          label: '取消',
          backgroundColor: const Color(0xFFB8B8B8),
          onPressed: onCancel,
        ),
        const SizedBox(width: 16),
        _DialogActionButton(
          label: '保存',
          backgroundColor: const Color(0xFF6290FF),
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      height: 28,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}
