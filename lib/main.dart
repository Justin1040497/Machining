import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/providers/database_provider.dart';
import 'package:framelean/infrastructure/repositories/drift_app_settings_repository.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final initialSettings = await _loadInitialSettings(database);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        initialAppSettingsProvider.overrideWithValue(initialSettings),
      ],
      child: const FrameLeanApp(),
    ),
  );
}

Future<AppSettings> _loadInitialSettings(AppDatabase database) async {
  try {
    return await DriftAppSettingsRepository(database).loadSettings();
  } on Object {
    return AppSettings.initial();
  }
}
