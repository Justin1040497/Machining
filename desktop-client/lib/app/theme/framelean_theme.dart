import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';

ThemeData frameLeanLightTheme() {
  return _frameLeanTheme(
    colors: frameLeanLightColors,
    brightness: Brightness.light,
  );
}

ThemeData frameLeanDarkTheme() {
  return _frameLeanTheme(
    colors: frameLeanDarkColors,
    brightness: Brightness.dark,
  );
}

ThemeData _frameLeanTheme({
  required FrameLeanColors colors,
  required Brightness brightness,
}) {
  final textTheme = TextTheme(
    bodyMedium: TextStyle(fontSize: 14.flSp, color: colors.textPrimary),
    bodySmall: TextStyle(fontSize: 13.flSp, color: colors.textSecondary),
    labelMedium: TextStyle(fontSize: 12.flSp, color: colors.textTertiary),
    bodyLarge: TextStyle(fontSize: 16.flSp, color: colors.textPrimary),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      error: colors.statusFailed,
      surface: colors.surface,
    ),
    scaffoldBackgroundColor: colors.surfaceCanvas,
    fontFamily: 'AlibabaPuHuiTi',
    textTheme: textTheme,
    iconTheme: IconThemeData(size: 20.flR, color: colors.iconMuted),
    extensions: [colors],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.progress,
        disabledForegroundColor: colors.textTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.flR),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.flR),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.surfaceDisabled,
      thumbColor: colors.primary,
      overlayColor: colors.primary.withAlpha(24),
      activeTickMarkColor: colors.surface,
      inactiveTickMarkColor: colors.borderStrong,
      valueIndicatorColor: colors.primary,
      valueIndicatorTextStyle: TextStyle(
        color: colors.onPrimary,
        fontSize: 11.flSp,
        fontWeight: FontWeight.w600,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all(colors.onPrimary),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.primary;
        }
        return colors.surface;
      }),
      side: BorderSide(color: colors.borderStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.flR)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(4.flR),
      ),
      textStyle: TextStyle(color: colors.surface, fontSize: 11.flSp),
    ),
  );
}
