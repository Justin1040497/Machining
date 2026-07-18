import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/domain/library.dart';

class LoadAppSettingsUseCase {
  final AppSettingsRepository repository;

  const LoadAppSettingsUseCase({required this.repository});

  Future<AppSettings> call() {
    return repository.loadSettings();
  }
}
