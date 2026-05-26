import 'dart:io';

import 'package:framelean/application/services/input_runtime/source_file_checker.dart';

/// 使用本地文件系统检查源文件是否存在
class LocalSourceFileChecker implements SourceFileChecker {
  @override
  Future<bool> exists(String inputPath) {
    return File(inputPath).exists();
  }
}
