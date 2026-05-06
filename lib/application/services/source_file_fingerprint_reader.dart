import 'package:machining/domain/value_objects/source_file_fingerprint.dart';

/// 读取源文件快速指纹
abstract class SourceFileFingerprintReader {
  Future<SourceFileFingerprint> read(String inputPath);
}
