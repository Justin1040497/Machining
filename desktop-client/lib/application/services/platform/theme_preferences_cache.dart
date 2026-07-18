import 'package:framelean/domain/library.dart';

abstract interface class ThemePreferencesCache {
  Future<AppThemeMode> read();

  Future<void> write(AppThemeMode mode);
}
