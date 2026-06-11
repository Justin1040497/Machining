import 'dart:convert';
import 'dart:io';

import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 轻量级主题缓存，用独立 JSON 文件加速启动时的主题读取，
/// 避免等 SQLite / Drift 初始化完成才能确定首帧主题。
///
/// 这不是 source of truth，DB 中的 settings 表才是。
/// 如果缓存文件丢失或损坏，回退到跟随系统主题，不影响功能。
class ThemePrefsCache {
  static const _fileName = 'theme_prefs.json';
  static const _keyThemeMode = 'themeMode';

  /// 读取缓存的 [AppThemeMode]，失败时返回 [AppThemeMode.system]。
  static Future<AppThemeMode> read() async {
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

  /// 写入当前 [AppThemeMode] 到缓存文件。
  static Future<void> write(AppThemeMode mode) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(
        jsonEncode({_keyThemeMode: mode.name}),
        flush: true,
      );
    } on Object {
      // 写入失败不影响功能，下次启动走 fallback。
    }
  }

  static Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(join(directory.path, _fileName));
  }
}
