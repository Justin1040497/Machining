import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

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

class WorkbenchTaskConfigurationStatusBadges extends StatelessWidget {
  const WorkbenchTaskConfigurationStatusBadges({
    super.key,
    required this.modified,
  });

  final bool modified;

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
