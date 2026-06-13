import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class WorkbenchSegment<T> {
  const WorkbenchSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class WorkbenchSegmentedSwitch<T> extends StatelessWidget {
  const WorkbenchSegmentedSwitch({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.isSegmentEnabled,
    this.height = 34,
  }) : assert(segments.length >= 2);

  final T value;
  final List<WorkbenchSegment<T>> segments;
  final ValueChanged<T> onChanged;
  final bool Function(T value)? isSegmentEnabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceDisabled,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _WorkbenchSegmentButton<T>(
                segment: segment,
                selected: segment.value == value,
                enabled: isSegmentEnabled?.call(segment.value) ?? true,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkbenchSegmentButton<T> extends StatelessWidget {
  const _WorkbenchSegmentButton({
    required this.segment,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final WorkbenchSegment<T> segment;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          segment.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: enabled
                ? (selected ? colors.textPrimary : colors.textSecondary)
                : colors.textTertiary,
            fontSize: 12.flSp,
            height: 1,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
