import 'package:flutter/material.dart';

class WorkbenchConfigDropdown<T> extends StatelessWidget {
  const WorkbenchConfigDropdown({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize,
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showTrailingText)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: valueFontSize,
                  color: const Color(0xFF111111),
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
            style: TextStyle(fontSize: valueFontSize, color: Colors.black),
            items: values.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  style: TextStyle(
                    fontSize: valueFontSize,
                    color: const Color(0xFF111111),
                    height: 1.2,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF9A9A9A),
              size: 20,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: Color(0xFF6290FF)),
              ),
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}
