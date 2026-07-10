import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/library.dart';

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
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}
