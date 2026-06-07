import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';
import 'package:framelean/app/theme/framelean_theme.dart';

import 'app_router.dart';

class FrameLeanApp extends ConsumerWidget {
  const FrameLeanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(
      appThemeModeProvider.select((mode) => mode == AppThemeMode.dark),
    );

    return ScreenUtilInit(
      designSize: frameLeanScreenDesignSize,
      minTextAdapt: true,
      splitScreenMode: true,
      fontSizeResolver: frameLeanFontSizeResolver,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'FrameLean',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          theme: frameLeanLightTheme(),
          darkTheme: frameLeanDarkTheme(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return _AnimatedThemeSwitch(isDark: isDark, child: child!);
          },
        );
      },
    );
  }
}

class _AnimatedThemeSwitch extends StatelessWidget {
  const _AnimatedThemeSwitch({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isDark ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
      builder: (context, t, child) {
        final light = frameLeanLightTheme();
        final dark = frameLeanDarkTheme();
        var data = ThemeData.lerp(light, dark, t);
        final lc = light.extension<FrameLeanColors>();
        final dc = dark.extension<FrameLeanColors>();
        if (lc != null && dc != null) {
          data = data.copyWith(extensions: [lc.lerp(dc, t)]);
        }
        return Theme(data: data, child: child!);
      },
      child: child,
    );
  }
}
