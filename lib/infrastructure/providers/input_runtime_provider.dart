import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_locator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_analyzer.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_ffmpeg_locator.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_source_file_checker.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_source_file_fingerprint_reader.dart';

/// 媒体类型识别服务
final mediaKindResolverProvider = Provider<MediaKindResolver>((ref) {
  return FileExtensionMediaKindResolver();
});

/// 源文件存在检查服务
final sourceFileCheckerProvider = Provider<SourceFileChecker>((ref) {
  return LocalSourceFileChecker();
});

/// 源文件快速指纹读取服务
final sourceFileFingerprintReaderProvider =
    Provider<SourceFileFingerprintReader>((ref) {
      return LocalSourceFileFingerprintReader();
    });

/// FFmpeg / FFprobe 路径解析服务
final ffmpegLocatorProvider = Provider<FfmpegLocator>((ref) {
  return LocalFfmpegLocator();
});

/// FFprobe 媒体分析服务
final mediaAnalyzerProvider = Provider<MediaAnalyzer>((ref) {
  return FfprobeMediaAnalyzer();
});

/// 当前 FFmpeg / FFprobe 运行时状态
final ffmpegRuntimeProvider =
    AsyncNotifierProvider<FfmpegRuntimeNotifier, ResolvedFfmpegRuntime>(
      FfmpegRuntimeNotifier.new,
    );

class FfmpegRuntimeNotifier extends AsyncNotifier<ResolvedFfmpegRuntime> {
  @override
  Future<ResolvedFfmpegRuntime> build() async {
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    final locator = ref.watch(ffmpegLocatorProvider);
    final settings = await settingsRepository.loadSettings();

    return locator.resolve(
      customFfmpegPath: settings.customFfmpegPath,
      customFfprobePath: settings.customFfprobePath,
    );
  }

  Future<void> updateCustomFfmpegPath(String inputPath) async {
    final locator = ref.read(ffmpegLocatorProvider);
    final settingsRepository = ref.read(appSettingsRepositoryProvider);

    await locator.validateCustomFfmpegPath(inputPath);

    final settings = await settingsRepository.loadSettings();
    final updatedSettings = settings.withCustomFfmpegPath(inputPath);
    await settingsRepository.saveSettings(updatedSettings);
    final runtime = await locator.resolve(
      customFfmpegPath: updatedSettings.customFfmpegPath,
      customFfprobePath: updatedSettings.customFfprobePath,
    );

    state = AsyncData(runtime);
  }

  Future<void> updateCustomFfprobePath(String inputPath) async {
    final locator = ref.read(ffmpegLocatorProvider);
    final settingsRepository = ref.read(appSettingsRepositoryProvider);

    await locator.validateCustomFfprobePath(inputPath);

    final settings = await settingsRepository.loadSettings();
    final updatedSettings = settings.withCustomFfprobePath(inputPath);
    await settingsRepository.saveSettings(updatedSettings);
    final runtime = await locator.resolve(
      customFfmpegPath: updatedSettings.customFfmpegPath,
      customFfprobePath: updatedSettings.customFfprobePath,
    );

    state = AsyncData(runtime);
  }
}
