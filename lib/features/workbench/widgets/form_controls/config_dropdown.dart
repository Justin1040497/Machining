import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';

class ConfigDropdown<T> extends StatelessWidget {
  const ConfigDropdown({
    super.key,
    required this.label,
    required this.trailingText,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
    this.height,
    this.showTrailingText = true,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
  });

  final String label;
  final String trailingText;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final double? height;
  final bool showTrailingText;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize.flSp,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showTrailingText)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: valueFontSize.flSp,
                  color: colors.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: height,
          child: DropdownButtonFormField<T>(
            key: ValueKey('$label-$value'),
            initialValue: value,
            isDense: true,
            style: TextStyle(
              fontSize: valueFontSize.flSp,
              color: colors.textPrimary,
            ),
            items: values.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  style: TextStyle(
                    fontSize: valueFontSize.flSp,
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.iconMuted,
              size: 20,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: colors.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: colors.primary),
              ),
            ),
            dropdownColor: colors.surface,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}
