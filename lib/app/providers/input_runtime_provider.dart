import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_locator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/media_analyzer.dart';
import 'package:framelean/application/services/input_runtime/media_folder_scanner.dart';
import 'package:framelean/application/services/input_runtime/media_kind_resolver.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_format_resolver.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/app/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/input_runtime/bundled_proprietary_audio_adapter_registry.dart';
import 'package:framelean/infrastructure/services/input_runtime/default_media_input_preparer.dart';
import 'package:framelean/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_proprietary_audio_format_resolver.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_ffmpeg_locator.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_media_folder_scanner.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_source_file_checker.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_source_file_fingerprint_reader.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/proprietary_audio_decoder_dispatcher.dart';

/// 媒体类型识别服务
final mediaKindResolverProvider = Provider<MediaKindResolver>((ref) {
  return FileExtensionMediaKindResolver();
});

final mediaFolderScannerProvider = Provider<MediaFolderScanner>((ref) {
  return LocalMediaFolderScanner(
    mediaKindResolver: ref.watch(mediaKindResolverProvider),
  );
});

/// 专有音频输入格式识别服务
final proprietaryAudioFormatResolverProvider =
    Provider<ProprietaryAudioFormatResolver>((ref) {
      return const FileExtensionProprietaryAudioFormatResolver();
    });

/// 随包分发的专有音频适配器解析服务
final proprietaryAudioAdapterRegistryProvider =
    Provider<ProprietaryAudioAdapterRegistry>((ref) {
      return const BundledProprietaryAudioAdapterRegistry();
    });

/// 专有音频适配器执行服务
final proprietaryAudioDecoderProvider = Provider<ProprietaryAudioDecoder>((
  ref,
) {
  return const ProprietaryAudioDecoderDispatcher();
});

/// FFprobe / FFmpeg 前的实际输入文件准备服务
final mediaInputPreparerProvider = Provider<MediaInputPreparer>((ref) {
  return DefaultMediaInputPreparer(
    proprietaryAudioFormatResolver: ref.watch(
      proprietaryAudioFormatResolverProvider,
    ),
    proprietaryAudioAdapterRegistry: ref.watch(
      proprietaryAudioAdapterRegistryProvider,
    ),
    proprietaryAudioDecoder: ref.watch(proprietaryAudioDecoderProvider),
  );
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
