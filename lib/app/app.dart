import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';
import 'package:framelean/app/theme/framelean_theme.dart';

import 'app_router.dart';

class FrameLeanApp extends ConsumerWidget {
  const FrameLeanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

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
          themeMode: themeMode.materialThemeMode,
        );
      },
    );
  }
}
