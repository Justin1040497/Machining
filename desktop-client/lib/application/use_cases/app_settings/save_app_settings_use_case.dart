import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/domain/library.dart';

class SaveAppSettingsUseCase {
  final AppSettingsRepository repository;

  const SaveAppSettingsUseCase({required this.repository});

  Future<void> call(AppSettings settings) async {
    await repository.saveSettings(settings);
  }
}
