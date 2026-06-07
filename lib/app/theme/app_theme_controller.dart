import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';

final initialAppSettingsProvider = Provider<AppSettings>((ref) {
  return AppSettings.initial();
});

final appThemeModeProvider =
    NotifierProvider<AppThemeModeController, AppThemeMode>(
      AppThemeModeController.new,
    );

class AppThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    return ref.watch(initialAppSettingsProvider).themeMode;
  }

  void setThemeMode(AppThemeMode mode) {
    state = mode;
  }
}

extension AppThemeModeMaterialMapping on AppThemeMode {
  ThemeMode get materialThemeMode {
    return switch (this) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}
