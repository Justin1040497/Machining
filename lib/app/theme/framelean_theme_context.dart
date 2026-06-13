import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_colors.dart';

export 'package:framelean/app/theme/framelean_responsive.dart';

extension FrameLeanThemeContext on BuildContext {
  FrameLeanColors get frameLeanColors {
    final theme = Theme.of(this);
    return theme.extension<FrameLeanColors>() ??
        (theme.brightness == Brightness.dark
            ? frameLeanDarkColors
            : frameLeanLightColors);
  }
}
