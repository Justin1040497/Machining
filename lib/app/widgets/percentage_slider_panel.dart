import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class PercentageSliderPanel extends StatelessWidget {
  const PercentageSliderPanel({
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
              const Spacer(),
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
