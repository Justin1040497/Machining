import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/theme/theme_prefs_reconciler.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';

void main() {
  group('reconcileThemePrefsCache', () {
    test(
      'updates app theme mode and cache when DB differs from cache',
      () async {
        final setModes = <AppThemeMode>[];
        final writtenModes = <AppThemeMode>[];

        await reconcileThemePrefsCache(
          currentThemeMode: AppThemeMode.light,
          loadSettings: () async {
            return AppSettings.initial().copyWith(themeMode: AppThemeMode.dark);
          },
          setThemeMode: setModes.add,
          writeCache: (mode) async {
            writtenModes.add(mode);
          },
        );

        expect(setModes, [AppThemeMode.dark]);
        expect(writtenModes, [AppThemeMode.dark]);
      },
    );

    test(
      'rewrites cache without app state update when DB already matches',
      () async {
        final setModes = <AppThemeMode>[];
        final writtenModes = <AppThemeMode>[];

        await reconcileThemePrefsCache(
          currentThemeMode: AppThemeMode.dark,
          loadSettings: () async {
            return AppSettings.initial().copyWith(themeMode: AppThemeMode.dark);
          },
          setThemeMode: setModes.add,
          writeCache: (mode) async {
            writtenModes.add(mode);
          },
        );

        expect(setModes, isEmpty);
        expect(writtenModes, [AppThemeMode.dark]);
      },
    );
  });
}
