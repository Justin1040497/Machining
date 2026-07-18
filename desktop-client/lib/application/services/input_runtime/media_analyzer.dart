import 'package:framelean/domain/library.dart';

/// 任务中的 媒体文件分析服务抽象
abstract class MediaAnalyzer {
  /// 分析文件并返回媒体基础信息
  Future<MediaAnalysisResult> analyze({
    required String ffprobePath,
    required String inputPath,
  });
}
