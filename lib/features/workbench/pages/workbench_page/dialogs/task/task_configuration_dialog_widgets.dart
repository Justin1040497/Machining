import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

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

class WorkbenchConversionFormatPanel<T> extends StatelessWidget {
  const WorkbenchConversionFormatPanel({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConfigDropdown<T>(
      label: label,
      trailingText: '',
      value: value,
      values: values,
      itemLabel: itemLabel,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      height: 40,
      showTrailingText: false,
      labelFontSize: 12,
      valueFontSize: 12,
    );
  }
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
        _CompressionModeSegmentedControl(
          mode: mode,
          targetSizeModeEnabled: targetSizeModeEnabled,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: AnimatedSize(
            duration: expandCollapseTransition,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: AnimatedSwitcher(
              duration: expandCollapseTransition,
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.hardEdge,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
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

class WorkbenchTaskFolderSummary extends StatelessWidget {
  const WorkbenchTaskFolderSummary({
    super.key,
    required this.folder,
    required this.tasks,
  });

  final TaskFolder folder;
  final List<MediaTask> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final knownSizes = tasks
        .map((task) => task.sourceFileFingerprint?.fileSize)
        .whereType<int>()
        .toList();
    final totalSize = knownSizes.isEmpty
        ? null
        : knownSizes.fold<int>(0, (sum, size) => sum + size);
    final formats = _formatDistribution();
    final detail = folder.mediaKind == MediaKind.image
        ? _dimensionDistribution()
        : _durationSummary();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text('任务数量: ${tasks.length}'),
                  Text(
                    '源文件总大小: ${WorkbenchFormatters.formatBytes(totalSize)}'
                    '${knownSizes.length == tasks.length ? '' : '（已统计 ${knownSizes.length}/${tasks.length}）'}',
                  ),
                  Text('格式分布: ${formats.isEmpty ? '-' : formats}'),
                  Text(detail),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 92,
            constraints: const BoxConstraints(minHeight: 58),
            decoration: BoxDecoration(
              color: colors.surfaceDisabled,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(
              WorkbenchIcons.folderCopy,
              color: colors.iconMuted,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistribution() {
    final counts = <String, int>{};
    for (final task in tasks) {
      final format = WorkbenchFormatters.formatContainer(
        task.analysisResult?.containerFormat,
      );
      if (format == '-') {
        continue;
      }
      counts.update(format, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts.entries
        .map((entry) => '${entry.key} × ${entry.value}')
        .join('、');
  }

  String _durationSummary() {
    final durations = tasks
        .map((task) => task.analysisResult?.durationMs)
        .whereType<int>()
        .toList();
    final totalDuration = durations.isEmpty
        ? null
        : durations.fold<int>(0, (sum, duration) => sum + duration);
    return '总时长: ${WorkbenchFormatters.formatDuration(totalDuration)}'
        '${durations.length == tasks.length ? '' : '（已统计 ${durations.length}/${tasks.length}）'}';
  }

  String _dimensionDistribution() {
    final counts = <String, int>{};
    for (final task in tasks) {
      final analysis = task.analysisResult;
      final width = analysis?.imageWidth ?? analysis?.videoWidth;
      final height = analysis?.imageHeight ?? analysis?.videoHeight;
      if (width == null || height == null) {
        continue;
      }
      final dimension = '$width × $height';
      counts.update(dimension, (count) => count + 1, ifAbsent: () => 1);
    }
    final distribution = counts.entries
        .map((entry) => '${entry.key} × ${entry.value}')
        .join('、');
    return '尺寸分布: ${distribution.isEmpty ? '-' : distribution}';
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
    return PercentageSliderPanel(
      title: '目标体积',
      summaryBuilder: (ratio) => '压缩体积${(ratio * 100).round()}%',
      values: ratios,
      selectedValue: selectedRatio,
      onChanged: onChanged,
    );
  }
}

class _CompressionModeSegmentedControl extends StatelessWidget {
  const _CompressionModeSegmentedControl({
    required this.mode,
    required this.targetSizeModeEnabled,
    required this.onChanged,
  });

  final CompressionMode mode;
  final bool targetSizeModeEnabled;
  final ValueChanged<CompressionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final value = mode == CompressionMode.targetSize
        ? CompressionMode.targetSize
        : CompressionMode.preset;

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: CupertinoSlidingSegmentedControl<CompressionMode>(
        groupValue: value,
        backgroundColor: colors.surfaceDisabled,
        thumbColor: colors.surface,
        padding: const EdgeInsets.all(3),
        disabledChildren: targetSizeModeEnabled
            ? const <CompressionMode>{}
            : const {CompressionMode.targetSize},
        children: const {
          CompressionMode.preset: Text('推荐方案选项'),
          CompressionMode.targetSize: Text('自定义目标体积'),
        },
        onValueChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
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
      waitDuration: debounceInterval,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: hoverTransition,
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
