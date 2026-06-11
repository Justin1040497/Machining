import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';

final appSettingsProvider = FutureProvider<AppSettings>((ref) {
  return LoadAppSettingsUseCase(
    repository: ref.watch(appSettingsRepositoryProvider),
  ).call();
});
