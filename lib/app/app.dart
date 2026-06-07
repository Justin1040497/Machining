import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/app/theme/theme_prefs_reconciler.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/theme_prefs_cache.dart';

import 'app_router.dart';

class FrameLeanApp extends ConsumerStatefulWidget {
  const FrameLeanApp({super.key});

  @override
  ConsumerState<FrameLeanApp> createState() => _FrameLeanAppState();
}

class _FrameLeanAppState extends ConsumerState<FrameLeanApp> {
  @override
  void initState() {
    super.initState();
    unawaited(reconcileThemeModeAfterStartup());
  }

  Future<void> reconcileThemeModeAfterStartup() async {
    final startupThemeMode = ref.read(appThemeModeProvider);
    try {
      await reconcileThemePrefsCache(
        currentThemeMode: startupThemeMode,
        loadSettings: () {
          return LoadAppSettingsUseCase(
            repository: ref.read(appSettingsRepositoryProvider),
          ).call();
        },
        setThemeMode: (mode) {
          if (mounted && ref.read(appThemeModeProvider) == startupThemeMode) {
            ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
          }
        },
        writeCache: (mode) async {
          if (mounted && ref.read(appThemeModeProvider) == mode) {
            await ThemePrefsCache.write(mode);
          }
        },
      );
    } on Object {
      // 主题缓存对齐失败不影响应用启动；下次切换主题会重写缓存。
    }
  }

  @override
  Widget build(BuildContext context) {
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
          themeAnimationDuration: const Duration(milliseconds: 200),
          themeAnimationCurve: Curves.easeIn,
        );
      },
    );
  }
}
