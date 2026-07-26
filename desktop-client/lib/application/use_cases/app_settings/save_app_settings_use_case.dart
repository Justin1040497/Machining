import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/domain/library.dart';

class SaveAppSettingsUseCase {
  final AppSettingsRepository repository;

  const SaveAppSettingsUseCase({required this.repository});

  Future<void> call(AppSettings settings) async {
    // Legacy custom FFmpeg/FFprobe fields are persisted for compatibility
    // only. Client no longer validates or consumes them; FEngine owns the
    // media runtime and its native capabilities.
    await repository.saveSettings(settings);
  }
}
