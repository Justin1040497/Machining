import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';

void main() {
  group('app settings use cases', () {
    test('loads settings from the repository', () async {
      final settings = AppSettings.initial();
      final repository = FakeAppSettingsRepository(settings);

      final loadedSettings = await LoadAppSettingsUseCase(
        repository: repository,
      ).call();

      expect(loadedSettings, same(settings));
    });

    test('persists settings without Client runtime validation', () async {
      final repository = FakeAppSettingsRepository(AppSettings.initial());
      final settings = AppSettings.initial().copyWith(
        defaultOutputDirectory: '/exports',
      );

      await SaveAppSettingsUseCase(repository: repository).call(settings);

      expect(repository.settings, same(settings));
    });
  });
}

class FakeAppSettingsRepository implements AppSettingsRepository {
  FakeAppSettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}
