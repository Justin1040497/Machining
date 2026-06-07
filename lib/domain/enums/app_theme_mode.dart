enum AppThemeMode {
  light,
  dark;

  AppThemeMode get toggled {
    return switch (this) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.light,
    };
  }
}
