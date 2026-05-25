import 'package:flutter/material.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:machining/features/workbench/presentation_mappers/domain_labels.dart';

class WorkbenchCompressionPreset {
  const WorkbenchCompressionPreset({
    required this.smartPreset,
    required this.qualityIndex,
    required this.outputFormat,
    required this.videoCodec,
  });

  final SmartCompressionPreset smartPreset;
  final int qualityIndex;
  final OutputFormat outputFormat;
  final VideoCodec videoCodec;

  String get title => smartPreset.label;

  String get subtitle => smartPreset.subtitle;
}

class WorkbenchCompressionOptionsSection extends StatelessWidget {
  const WorkbenchCompressionOptionsSection({
    super.key,
    required this.mode,
    required this.presets,
    required this.selectedQualityIndex,
    required this.activePresetTitle,
    required this.presetEdited,
    required this.badgeText,
    required this.selectedTargetSizeRatio,
    required this.estimatedSizeForPreset,
    required this.onModeChanged,
    required this.onPresetSelected,
    required this.onTargetSizeRatioChanged,
  });

  final CompressionMode mode;
  final List<WorkbenchCompressionPreset> presets;
  final int selectedQualityIndex;
  final String? activePresetTitle;
  final bool presetEdited;
  final String badgeText;
  final double selectedTargetSizeRatio;
  final String Function(WorkbenchCompressionPreset preset)
  estimatedSizeForPreset;
  final ValueChanged<CompressionMode> onModeChanged;
  final ValueChanged<WorkbenchCompressionPreset> onPresetSelected;
  final ValueChanged<double> onTargetSizeRatioChanged;

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
                  badgeText: badgeText,
                  selectedRatio: selectedTargetSizeRatio,
                  onChanged: onTargetSizeRatioChanged,
                ),
        ),
      ],
    );
  }
}

class WorkbenchSourceSummary extends StatelessWidget {
  const WorkbenchSourceSummary({
    super.key,
    required this.task,
    required this.thumbnail,
  });

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

class _TargetSizePanel extends StatelessWidget {
  const _TargetSizePanel({
    super.key,
    required this.badgeText,
    required this.selectedRatio,
    required this.onChanged,
  });

  final String badgeText;
  final double selectedRatio;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ratios = WorkbenchConstants.targetSizeRatios;
    final selectedIndex = _indexForRatio(selectedRatio);
    final selectedPercent = (ratios[selectedIndex] * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
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
                '目标体积',
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
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 14,
                activeTrackColor: const Color(0xFF6290FF),
                inactiveTrackColor: const Color(0xFFEDEDED),
                thumbColor: Colors.white,
                overlayColor: const Color(0x1A6290FF),
                activeTickMarkColor: Colors.white,
                inactiveTickMarkColor: const Color(0xFFCFCFCF),
                valueIndicatorColor: const Color(0xFF315FD4),
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Slider(
                min: 0,
                max: (ratios.length - 1).toDouble(),
                divisions: ratios.length - 1,
                value: selectedIndex.toDouble(),
                label: '$selectedPercent%',
                onChanged: (value) {
                  final index = value.round().clamp(0, ratios.length - 1);
                  onChanged(ratios[index]);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final ratio in ratios)
                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(
                      color: ratio == ratios[selectedIndex]
                          ? const Color(0xFF315FD4)
                          : const Color(0xFF9A9A9A),
                      fontSize: 8,
                      height: 1,
                      fontWeight: ratio == ratios[selectedIndex]
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  int _indexForRatio(double ratio) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (
      var index = 0;
      index < WorkbenchConstants.targetSizeRatios.length;
      index += 1
    ) {
      final distance = (WorkbenchConstants.targetSizeRatios[index] - ratio)
          .abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }

    return nearestIndex;
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
            onTap: () => onChanged(CompressionMode.preset),
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

  final List<WorkbenchCompressionPreset> presets;
  final int selectedQualityIndex;
  final String? activePresetTitle;
  final bool presetEdited;
  final String Function(WorkbenchCompressionPreset preset)
  estimatedSizeForPreset;
  final ValueChanged<WorkbenchCompressionPreset> onSelected;

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

  final WorkbenchCompressionPreset preset;
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
