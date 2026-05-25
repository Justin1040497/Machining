import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:machining/application/services/input_runtime/media_kind_resolver.dart';
import 'package:machining/application/services/input_runtime/source_file_checker.dart';
import 'package:machining/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:machining/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';
import 'package:machining/infrastructure/services/input_runtime/local_source_file_checker.dart';
import 'package:machining/infrastructure/services/input_runtime/local_source_file_fingerprint_reader.dart';

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
