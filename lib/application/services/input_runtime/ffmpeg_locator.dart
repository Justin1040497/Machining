import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';

/// 用户主动设置的工具路径无效
class InvalidFfmpegToolPathException implements Exception {
  final String toolName;
  final String inputPath;

  InvalidFfmpegToolPathException({
    required this.toolName,
    required this.inputPath,
  });

  @override
  String toString() {
    return '$toolName 路径不可用: $inputPath';
  }
}

/// FFmpeg 路径查找服务抽象
abstract class FfmpegLocator {
  /// 启动时解析运行时状态，旧的自定义路径不可用时会自动降级
  Future<ResolvedFfmpegRuntime> resolve({
    String? customFfmpegPath,
    String? customFfprobePath,
  });

  /// 用户主动设置 ffmpeg 路径时使用，路径不可用必须抛异常
  Future<ResolvedFfmpegTool> validateCustomFfmpegPath(String inputPath);

  /// 用户主动设置 ffprobe 路径时使用，路径不可用必须抛异常
  Future<ResolvedFfmpegTool> validateCustomFfprobePath(String inputPath);
}
