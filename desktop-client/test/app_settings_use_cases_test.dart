import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_locator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';

void main() {
  group('app settings use cases', () {
    test('loads settings from the repository', () async {
      final settings = AppSettings.initial().copyWith(
        customFfmpegPath: '/usr/bin/ffmpeg',
      );
      final repository = FakeAppSettingsRepository(settings);

      final loadedSettings = await LoadAppSettingsUseCase(
        repository: repository,
      ).call();

      expect(loadedSettings, same(settings));
    });

    test('validates custom FFmpeg paths before saving settings', () async {
      final repository = FakeAppSettingsRepository(AppSettings.initial());
      final locator = FakeFfmpegLocator();
      final settings = AppSettings.initial().copyWith(
        customFfmpegPath: '/custom/ffmpeg',
        customFfprobePath: '/custom/ffprobe',
      );

      await SaveAppSettingsUseCase(
        repository: repository,
        ffmpegLocator: locator,
      ).call(settings);

      expect(locator.validatedFfmpegPaths, ['/custom/ffmpeg']);
      expect(locator.validatedFfprobePaths, ['/custom/ffprobe']);
      expect(repository.settings, same(settings));
    });

    test('skips validation for empty custom FFmpeg paths', () async {
      final repository = FakeAppSettingsRepository(AppSettings.initial());
      final locator = FakeFfmpegLocator();
      final settings = AppSettings.initial().copyWith(
        customFfmpegPath: '   ',
        customFfprobePath: '',
      );

      await SaveAppSettingsUseCase(
        repository: repository,
        ffmpegLocator: locator,
      ).call(settings);

      expect(locator.validatedFfmpegPaths, isEmpty);
      expect(locator.validatedFfprobePaths, isEmpty);
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

class FakeFfmpegLocator implements FfmpegLocator {
  final List<String> validatedFfmpegPaths = [];
  final List<String> validatedFfprobePaths = [];

  @override
  Future<ResolvedFfmpegRuntime> resolve({
    String? customFfmpegPath,
    String? customFfprobePath,
  }) async {
    return const ResolvedFfmpegRuntime(ffmpeg: null, ffprobe: null);
  }

  @override
  Future<ResolvedFfmpegTool> validateCustomFfmpegPath(String inputPath) async {
    validatedFfmpegPaths.add(inputPath);
    return ResolvedFfmpegTool(
      path: inputPath,
      source: FfmpegBinarySource.custom,
    );
  }

  @override
  Future<ResolvedFfmpegTool> validateCustomFfprobePath(String inputPath) async {
    validatedFfprobePaths.add(inputPath);
    return ResolvedFfmpegTool(
      path: inputPath,
      source: FfmpegBinarySource.custom,
    );
  }
}
