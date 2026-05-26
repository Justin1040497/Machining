import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_locator.dart';
import 'package:framelean/domain/entities/app_settings.dart';

class SaveAppSettingsUseCase {
  final AppSettingsRepository repository;
  final FfmpegLocator ffmpegLocator;

  const SaveAppSettingsUseCase({
    required this.repository,
    required this.ffmpegLocator,
  });

  Future<void> call(AppSettings settings) async {
    final ffmpegPath = settings.customFfmpegPath?.trim();
    final ffprobePath = settings.customFfprobePath?.trim();

    if (ffmpegPath != null && ffmpegPath.isNotEmpty) {
      await ffmpegLocator.validateCustomFfmpegPath(ffmpegPath);
    }
    if (ffprobePath != null && ffprobePath.isNotEmpty) {
      await ffmpegLocator.validateCustomFfprobePath(ffprobePath);
    }

    await repository.saveSettings(settings);
  }
}
