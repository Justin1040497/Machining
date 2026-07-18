enum AppThemeMode {
  system,
  light,
  dark;

  AppThemeMode get toggled {
    return switch (this) {
      AppThemeMode.system => AppThemeMode.dark,
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.light,
    };
  }
}
