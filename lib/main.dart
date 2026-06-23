import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
  }

  // 快速路径：从轻量缓存文件读主题，不等待 SQLite / Drift 初始化。
  // 缓存未命中时回退到亮色默认，不影响功能。
  final cachedTheme = await const LocalThemePreferencesCache().read();
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
