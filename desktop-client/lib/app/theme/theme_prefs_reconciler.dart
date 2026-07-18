import 'package:framelean/domain/library.dart';

Future<void> reconcileThemePrefsCache({
  required AppThemeMode currentThemeMode,
  required Future<AppSettings> Function() loadSettings,
  required void Function(AppThemeMode mode) setThemeMode,
  required Future<void> Function(AppThemeMode mode) writeCache,
}) async {
  final settings = await loadSettings();
  if (settings.themeMode != currentThemeMode) {
    setThemeMode(settings.themeMode);
  }

  await writeCache(settings.themeMode);
}
