import 'dart:io';

import 'package:machining/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';

/// 使用本地文件系统读取源文件大小和最后修改时间
class LocalSourceFileFingerprintReader implements SourceFileFingerprintReader {
  @override
  Future<SourceFileFingerprint> read(String inputPath) async {
    final file = File(inputPath);

    if (!await file.exists()) {
      throw StateError('源文件不存在: $inputPath');
    }

    final stat = await file.stat();

    return SourceFileFingerprint(
      fileSize: stat.size,
      lastModifiedAt: stat.modified.millisecondsSinceEpoch,
    );
  }
}
