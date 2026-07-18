import 'package:framelean/domain/library.dart';

/// 读取源文件快速指纹
abstract class SourceFileFingerprintReader {
  Future<SourceFileFingerprint> read(String inputPath);
}
