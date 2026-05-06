/// 检查源文件是否还存在
abstract class SourceFileChecker {
  Future<bool> exists(String inputPath);
}
