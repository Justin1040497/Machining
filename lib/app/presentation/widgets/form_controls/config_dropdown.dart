import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

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
    this.showLabel = true,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
    this.enabled = true,
  });

  final String label;
  final String trailingText;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final double? height;
  final bool showTrailingText;
  final bool showLabel;
  final double labelFontSize;
  final double valueFontSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final fieldHeight = height ?? 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
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
        ],
        SizedBox(
          height: fieldHeight,
          child: DropdownButtonFormField<T>(
            key: ValueKey('$label-$value'),
            initialValue: value,
            isDense: false,
            isExpanded: true,
            alignment: AlignmentDirectional.centerStart,
            style: TextStyle(
              fontSize: valueFontSize.flSp,
              color: enabled ? colors.textPrimary : colors.textTertiary,
            ),
            selectedItemBuilder: (context) {
              return values.map((item) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    itemLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: valueFontSize.flSp,
                      color: enabled ? colors.textPrimary : colors.textTertiary,
                      height: 1.2,
                    ),
                  ),
                );
              }).toList();
            },
            items: values.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  itemLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: valueFontSize.flSp,
                    color: enabled ? colors.textPrimary : colors.textTertiary,
                    height: 1.2,
                  ),
                ),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? colors.iconMuted : colors.textTertiary,
              size: 20,
            ),
            decoration: InputDecoration(
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: colors.border),
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
