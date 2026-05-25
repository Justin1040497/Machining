import 'package:machining/application/repositories/app_settings_repository.dart';
import 'package:machining/domain/entities/app_settings.dart';

class LoadAppSettingsUseCase {
  final AppSettingsRepository repository;

  const LoadAppSettingsUseCase({required this.repository});

  Future<AppSettings> call() {
    return repository.loadSettings();
  }
}
