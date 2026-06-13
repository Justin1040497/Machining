import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/services/platform/theme_preferences_cache.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalThemePreferencesCache implements ThemePreferencesCache {
  const LocalThemePreferencesCache();

  static const _fileName = 'theme_prefs.json';
  static const _keyThemeMode = 'themeMode';

  @override
  Future<AppThemeMode> read() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return AppThemeMode.system;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final name = json[_keyThemeMode] as String;

      for (final value in AppThemeMode.values) {
        if (value.name == name) {
          return value;
        }
      }

      return AppThemeMode.system;
    } on Object {
      return AppThemeMode.system;
    }
  }

  @override
  Future<void> write(AppThemeMode mode) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(
        jsonEncode({_keyThemeMode: mode.name}),
        flush: true,
      );
    } on Object {
      // Theme cache is only a first-frame optimization.
    }
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(join(directory.path, _fileName));
  }
}
