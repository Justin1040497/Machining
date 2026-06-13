import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';
import 'package:framelean/features/workbench/presentation_mappers/media_kind_icons.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';
import 'package:framelean/features/workbench/widgets/form_controls/workbench_segmented_switch.dart';

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
    required this.selectedTargetSizeRatio,
    required this.estimatedSizeForPreset,
    required this.onModeChanged,
    required this.onPresetSelected,
    required this.onTargetSizeRatioChanged,
    this.targetSizeModeEnabled = true,
    this.isPresetEnabled,
  });

  final CompressionMode mode;
  final List<WorkbenchCompressionPreset> presets;
  final int selectedQualityIndex;
  final String? activePresetTitle;
  final double selectedTargetSizeRatio;
  final String Function(WorkbenchCompressionPreset preset)
  estimatedSizeForPreset;
  final ValueChanged<CompressionMode> onModeChanged;
  final ValueChanged<WorkbenchCompressionPreset> onPresetSelected;
  final ValueChanged<double> onTargetSizeRatioChanged;
  final bool targetSizeModeEnabled;
  final bool Function(WorkbenchCompressionPreset preset)? isPresetEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompressionModeSwitch(
          mode: mode,
          targetSizeModeEnabled: targetSizeModeEnabled,
          onChanged: onModeChanged,
        ),
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
                  estimatedSizeForPreset: estimatedSizeForPreset,
                  isPresetEnabled: isPresetEnabled,
                  onSelected: onPresetSelected,
                )
              : _TargetSizePanel(
                  key: const ValueKey('custom-target-size'),
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
    final colors = context.frameLeanColors;
    final analysis = task.analysisResult;
    final dimension = switch (task.mediaKind) {
      MediaKind.image => _formatImageDimension(task),
      MediaKind.video => WorkbenchFormatters.formatResolution(analysis),
      MediaKind.audio => '-',
    };
    final formatLabel = switch (task.mediaKind) {
      MediaKind.video => '视频格式',
      MediaKind.image => '图片格式',
      MediaKind.audio => '音频格式',
    };
    final secondaryLabel = switch (task.mediaKind) {
      MediaKind.video => '视频时长',
      MediaKind.image => '方向',
      MediaKind.audio => '音频时长',
    };
    final secondaryValue = task.mediaKind == MediaKind.image
        ? _formatOrientation(task)
        : WorkbenchFormatters.formatDuration(analysis?.durationMs);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 11.flSp,
              height: 1.95,
              fontWeight: FontWeight.w400,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '源文件大小: ${WorkbenchFormatters.formatBytes(task.sourceFileFingerprint?.fileSize)}',
                ),
                Text('尺寸: $dimension'),
                Wrap(
                  spacing: 24,
                  runSpacing: 0,
                  children: [
                    Text(
                      '$formatLabel: ${WorkbenchFormatters.formatContainer(analysis?.containerFormat)}',
                    ),
                    Text('$secondaryLabel: $secondaryValue'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _TaskThumbnail(mediaKind: task.mediaKind, thumbnail: thumbnail),
      ],
    );
  }

  String _formatImageDimension(MediaTask task) {
    final analysis = task.analysisResult;
    final width = analysis?.imageWidth ?? analysis?.videoWidth;
    final height = analysis?.imageHeight ?? analysis?.videoHeight;
    if (width == null || height == null) {
      return '-';
    }

    return '$width × $height';
  }

  String _formatOrientation(MediaTask task) {
    final degrees =
        task.analysisResult?.orientationDegrees ??
        task.analysisResult?.videoRotationDegrees;
    if (degrees == null) {
      return '-';
    }

    return '$degrees°';
  }
}

class _TargetSizePanel extends StatelessWidget {
  const _TargetSizePanel({
    super.key,
    required this.selectedRatio,
    required this.onChanged,
  });

  final double selectedRatio;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ratios = WorkbenchConstants.targetSizeRatios;
    return WorkbenchPercentageSliderPanel(
      title: '目标体积',
      summaryBuilder: (ratio) => '压缩体积${(ratio * 100).round()}%',
      values: ratios,
      selectedValue: selectedRatio,
      onChanged: onChanged,
    );
  }
}

class WorkbenchPercentageSliderPanel extends StatelessWidget {
  const WorkbenchPercentageSliderPanel({
    super.key,
    required this.title,
    required this.summaryBuilder,
    required this.values,
    required this.selectedValue,
    required this.onChanged,
    this.showTickLabels = true,
  }) : assert(values.length >= 2);

  final String title;
  final String Function(double value) summaryBuilder;
  final List<double> values;
  final double selectedValue;
  final ValueChanged<double> onChanged;
  final bool showTickLabels;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final selectedIndex = _indexForValue(selectedValue);
    final selectedPanelValue = values[selectedIndex];
    final selectedPercent = (selectedPanelValue * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.flSp,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Spacer(),
              Text(
                summaryBuilder(selectedPanelValue),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.flSp,
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
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.surfaceDisabled,
                thumbColor: colors.primary,
                overlayColor: colors.primary.withAlpha(26),
                activeTickMarkColor: colors.surface,
                inactiveTickMarkColor: colors.borderStrong,
                valueIndicatorColor: colors.primary,
                valueIndicatorTextStyle: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 11.flSp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Slider(
                min: 0,
                max: (values.length - 1).toDouble(),
                divisions: values.length - 1,
                value: selectedIndex.toDouble(),
                label: '$selectedPercent%',
                onChanged: (value) {
                  final index = value.round().clamp(0, values.length - 1);
                  onChanged(values[index]);
                },
              ),
            ),
          ),
          if (showTickLabels) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final value in values)
                    Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        color: value == selectedPanelValue
                            ? colors.primary
                            : colors.textTertiary,
                        fontSize: 8.flSp,
                        height: 1,
                        fontWeight: value == selectedPanelValue
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  int _indexForValue(double value) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < values.length; index += 1) {
      final distance = (values[index] - value).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }

    return nearestIndex;
  }
}

class _CompressionModeSwitch extends StatelessWidget {
  const _CompressionModeSwitch({
    required this.mode,
    required this.targetSizeModeEnabled,
    required this.onChanged,
  });

  final CompressionMode mode;
  final bool targetSizeModeEnabled;
  final ValueChanged<CompressionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = mode == CompressionMode.targetSize
        ? CompressionMode.targetSize
        : CompressionMode.preset;

    return WorkbenchSegmentedSwitch<CompressionMode>(
      value: value,
      segments: const [
        WorkbenchSegment(value: CompressionMode.preset, label: '推荐方案选项'),
        WorkbenchSegment(value: CompressionMode.targetSize, label: '自定义目标体积'),
      ],
      isSegmentEnabled: (value) =>
          value != CompressionMode.targetSize || targetSizeModeEnabled,
      onChanged: onChanged,
    );
  }
}

class _RecommendedPresetRow extends StatelessWidget {
  const _RecommendedPresetRow({
    super.key,
    required this.presets,
    required this.selectedQualityIndex,
    required this.activePresetTitle,
    required this.estimatedSizeForPreset,
    required this.isPresetEnabled,
    required this.onSelected,
  });

  final List<WorkbenchCompressionPreset> presets;
  final int selectedQualityIndex;
  final String? activePresetTitle;
  final String Function(WorkbenchCompressionPreset preset)
  estimatedSizeForPreset;
  final bool Function(WorkbenchCompressionPreset preset)? isPresetEnabled;
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
              enabled: isPresetEnabled?.call(presets[index]) ?? true,
              selected: hasActivePreset
                  ? presets[index].title == activePresetTitle
                  : presets[index].qualityIndex == selectedQualityIndex,
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
    required this.enabled,
    required this.selected,
    required this.estimatedSize,
    required this.onTap,
  });

  final WorkbenchCompressionPreset preset;
  final bool enabled;
  final bool selected;
  final String estimatedSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Tooltip(
      message: enabled ? '${preset.title}：${preset.subtitle}' : '保持 HDR 时不可用',
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 72,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          decoration: BoxDecoration(
            color: selected ? colors.primarySoft : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : enabled
                  ? colors.border
                  : colors.surfaceDisabled,
              width: selected ? 1.3 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withAlpha(18),
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
                  color: enabled
                      ? (selected ? colors.primary : colors.textPrimary)
                      : colors.textTertiary,
                  fontSize: 11.flSp,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                preset.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? colors.textTertiary : colors.iconMuted,
                  fontSize: 9.flSp,
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
                        color: enabled
                            ? (selected ? colors.primary : colors.textTertiary)
                            : colors.iconMuted,
                        fontSize: 9.flSp,
                        height: 1,
                        fontWeight: FontWeight.w600,
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

class WorkbenchTaskConfigurationStatusBadges extends StatelessWidget {
  const WorkbenchTaskConfigurationStatusBadges({
    super.key,
    required this.modified,
    required this.compressed,
  });

  final bool modified;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (modified)
          _StatusBadge(
            label: '已修改',
            color: colors.primary,
            backgroundColor: colors.primarySoft,
          ),
        if (compressed)
          _StatusBadge(
            label: '已压缩',
            color: colors.statusRunning,
            backgroundColor: colors.runningSoft,
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9.flSp,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TaskThumbnail extends StatelessWidget {
  const _TaskThumbnail({required this.mediaKind, required this.thumbnail});

  final MediaKind mediaKind;
  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        image: thumbnail == null
            ? null
            : DecorationImage(image: thumbnail!, fit: BoxFit.cover),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail == null
          ? Icon(mediaKind.placeholderIcon, color: colors.iconMuted, size: 22)
          : null,
    );
  }
}
