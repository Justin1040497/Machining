import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class ConfigCheckbox extends StatelessWidget {
  const ConfigCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.height = 40,
    this.fontSize = 12,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => onChanged(!value),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 18,
                child: Checkbox(
                  value: value,
                  onChanged: (next) => onChanged(next ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: colors.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: fontSize.flSp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
