import 'package:flutter/material.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/formatters.dart';
import 'package:machining/features/workbench/pages/workbench_page/models.dart';
import 'package:machining/features/workbench/pages/workbench_page/quality_slider_panel.dart';
import 'package:machining/features/workbench/pages/workbench_page/video_config_panel.dart';

enum _CompressionConfigMode { recommended, customTargetSize }

class WorkbenchTaskConfigurationDialog extends StatefulWidget {
  const WorkbenchTaskConfigurationDialog({
    super.key,
    required this.task,
    required this.thumbnail,
    required this.qualityOptions,
    required this.selectedQualityIndex,
    required this.selectedOutputFormat,
    required this.selectedVideoCodec,
    required this.selectedEncoderBackend,
    required this.selectedResolutionPreset,
    required this.availableEncoderBackends,
    required this.onClose,
    required this.onOpenSource,
    required this.onSave,
    required this.onQualityChanged,
    required this.onOutputFormatChanged,
    required this.onVideoCodecChanged,
    required this.onEncoderBackendChanged,
    required this.onResolutionPresetChanged,
  });

  final MediaTask task;
  final ImageProvider? thumbnail;
  final List<QualityOption> qualityOptions;
  final int selectedQualityIndex;
  final OutputFormat selectedOutputFormat;
  final VideoCodec selectedVideoCodec;
  final EncoderBackend selectedEncoderBackend;
  final ResolutionPreset selectedResolutionPreset;
  final List<EncoderBackend> availableEncoderBackends;
  final VoidCallback onClose;
  final VoidCallback onOpenSource;
  final VoidCallback onSave;
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
  late _CompressionConfigMode _mode;

  static const _recommendedPresets = [
    _CompressionPreset(title: '均衡推荐', subtitle: '稳妥默认', qualityIndex: 4),
    _CompressionPreset(title: '微信发送', subtitle: '聊天分享', qualityIndex: 6),
    _CompressionPreset(title: '清晰优先', subtitle: '保留细节', qualityIndex: 2),
    _CompressionPreset(title: '体积优先', subtitle: '尽量压小', qualityIndex: 8),
  ];

  @override
  void initState() {
    super.initState();
    _mode = _isRecommendedIndex(widget.selectedQualityIndex)
        ? _CompressionConfigMode.recommended
        : _CompressionConfigMode.customTargetSize;
  }

  bool _isRecommendedIndex(int index) {
    return _recommendedPresets.any((preset) => preset.qualityIndex == index);
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
                  qualityOptions: widget.qualityOptions,
                  selectedQualityIndex: widget.selectedQualityIndex,
                  badgeText: _compressionBadgeText(),
                  estimatedSizeForIndex: _estimatedOutputSizeForIndex,
                  onModeChanged: (mode) {
                    setState(() {
                      _mode = mode;
                    });
                  },
                  onPresetSelected: (preset) {
                    widget.onQualityChanged(preset.qualityIndex);
                  },
                  onQualityChanged: widget.onQualityChanged,
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
                _DialogActions(onCancel: widget.onClose, onSave: widget.onSave),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compressionBadgeText() {
    final option = widget.qualityOptions[widget.selectedQualityIndex];
    final compressionPercent = ((1 - option.targetRatio) * 100).round();
    return '压缩 $compressionPercent% > ${_estimatedOutputSize(option)}';
  }

  String _estimatedOutputSizeForIndex(int index) {
    return _estimatedOutputSize(widget.qualityOptions[index]);
  }

  String _estimatedOutputSize(QualityOption option) {
    final sourceSize = widget.task.sourceFileFingerprint?.fileSize;
    if (sourceSize == null || sourceSize <= 0) {
      return '-';
    }

    return WorkbenchFormatters.formatBytes(
      (sourceSize * option.targetRatio).round(),
    );
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

class _CompressionPreset {
  const _CompressionPreset({
    required this.title,
    required this.subtitle,
    required this.qualityIndex,
  });

  final String title;
  final String subtitle;
  final int qualityIndex;
}

class _CompressionOptionsSection extends StatelessWidget {
  const _CompressionOptionsSection({
    required this.mode,
    required this.presets,
    required this.qualityOptions,
    required this.selectedQualityIndex,
    required this.badgeText,
    required this.estimatedSizeForIndex,
    required this.onModeChanged,
    required this.onPresetSelected,
    required this.onQualityChanged,
  });

  final _CompressionConfigMode mode;
  final List<_CompressionPreset> presets;
  final List<QualityOption> qualityOptions;
  final int selectedQualityIndex;
  final String badgeText;
  final String Function(int index) estimatedSizeForIndex;
  final ValueChanged<_CompressionConfigMode> onModeChanged;
  final ValueChanged<_CompressionPreset> onPresetSelected;
  final ValueChanged<int> onQualityChanged;

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
          child: mode == _CompressionConfigMode.recommended
              ? _RecommendedPresetRow(
                  key: const ValueKey('recommended-presets'),
                  presets: presets,
                  selectedQualityIndex: selectedQualityIndex,
                  estimatedSizeForIndex: estimatedSizeForIndex,
                  onSelected: onPresetSelected,
                )
              : WorkbenchQualitySliderPanel(
                  key: const ValueKey('custom-target-size'),
                  title: '目标体积',
                  options: qualityOptions,
                  selectedIndex: selectedQualityIndex,
                  onChanged: onQualityChanged,
                  showTrailingText: true,
                  badgeText: badgeText,
                  padding: EdgeInsets.zero,
                  headerGap: 7,
                  sliderHeight: 24,
                  showStops: false,
                  thumbSize: 22,
                  trackHeight: 11,
                  titleFontSize: 12,
                ),
        ),
      ],
    );
  }
}

class _CompressionModeSwitch extends StatelessWidget {
  const _CompressionModeSwitch({required this.mode, required this.onChanged});

  final _CompressionConfigMode mode;
  final ValueChanged<_CompressionConfigMode> onChanged;

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
            selected: mode == _CompressionConfigMode.recommended,
            onTap: () => onChanged(_CompressionConfigMode.recommended),
          ),
          _CompressionModeSegment(
            label: '自定义目标体积',
            selected: mode == _CompressionConfigMode.customTargetSize,
            onTap: () => onChanged(_CompressionConfigMode.customTargetSize),
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
    required this.estimatedSizeForIndex,
    required this.onSelected,
  });

  final List<_CompressionPreset> presets;
  final int selectedQualityIndex;
  final String Function(int index) estimatedSizeForIndex;
  final ValueChanged<_CompressionPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < presets.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: _RecommendedPresetCard(
              preset: presets[index],
              selected: presets[index].qualityIndex == selectedQualityIndex,
              estimatedSize: estimatedSizeForIndex(presets[index].qualityIndex),
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
    required this.estimatedSize,
    required this.onTap,
  });

  final _CompressionPreset preset;
  final bool selected;
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
              Text(
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
