import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/providers/database_provider.dart';
import 'package:framelean/infrastructure/services/theme_prefs_cache.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 快速路径：从轻量缓存文件读主题，不等待 SQLite / Drift 初始化。
  // 缓存未命中时回退到亮色默认，不影响功能。
  final cachedTheme = await ThemePrefsCache.read();
  final database = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        initialAppSettingsProvider.overrideWithValue(
          AppSettings.initial().copyWith(themeMode: cachedTheme),
        ),
      ],
      child: const FrameLeanApp(),
    ),
  );
}
