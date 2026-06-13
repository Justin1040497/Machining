import 'package:framelean/domain/enums/app_theme_mode.dart';

abstract interface class ThemePreferencesCache {
  Future<AppThemeMode> read();

  Future<void> write(AppThemeMode mode);
}
