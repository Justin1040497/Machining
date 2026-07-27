import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/library.dart';

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

/// FEngine 前的实际输入文件准备服务
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
